{
  description = "Kasm NixOS images";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
              kasmvnc = final.callPackage ./kasmvnc.nix { };
          })
        ];
      };

      dockerUser = pkgs.runCommand "docker-user" { } ''
        mkdir -p $out/etc $out/home/user
        echo "user:x:1000:1000:user:/home/user:/bin/bash" > $out/etc/passwd
        echo "user:x:1000:" > $out/etc/group
        echo "user:!:1::::::" > $out/etc/shadow
        chmod 0755 $out/home/user
      '';

      devTools = with pkgs; [
        git
        curl
        wget
        jq
      ];
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.crane
        ];
      };

      packages.${system} = {
        kasmvnc = pkgs.kasmvnc;
        desktop =
          pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/a-h/kasm-nixos/desktop";
            tag = "latest";

            contents =
              [
                pkgs.coreutils
                pkgs.bash
                pkgs.cacert
                pkgs.dockerTools.caCertificates
                pkgs.dbus
                pkgs.kasmvnc
                pkgs.xfce4-session
                pkgs.xfce4-panel
                pkgs.xfce4-terminal
                pkgs.thunar
                pkgs.firefox
                dockerUser
              ]
              ++ devTools;

            config = {
              User = "user:user";
              Env = [
                "HOME=/home/user"
                "LANG=en_US.UTF-8"
                "LC_ALL=en_US.UTF-8"
                "XDG_CURRENT_DESKTOP=xfce"
                "XDG_SESSION_TYPE=x11"
              ];
              Cmd = [
                "kasmvncserver"
                ":0"
                "-fg"
                "-SecurityTypes"
                "None"
              ];
              ExposedPorts = {
                "5901/tcp" = { };
                "6080/tcp" = { };
              };
            };
          };
      };
    };
}
