{ config, pkgs, ... }: {

    environment.systemPackages = [
        (pkgs.writeShellApplication {
            name = "planka-create-admin";
            runtimeInputs = [ pkgs.coreutils pkgs.docker pkgs.docker-compose ];
            text = ''
                if [ "$(id -u)" -ne 0 ]; then
                    echo "Run this command with sudo so it can read the Planka secrets." >&2
                    exit 1
                fi

                exec docker compose --project-name planka -f ${./docker-compose.yml} \
                    run --rm planka npm run db:create-admin-user
            '';
        })
    ];

    age.secrets.planka-env = {
        file = ./../../../secrets/planka-env.age;
        owner = "root";
        group = "root";
        mode = "400";
        path = "/etc/planka/.env";
    };
    age.secrets.planka-postgres-password = {
        file = ./../../../secrets/planka-postgres-password.age;
        # Docker Compose implements file-backed secrets as bind mounts. Planka
        # runs as UID 1000, which is the same UID used by the andrew account.
        owner = "andrew";
        group = "users";
        mode = "400";
        path = "/etc/planka/postgres-password";
    };

    systemd.services.planka-docker-compose = {
        path = [
            pkgs.coreutils
            pkgs.docker-compose
            pkgs.docker
            pkgs.gnugrep
            pkgs.tailscale
        ];
        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "15s";
            TimeoutStartSec = "3min";
        };
        preStart = ''
        if [ ! -s /etc/planka/postgres-password ]; then
            echo "The Planka database password secret is missing or empty" >&2
            exit 1
        fi

        if ! grep -Eq '^SECRET_KEY=' /etc/planka/.env; then
            echo "The Planka environment secret must define SECRET_KEY" >&2
            exit 1
        fi

        if grep -Eq '^DATABASE_PASSWORD=' /etc/planka/.env; then
            echo "Remove DATABASE_PASSWORD from planka-env.age; the file-backed secret is authoritative" >&2
            exit 1
        fi

        for attempt in $(seq 1 60); do
            if tailscale ip -4 2>/dev/null | grep -Fxq "100.122.79.75"; then
                break
            fi

            if [ "$attempt" -eq 60 ]; then
                echo "Timed out waiting for Tailscale address 100.122.79.75" >&2
                exit 1
            fi

            sleep 2
        done

        install -d -m 0755 -o 1000 -g 100 /home/andrew/planka/data /home/andrew/planka/db-data
        '';
        script = ''
        set -eu
        docker compose --project-name planka -f ${./docker-compose.yml} up --detach
        '';
        preStop = ''
        set -eu
        docker compose --project-name planka -f ${./docker-compose.yml} down
        '';
        wantedBy = ["multi-user.target"];
        requires = ["docker.service" "tailscaled.service"];
        after = ["docker.service" "docker.socket" "tailscaled.service"];
    };

}
