{ config, pkgs, ... }: {

  services.caddy = {
    enable = true;

    virtualHosts."internaltest.stewartinternal.com".extraConfig = ''
      
              tls internal
              respond "Hello, internal!"
    '';

    virtualHosts."pdf.stewartinternal.com".extraConfig = ''
      
              tls internal
              reverse_proxy 100.83.80.45:8080
    '';

    virtualHosts."endeavor.stewartinternal.com".extraConfig = ''
      
              tls internal
              reverse_proxy 100.103.150.122:8006
    '';

    virtualHosts."tanker.stewartinternal.com".extraConfig = ''
      
              tls internal
              reverse_proxy 100.113.228.33
    '';
  };
  
}