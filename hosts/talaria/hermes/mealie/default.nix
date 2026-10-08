{ lib, ... }:

let
  secretFile = ../../../../secrets/hermes-mealie-env.age;
  hasSecret = builtins.pathExists secretFile;
in
{
  age.secrets = lib.optionalAttrs hasSecret {
    hermes-mealie-env = {
      file = secretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  # Recreate the container to reload its environment when credentials change.
  systemd.services.hermes-docker-compose.restartTriggers =
    lib.optional hasSecret secretFile;
}
