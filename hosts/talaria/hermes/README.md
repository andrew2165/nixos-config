# Hermes on talaria

The Nix module enables Docker and manages the Compose stack through
`hermes-docker-compose.service`. The Compose file is also installed at
`/etc/hermes/docker-compose.yml` for manual setup and maintenance.

The image is pinned to the versioned `v2026.9.24` tag. Updates are made by
changing the image in `docker-compose.yml` and rebuilding talaria. The systemd
service recreates the container when its Compose definition changes.

## First setup

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

This initial stack publishes no ports and enables neither the dashboard nor
the API server. It uses Docker's bridge network with outbound access; it does
not restrict access to destinations on the LAN or tailnet. It mounts no host
Docker socket or infrastructure credentials.

The container is limited to one CPU, 2 GiB RAM, and 512 processes. Leave enough
memory for NixOS and adjust these limits for browser tools or parallel tasks.
Docker logs rotate; Hermes's own state and logs still need disk monitoring.

Upstream references:

- [Docker deployment](https://hermes-agent.nousresearch.com/docs/user-guide/docker)
- [Pinned release](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.9.24)
