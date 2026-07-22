{ lib, pkgs, ... }:

let
    bootstrapSecretFile = ./../../../secrets/planka-bootstrap-env.age;
    hasBootstrapSecret = builtins.pathExists bootstrapSecretFile;
in {
    age.secrets = {
      planka-env = {
        file = ./../../../secrets/planka-env.age;
        owner = "root";
        group = "root";
        mode = "400";
        path = "/etc/planka/.env";
      };
      planka-postgres-password = {
        file = ./../../../secrets/planka-postgres-password.age;
        # Docker Compose implements file-backed secrets as bind mounts. Planka
        # runs as UID 1000, which is the same UID used by the andrew account.
        owner = "andrew";
        group = "users";
        mode = "400";
        path = "/etc/planka/postgres-password";
      };
    } // lib.optionalAttrs hasBootstrapSecret {
      planka-bootstrap-env = {
        file = bootstrapSecretFile;
        owner = "root";
        group = "root";
        mode = "400";
      };
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
            TimeoutStartSec = "6min";
        };
        restartTriggers = [
            ./../../../secrets/planka-env.age
            ./../../../secrets/planka-postgres-password.age
        ] ++ lib.optional hasBootstrapSecret bootstrapSecretFile;
        preStart = ''
        if [ ! -s /etc/planka/postgres-password ]; then
            echo "The Planka database password secret is missing or empty" >&2
            exit 1
        fi

        if [ ! -s /etc/planka/.env ]; then
            echo "The Planka environment secret is missing or empty" >&2
            exit 1
        fi

        secretKeyMatches=$(grep -Ec '^SECRET_KEY=' /etc/planka/.env || true)
        if [ "$secretKeyMatches" -ne 1 ] || ! grep -Eq '^SECRET_KEY=.+' /etc/planka/.env; then
            echo "The Planka environment secret must define SECRET_KEY exactly once with a non-empty value" >&2
            exit 1
        fi

        singleQuote="'"
        if grep -Fqx 'SECRET_KEY=""' /etc/planka/.env \
            || grep -Fqx "SECRET_KEY=$singleQuote$singleQuote" /etc/planka/.env; then
            echo "The Planka environment secret must not define SECRET_KEY as an empty quoted value" >&2
            exit 1
        fi

        if grep -Eq '^DATABASE_PASSWORD=' /etc/planka/.env; then
            echo "Remove DATABASE_PASSWORD from planka-env.age; the file-backed secret is authoritative" >&2
            exit 1
        fi

        if grep -Eq '^DEFAULT_ADMIN_' /etc/planka/.env; then
            echo "Move DEFAULT_ADMIN_* settings from planka-env.age to planka-bootstrap-env.age" >&2
            exit 1
        fi

        '' + lib.optionalString hasBootstrapSecret ''
        if [ ! -s /run/agenix/planka-bootstrap-env ]; then
            echo "The Planka administrator bootstrap secret is missing or empty" >&2
            exit 1
        fi

        if grep -Eq '^(DATABASE_PASSWORD|SECRET_KEY)=' /run/agenix/planka-bootstrap-env; then
            echo "Do not put database or runtime secrets in the Planka administrator bootstrap secret" >&2
            exit 1
        fi

        for key in \
            DEFAULT_ADMIN_EMAIL \
            DEFAULT_ADMIN_PASSWORD \
            DEFAULT_ADMIN_NAME \
            DEFAULT_ADMIN_USERNAME; do
            matches=$(grep -Ec "^$key=" /run/agenix/planka-bootstrap-env || true)
            if [ "$matches" -ne 1 ]; then
                echo "The Planka administrator bootstrap secret must define $key exactly once" >&2
                exit 1
            fi

            if ! grep -Eq "^$key=.+" /run/agenix/planka-bootstrap-env; then
                echo "The Planka administrator bootstrap secret must define a non-empty value for $key" >&2
                exit 1
            fi

            if grep -Fqx "$key=\"\"" /run/agenix/planka-bootstrap-env \
                || grep -Fqx "$key=$singleQuote$singleQuote" /run/agenix/planka-bootstrap-env; then
                echo "The Planka administrator bootstrap secret must not define $key as an empty quoted value" >&2
                exit 1
            fi
        done

        '' + ''

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
        if ! docker compose --project-name planka -f ${./docker-compose.yml} \
            up --detach --wait --wait-timeout 180; then
            docker compose --project-name planka -f ${./docker-compose.yml} ps >&2 || true
            docker compose --project-name planka -f ${./docker-compose.yml} \
                logs --no-color --tail 100 postgres planka >&2 || true
            exit 1
        fi
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
