{ config, lib, pkgs, ... }:

let
  mountPoint = "/mnt/tanker-hermes";
  stagingDirectory = "/var/lib/hermes-backup/staging";
  smbSecretFile = ./../../../secrets/tanker-karakeep-smb-pswd.age;
  passwordSecretFile = ./../../../secrets/hermes-restic-password.age;
  secretsReady = builtins.pathExists smbSecretFile && builtins.pathExists passwordSecretFile;
in
lib.mkMerge [
  {
    warnings = lib.optional (!secretsReady) "Hermes backups are disabled until tanker-karakeep-smb-pswd.age and hermes-restic-password.age exist; see hosts/talaria/hermes/README.md.";
  }
  (lib.mkIf secretsReady {
    boot.supportedFilesystems = [ "cifs" ];

    age.secrets = {
      tanker-karakeep-smb-pswd = {
        file = smbSecretFile;
        mode = "0400";
      };
      hermes-restic-password = {
        file = passwordSecretFile;
        mode = "0400";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${mountPoint} 0700 root root -"
      "d /var/lib/hermes-backup 0700 root root -"
      "d ${stagingDirectory} 0700 root root -"
    ];

    systemd.mounts = [{
      description = "Tanker Hermes backup share over Tailscale";
      what = "//100.113.228.33/self-hosted-services";
      where = mountPoint;
      type = "cifs";
      options = "credentials=${config.age.secrets.tanker-karakeep-smb-pswd.path},vers=3.0,uid=0,gid=0,file_mode=0600,dir_mode=0700,nosuid,nodev,noexec";
      wants = [ "network-online.target" ];
      requires = [ "tailscaled.service" ];
      after = [ "network-online.target" "tailscaled.service" ];
      mountConfig.TimeoutSec = "30s";
    }];
    systemd.automounts = [{
      description = "Automount Tanker Hermes backup share";
      where = mountPoint;
      wantedBy = [ "multi-user.target" ];
      automountConfig.TimeoutIdleSec = "5min";
    }];

    services.restic.backups.hermes = {
      repository = "${mountPoint}/hermes-restic";
      passwordFile = config.age.secrets.hermes-restic-password.path;
      initialize = true;
      paths = [ stagingDirectory ];
      extraBackupArgs = [ "--tag hermes" ];
      timerConfig = {
        OnCalendar = "Sun *-*-* 20:00:00";
        RandomizedDelaySec = "15min";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
      ];
      # Check repository metadata after each successful backup and prune.
      runCheck = true;
      backupPrepareCommand = builtins.readFile ./prepare-backup.sh;
      # The Restic module runs this as ExecStopPost, including after a failed
      # preparation or timeout, so a failed copy still attempts to restart Hermes.
      backupCleanupCommand = builtins.readFile ./resume-after-backup.sh;
    };

    systemd.services.restic-backups-hermes = {
      requires = [ "docker.service" "tailscaled.service" ];
      after = [ "docker.service" "tailscaled.service" ];
      # Start the real mount before any copying; never write a local "backup"
      # under an unmounted NAS directory. No dependency on the Hermes service:
      # preparation must be able to stop/start it without an ordering deadlock.
      unitConfig.RequiresMountsFor = mountPoint;
      path = [ pkgs.bash pkgs.coreutils pkgs.rsync pkgs.util-linux pkgs.systemd ];
      environment = {
        HERMES_BACKUP_MOUNT = mountPoint;
        HERMES_BACKUP_STAGING = stagingDirectory;
        HERMES_BACKUP_RESTART_MARKER = "/run/restic-backups-hermes/restart-hermes";
        # Restic's documented workaround for Linux CIFS compatibility.
        GODEBUG = "asyncpreemptoff=1";
      };
      serviceConfig = {
        UMask = "0077";
        TimeoutStartSec = "2h";
        TimeoutStopSec = "6min";
      };
    };
  })
]
