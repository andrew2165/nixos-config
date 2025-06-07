{ config, pkgs, ... }: {


    # TODO:finish configuration

    age.secrets.pocket-id-env = {
        file = ./../../secrets/pocket-id-env.age;
    };

    services.pocket-id = {
        enable = true;
        user = "andrew";
        environmentFile = config.age.secrets.pocket-id-env.path;
        dataDir = "/home/andrew/pocket-id";
    };

}