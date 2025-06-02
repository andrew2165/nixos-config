let
  mbp =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFTSJ+CahcqGec/tsOcZDxsAyFQ1h8TxCgVxq1bSePr";
  endeavor-nixos =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKeyCw1VxK87xr+cYZdjqW/MIPTjxzOg7q7isrn3bdC4";
  endeavor-nixos-internalServer =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSBPlZgcSd3Y9RHWZCemFFjJkR4g41JREEvXeplv74X";
  nixPi-test =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuwH6/WPRkArKQT86nWzwBBWK7h8fv6/LEX3do5gevp";
  desktop-knvu2bv-wsl =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZCeaMfoy/5Tef0FnIkLrqhE6BIvjL+XfIDXczkTiDR";
in {
  "wifi-pswd.age".publicKeys = [ mbp endeavor-nixos desktop-knvu2bv-wsl ];
  "nixpi-andrew-pswd.age".publicKeys =
    [ mbp endeavor-nixos desktop-knvu2bv-wsl ];
  "tailscale-auth-key1.age".publicKeys =
    [ mbp endeavor-nixos nixPi-test desktop-knvu2bv-wsl ];
  "tanker-karakeep-smb-pswd.age".publicKeys =
    [ mbp endeavor-nixos-internalServer desktop-knvu2bv-wsl ];
  "karakeep-env-file.age".publicKeys =
    [ mbp endeavor-nixos-internalServer endeavor-nixos desktop-knvu2bv-wsl ];
  "paperless.age".publicKeys = 
    [ mbp endeavor-nixos-internalServer endeavor-nixos desktop-knvu2bv-wsl ];
}
