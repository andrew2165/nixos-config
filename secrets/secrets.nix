let
    mbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFTSJ+CahcqGec/tsOcZDxsAyFQ1h8TxCgVxq1bSePr";
    endeavor-nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJCd6JBjWuiGdr9tB7AEx0e7awpmLwTYvp60MemuUb4n";
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