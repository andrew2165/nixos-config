# Hermes on talaria

The Nix module enables Docker and manages the Compose stack through
`hermes-docker-compose.service`. The Compose file is also installed at
`/etc/hermes/docker-compose.yml` for manual setup and maintenance.

The image is pinned to the `v0.21.6` stable release by its immutable manifest
digest, recorded in the upstream release receipt. The `stable` tag in the image
reference cannot advance it automatically because the digest takes precedence.
Updates are made by changing the image digest in `docker-compose.yml` and
rebuilding talaria. The systemd service recreates the container when its Compose
definition changes.

## First setup

Complete the dashboard and Home Assistant secret setup below before running
Compose: it requires `/run/agenix/hermes-dashboard-env` and
`/run/agenix/hermes-homeassistant-env`. Until both encrypted files exist, NixOS
can still rebuild, but the gateway service will be skipped.

After installing/rebuilding talaria, connect over SSH and run:

```sh
sudo docker compose --project-name hermes -f /etc/hermes/docker-compose.yml run --rm --no-deps hermes setup
sudo systemctl start hermes-docker-compose
sudo docker logs --tail 100 hermes
```

Configure a model provider and a chat integration in the wizard. Restrict the
integration to your own account using Hermes's platform allowlists or pairing.
The service waits for `/var/lib/hermes/data/config.yaml` before it starts, so a
fresh VM can boot before the wizard has been run. After setup it starts on boot.

## Interactive use

```sh
sudo docker exec -it hermes hermes
sudo docker exec -it hermes hermes setup
sudo systemctl restart hermes-docker-compose
sudo systemctl stop hermes-docker-compose
```

Stop the service before running the setup wizard in a new one-off container
against the same data directory. Use `docker exec` when the gateway is running.

## Data and networking

All persistent state is in `/var/lib/hermes/data`, including `.env` credentials,
configuration, sessions, skills, and memories. Keep credentials out of Git and
the Nix store. The backup job below stops the service while copying this
directory for a consistent snapshot. `docker compose down` does not delete
this bind-mounted data.

The dashboard/Desktop backend is published at `http://100.115.7.109:9119`, only
on talaria's Tailscale address. Connect the desktop to the same tailnet, add a
Remote gateway in Hermes Desktop, and sign in with the dashboard credentials.
No SSH tunnel is needed. Tailnet ACLs must allow the connection. The separate
OpenAI-compatible API server is not enabled. Docker uses bridge networking;
binding the published port to the Tailscale address restricts its destination
address, but tailnet access policy still matters (Docker manages forwarding
rules separately from the host INPUT firewall).

The stack has outbound access; it does
not restrict access to destinations on the LAN or tailnet. It mounts no host
Docker socket or infrastructure credentials.

The container is limited to one CPU, 2 GiB RAM, and 512 processes. Leave enough
memory for NixOS and adjust these limits for browser tools or parallel tasks.
Docker logs rotate; Hermes's own state and logs still need disk monitoring.

## Backups to Tanker

`backup.nix` creates encrypted, deduplicated Restic snapshots on Tanker's
existing `//100.113.228.33/self-hosted-services` SMB share, under
`hermes-restic/`. This is Tanker's Tailscale address. The share is mounted on
talaria at `/mnt/tanker-hermes`, with root-only local permissions. Tailnet
policy must allow talaria to reach Tanker on TCP port 445, and the SMB account
must have write access to this share.

The timer runs weekly on Sundays at 20:00 Pacific time, with up to 15 minutes
of jitter, and catches up after a missed run. Retention rules keep up to 14
daily, 8 weekly, and 12 monthly snapshots. Repository metadata is checked after
each successful backup.

The job first verifies the actual SMB mount, then stops Hermes if it was
running, copies its state to `/var/lib/hermes-backup/staging`, and restarts it
before uploading. A failed copy or timeout also attempts to restart Hermes.
An intentionally stopped service stays stopped. The local staging copy is
kept between runs to shorten later copies; allow disk space for a second copy
of Hermes's data. Its parent directory is accessible only to root.

Each snapshot contains:

- `data/`: the entire `/var/lib/hermes/data` bind mount, including hidden
  `.env` files, databases, sessions, skills, memories, and logs.
- `config/`: dereferenced copies of the deployed Compose and managed MCP files.
- `secrets/`: the dashboard and Home Assistant env files supplied by agenix,
  plus the Mealie env file when configured.

The NAS only receives encrypted Restic content. The SMB credential and Restic
repository password are not included in snapshots. Keep this repository's
encrypted secrets and an authorized editing SSH private key somewhere outside
the VM so a lost VM does not also lose the ability to restore.

### Enable and verify

`secrets/hermes-restic-password.age` already contains a generated random
repository password encrypted for the editing keys and talaria's key.
Keep it: replacing its contents will not change the password on an existing
Restic repository. Use `restic key` operations if you need to rotate it.

Backups reuse `secrets/tanker-karakeep-smb-pswd.age`, the existing Tanker SMB
credential used by Karakeep and Mealie. Its recipient rule includes
`secrets/talaria.pub` alongside the existing recipients. When adding or changing
talaria's public key, re-encrypt only this secret while retaining its contents:

```sh
cd ~/nixos-config/secrets
AGENIX_RULES=./secrets.nix EDITOR=: agenix -e tanker-karakeep-smb-pswd.age
```

Until both backup secrets exist, the NixOS configuration remains rebuildable
and warns that backups are disabled.

Make the new files visible to Git-based flake evaluation before synchronizing
the repo to talaria:

```sh
cd ~/nixos-config
git add hosts/talaria/hermes secrets/secrets.nix secrets/hermes-restic-password.age secrets/tanker-karakeep-smb-pswd.age
```

On talaria, rebuild and run the first backup:

```sh
sudo nixos-rebuild switch --flake .#talaria
sudo systemctl start restic-backups-hermes.service
sudo journalctl -u restic-backups-hermes.service -n 100 --no-pager
systemctl list-timers restic-backups-hermes.timer
sudo restic-hermes snapshots --tag hermes
```

The first successful run initializes the repository automatically. The
`restic-hermes` wrapper sets the repository, password file, cache, and CIFS
compatibility environment. For manual access after the idle mount has gone
away, start the mount first:

```sh
sudo systemctl start 'mnt-tanker\x2dhermes.mount'
sudo restic-hermes check --read-data
```

The scheduled check verifies metadata; `check --read-data` additionally reads and
verifies all stored data. A failed backup appears as a failed systemd unit
and in its journal; external notifications are not configured.

### Restore

Mount Tanker, list snapshots, and restore a selected snapshot into a separate
directory so it can be inspected before replacing live state:

```sh
sudo systemctl start 'mnt-tanker\x2dhermes.mount'
sudo restic-hermes snapshots --tag hermes
sudo install -d -m 700 /var/lib/hermes-restore
sudo restic-hermes restore <snapshot-id> --target /var/lib/hermes-restore --verify
```

Restic preserves the backed-up path. Recovered `data/`, `config/`, and `secrets/`
are under `/var/lib/hermes-restore/var/lib/hermes-backup/staging/`.
Once verified, restore the data while Hermes is stopped:

```sh
sudo systemctl stop hermes-docker-compose.service
sudo rsync -a --delete /var/lib/hermes-restore/var/lib/hermes-backup/staging/data/ /var/lib/hermes/data/
sudo systemctl start hermes-docker-compose.service
```

This replaces the live data with the selected snapshot, preserving ownership
and permissions. Compare the recovered Compose and MCP files with this repo
if restoring across an image/configuration change; deploy the corresponding
version through NixOS. For a replacement VM, recreate its agenix identity and
re-encrypt secrets for its new public key before rebuilding. The original
encrypted env files can be re-encrypted from an editing machine; the backed-up
env files also provide recovery copies if needed. Do not copy plaintext
secrets into Git or the Nix store.

If restoring on another machine, decrypt `hermes-restic-password.age` with an
authorized editing key into a private temporary file and pass it to Restic
with `--password-file`. Mount the same NAS share and use the `hermes-restic`
directory as `--repo`; the original VM is not required.

References: [Restic repositories and CIFS compatibility](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html),
[Restic restore](https://restic.readthedocs.io/en/stable/050_restore.html).

## Dashboard secrets with agenix

Talaria imports agenix and uses `/home/andrew/.ssh/id_ed25519` to decrypt
secrets. This is a separate key from the public keys in `authorizedKeys`,
which allow you to log in to talaria. The private key stays on the VM and
must be available without a passphrase for unattended boot-time decryption.

When ready, as `andrew` on talaria, create the key if it does not exist:

```sh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -N '' -C andrew@talaria -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

Copy only that public key into `secrets/talaria.pub` in the repo. The recipient
rule in `secrets/secrets.nix` reads that file. Never copy the private key into
Git, and do not encrypt the secret until the public key has been added.

Create the encrypted file from a machine with an authorized editing key:

```sh
cd ~/nixos-config/secrets
agenix -e hermes-dashboard-env.age
```

Enter these variables in the editor, replacing the placeholders:

```dotenv
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=andrew
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=<strong-password>
HERMES_DASHBOARD_BASIC_AUTH_SECRET=<random-signing-secret>
```

Use `openssl rand -hex 32` to generate the signing secret. Paste the result;
the env file does not execute shell expressions. Keep the cleartext out of
the repository. If you already put these variables in Hermes's data `.env`,
remove those duplicate entries so the agenix-provided values are authoritative.

Ensure the public key and encrypted secret are included in the flake's source.
For uncommitted Git files, `git add secrets/talaria.pub
secrets/hermes-dashboard-env.age` makes them visible to Nix without committing.
Synchronize the repo to talaria, then rebuild there:

```sh
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#talaria
```

Agenix decrypts the file on the VM into `/run/agenix/hermes-dashboard-env`
with root-only permissions. Compose reads it via `env_file` and passes the
values to Hermes inside the container; it does not mount the SSH key or the
secret file into the container. Existing provider tokens remain in Hermes's
data `.env`; this secret manages dashboard authentication only.

After rebuilding, follow the setup/start commands above. For subsequent
secret changes, edit the encrypted file and rebuild: the Compose service
restarts when the encrypted file changes.

## Mealie REST API

The local [Mealie integration](mealie/README.md) provides a repository-owned
Hermes skill and Python standard-library client for reading recipes, meal plans,
and shopping lists. It uses a dedicated agenix env secret and calls Mealie
directly. The skill folder is available for you to tell Hermes to learn; NixOS
manages only the credentials. Follow that guide to fill in the URL/token,
deploy the credentials, and teach Hermes the skill.

## Home Assistant MCP

Enable the **Model Context Protocol Server** integration in Home Assistant and
create a long-lived access token from your user profile's Security tab. Hermes
connects directly to its Streamable HTTP endpoint with a bearer token.
Choose a URL reachable from talaria's Docker container and expose the entities
you want Hermes to use in Home Assistant. The base `/api/mcp` endpoint may
require an administrator account, depending on the integration's settings.

On your editing machine, edit the encrypted env file:

```sh
cd ~/nixos-config/secrets
AGENIX_RULES=./secrets.nix EDITOR=nano nix run github:ryantm/agenix -- -e hermes-homeassistant-env.age
```

It must contain these assignments (replace both placeholders):

```dotenv
HA_TOKEN=<your-long-lived-access-token>
HA_MCP_URL=http://<your-home-assistant-host>:8123/api/mcp
```

`HA_MCP_URL` is the complete MCP endpoint, including `/api/mcp`, not just the
Home Assistant base URL. Use your instance's actual scheme, hostname and port.
Keep `HA_TOKEN` as the raw token; Hermes adds `Bearer ` in the header. Remove
duplicate `HA_TOKEN` or `HA_MCP_URL` entries from `/var/lib/hermes/data/.env` or
profile env files so they do not override the injected values.

The Nix module decrypts the secret into
`/run/agenix/hermes-homeassistant-env` as root with mode `0400`. Compose reads
it and injects the variables into the container. The plaintext secret is not
included in the Nix store or mounted into the container.

`mcp-config.yaml` is installed at `/etc/hermes/mcp-config.yaml` on talaria and
mounted read-only at `/etc/hermes/config.yaml` inside the container. The pinned
Hermes version loads this as its managed configuration layer and merges it
over `/opt/data/config.yaml`. It adds the `homeassistant` MCP connection with
environment references for the URL and Authorization header. Model settings,
chat integrations and other MCP servers continue to come from your existing
configuration. Change this connection through the repo; Hermes's interactive
config editors cannot change the managed fields.

Include the new files in the flake source before synchronizing the repo to
talaria:

```sh
cd ~/nixos-config
git add secrets/hermes-homeassistant-env.age hosts/talaria/hermes/mcp-config.yaml
```

Then, on talaria:

```sh
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#talaria
sudo systemctl status hermes-docker-compose --no-pager
```

Check that Hermes resolves the token without displaying it:

```sh
sudo docker exec -u hermes hermes /opt/hermes/.venv/bin/python -c 'from tools.mcp_tool_config import _load_mcp_config; c = _load_mcp_config()["homeassistant"]; h = c["headers"]["Authorization"]; assert h.startswith("Bearer ") and len(h) > 7 and "${" not in h; assert c["url"].startswith(("http://", "https://")) and "${" not in c["url"]; print("Home Assistant MCP URL and bearer token resolved")'
```

This checks configuration, not connectivity or token validity. Start a fresh
Hermes conversation and ask it to report the state of an exposed entity to
verify the connection without changing devices. A `401` indicates an invalid
token; a `404` can indicate a missing MCP integration or incorrect endpoint.
If access is denied, also check the integration's administrator requirement.

Subsequent token or URL changes use the same agenix edit command followed by
a rebuild. The service restarts for either secret file or MCP config changes,
recreating the container with the updated environment and bind mount.

Upstream references:

- [Docker deployment](https://hermes-agent.nousresearch.com/docs/user-guide/docker)
- [Pinned release](https://github.com/NousResearch/hermes-agent/releases/tag/v0.21.6)
- [Hermes MCP configuration](https://hermes-agent.nousresearch.com/docs/reference/mcp-config-reference/)
- [Managed configuration in the pinned version](https://github.com/NousResearch/hermes-agent/blob/v0.21.6/hermes_cli/managed_scope.py)
- [Home Assistant MCP server](https://www.home-assistant.io/integrations/mcp_server/)
