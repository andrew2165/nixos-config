# Hermes on talaria

The Nix module enables Docker and manages the Compose stack through
`hermes-docker-compose.service`. The Compose file is also installed at
`/etc/hermes/docker-compose.yml` for manual setup and maintenance.

The image is pinned to the versioned `v2026.9.24` tag. Updates are made by
changing the image in `docker-compose.yml` and rebuilding talaria. The systemd
service recreates the container when its Compose definition changes.

## First setup

Complete the dashboard secret setup below before running Compose: it requires
`/run/agenix/hermes-dashboard-env`. Until the encrypted file exists, NixOS can
still rebuild, but the gateway service will be skipped.

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
the Nix store. Stop the service before copying this directory for a consistent
backup. `docker compose down` does not delete this bind-mounted data.

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

Upstream references:

- [Docker deployment](https://hermes-agent.nousresearch.com/docs/user-guide/docker)
- [Pinned release](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.9.24)
