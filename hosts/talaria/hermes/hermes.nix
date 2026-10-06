{ lib, pkgs, ... }:

let
  dashboardSecretFile = ./../../../secrets/hermes-dashboard-env.age;
  hasDashboardSecret = builtins.pathExists dashboardSecretFile;
in
{
  # Allow rebuilding the VM to bootstrap its SSH identity before encryption.
  age.secrets = lib.optionalAttrs hasDashboardSecret {
    hermes-dashboard-env = {
      file = dashboardSecretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    docker
    docker-compose
  ];

  # Keep the same Compose file available for the interactive setup wizard.
  environment.etc."hermes/docker-compose.yml".source = ./docker-compose.yml;

  systemd.tmpfiles.rules = [
    "d /var/lib/hermes 0700 root root -"
    # The image assigns this directory to its runtime user on first setup.
    "d /var/lib/hermes/data 0700 - - -"
  ];

  systemd.services.hermes-docker-compose = {
    path = [
      pkgs.docker-compose
      pkgs.docker
      pkgs.tailscale
      pkgs.gnugrep
      pkgs.coreutils
    ];
    unitConfig = {
      # Run the setup wizard once before starting the gateway.
      ConditionPathExists = [
        "/var/lib/hermes/data/config.yaml"
        "/run/agenix/hermes-dashboard-env"
      ];
    };
    restartTriggers = lib.optional hasDashboardSecret dashboardSecretFile;
    preStart = ''
      for attempt in $(seq 1 60); do
        if tailscale ip -4 2>/dev/null | grep -Fxq "100.115.7.109"; then
          break
        fi
        if [ "$attempt" -eq 60 ]; then
          echo "Timed out waiting for Tailscale address 100.115.7.109" >&2
          exit 1
        fi
        sleep 2
      done
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "15s";
      TimeoutStartSec = "6min";
      TimeoutStopSec = "90s";
    };
    script = ''
      docker compose --project-name hermes -f ${./docker-compose.yml} up --detach
    '';
    preStop = ''
      docker compose --project-name hermes -f ${./docker-compose.yml} down
    '';
    wantedBy = [ "multi-user.target" ];
    requires = [ "docker.service" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    after = [ "docker.service" "tailscaled.service" "network-online.target" "systemd-tmpfiles-setup.service" ];
  };
}
