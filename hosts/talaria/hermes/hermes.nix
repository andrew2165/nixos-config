{ pkgs, ... }:

{
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
    ];
    unitConfig = {
      # Run the setup wizard once before starting the gateway.
      ConditionPathExists = "/var/lib/hermes/data/config.yaml";
    };
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
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    after = [ "docker.service" "network-online.target" "systemd-tmpfiles-setup.service" ];
  };
}
