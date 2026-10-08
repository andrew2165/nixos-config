# Mealie access for Hermes

This integration uses Mealie's REST API directly. The repository supplies a
Hermes skill and a Python standard-library client; no Mealie MCP adapter or
third-party Python package is installed. The client reads recipes, meal plans,
and shopping lists through specific GET routes. It has no write commands.

## Layout and deployment

- `default.nix`: agenix declaration and credential restart trigger.
- `env.example`: the assignments to enter in the encrypted env secret.
- `skill/SKILL.md`: Hermes discovery metadata, credential passthrough, and usage.
- `skill/scripts/mealie.py`: the REST client.
- `tests/`: local regression checks using a mock HTTP server.

The `skill/` folder is a self-contained skill for you to tell Hermes to learn.
Include both `SKILL.md` and `scripts/mealie.py` when learning it. NixOS and
Compose do not install or mount the skill. Credential deployment is independent
of learning the skill; skill changes do not restart the container.

Agenix decrypts `secrets/hermes-mealie-env.age` to
`/run/agenix/hermes-mealie-env` with root ownership and mode `0400`. Compose
reads that env file and injects the variables into the container; it does not
mount the env file or any decryption key. The encrypted file initially contains
the expected base URL and an empty token for you to fill in. Missing Mealie
credentials produce a setup error from the client without preventing Hermes
from starting. Optional `env_file` requires Docker Compose 2.24.0 or newer
(provided by talaria's current Nixpkgs input).

## Create the Mealie token

Mealie publishes port `9925` on internalServer. The repo's other services
identify that host's Tailscale address as `100.122.79.75`; verify the actual
address if it changes. Talaria's container must be allowed to connect to
`100.122.79.75:9925` by your tailnet policy.

1. Create a dedicated non-administrator Mealie user in the group/household
   containing the recipes, plans, and lists you want Hermes to read.
2. Sign in as that user at `http://100.122.79.75:9925`.
3. Open **Manage Your Profile → API Tokens**, or visit
   `/user/profile/api-tokens`.
4. Create a token named `Hermes` and copy it into the encrypted editor below.

The token inherits the user's permissions. GET-only behavior is a restriction
of this client, not a read-only scope on the token or a restriction on every
other tool Hermes could execute.

## Fill in the encrypted env file

On your editing machine, use a private key authorized by `secrets/secrets.nix`:

```sh
cd ~/SelfHostingProjects/nixos-config/secrets
AGENIX_RULES=./secrets.nix EDITOR=nano nix run github:ryantm/agenix -- -e hermes-mealie-env.age
```

Adjust the repository path if your checkout is elsewhere. The editor contains
these assignments; fill in the token and verify the URL:

```dotenv
MEALIE_BASE_URL=http://100.122.79.75:9925
MEALIE_API_TOKEN=<your-Mealie-API-token>
```

Use the application base URL without `/api`, `/docs`, a query, or login
credentials. The token is the raw value without `Bearer `. The env file does
not evaluate shell expressions. `env.example` is a credential-free reference;
never put the real token in that tracked file. Do not edit the agenix runtime
file, which is regenerated on deployment. Remove duplicate `MEALIE_BASE_URL`
and `MEALIE_API_TOKEN` settings from Hermes's persistent `.env` or profile env
files so they cannot override agenix's injected values.

The encrypted template uses the same editing keys and talaria public key as the
existing Home Assistant secret. If replacing talaria's SSH identity, update
`secrets/talaria.pub` and re-encrypt the secrets before deployment.

Include new files in the Git-based flake source, then synchronize your checkout
to talaria using your normal workflow:

```sh
git add hosts/talaria/hermes secrets/secrets.nix secrets/hermes-mealie-env.age
```

On talaria:

```sh
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#talaria
sudo systemctl status hermes-docker-compose --no-pager
```

Secret changes restart the Compose service and recreate the container. The
existing encrypted Restic backup includes the decrypted Mealie env file when
present. A skill learned into Hermes's normal persistent skills directory is
included in the existing data backup. Keep the source skill and encrypted
secrets in this repository as well.

## Teach Hermes the skill and check access

Make the repository's `hosts/talaria/hermes/mealie/skill/` folder available to
Hermes through your preferred learning workflow, then ask it to learn the
skill from that location, including its `scripts/` folder. The source must be
reachable from Hermes's execution environment; a host checkout is not
automatically visible inside the container. This repo does not install the
skill for you.

After Hermes has learned it, start a fresh conversation and ask: **“Load the
Mealie skill, check authenticated access, and list five recipes from my
household.”** Loading the skill registers its variables for terminal
passthrough. The check reads `/api/users/self` and prints only an `ok`
confirmation.

If the learned skill is saved at the usual `/opt/data/skills/mealie` location,
you can also check authenticated access from talaria with:

```sh
sudo docker exec -u hermes hermes python3 /opt/data/skills/mealie/scripts/mealie.py check
```

Adjust the script path if Hermes saves the skill elsewhere. The intended
execution environment is Hermes's local terminal inside this container; if you
configure an additional remote terminal backend, that backend will also need
access to the script and Mealie network.

Examples from the learned skill's directory inside the Hermes container:

```sh
python3 scripts/mealie.py recipes --search "chicken" --per-page 5
python3 scripts/mealie.py recipe chicken-soup
python3 scripts/mealie.py mealplans --start-date 2026-10-07 --end-date 2026-10-13
python3 scripts/mealie.py shopping-lists
python3 scripts/mealie.py shopping-list "<list-uuid>"
```

Use `--page` and `--per-page` to fetch additional collection pages. The client
does not follow redirects, has a 20-second request timeout, and limits each
response to 8 MiB. Its HTTP errors omit server bodies and credentials. A 401
indicates a rejected token; a 403 indicates denied access; a 404 may indicate
an incorrect ID or API version difference. For connection failures, check
Tailscale policy, the address/port, and any TLS certificate configuration.

The deployed Mealie instance follows `latest`, so use its `/docs` to investigate
API changes if a command stops working. The routes and query parameters were
checked against Mealie's published API schema when this integration was added.

## Local checks

The regression checks use dummy tokens and a local mock HTTP server, without
connecting to Mealie or changing production data:

```sh
python3 -m unittest discover -s hosts/talaria/hermes/mealie/tests -v
```

References:

- [Mealie API token and API documentation](https://mealie.io/documentation/getting-started/api-usage/)
- [Hermes skill creation and environment passthrough](https://hermes-agent.nousresearch.com/docs/developer-guide/creating-skills)
- [Skill discovery in the pinned Hermes release](https://github.com/NousResearch/hermes-agent/blob/v0.21.6/agent/skill_utils.py)
