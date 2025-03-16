let
    mbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFTSJ+CahcqGec/tsOcZDxsAyFQ1h8TxCgVxq1bSePr";
    endeavor-nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKeyCw1VxK87xr+cYZdjqW/MIPTjxzOg7q7isrn3bdC4";
in {
    "wifi-pswd.age".publicKeys = [
        mbp 
        endeavor-nixos
    ];
    "nixpi-andrew-pswd.age".publicKeys = [
        mbp 
        endeavor-nixos
    ];
}