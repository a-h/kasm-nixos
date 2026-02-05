{
  description = "Kasm NixOS images";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.11";
    };
    version = {
      url = "github:a-h/version";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, version }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            kasmvnc = final.callPackage ./kasmvnc.nix { };
            startup-script = final.callPackage ./startup-script.nix { };
            version = version.packages.${system}.default;
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

      devTools = [
        pkgs.git
        pkgs.curl
        pkgs.wget
        pkgs.jq
        pkgs.skopeo
        pkgs.version
      ];
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = devTools;
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
                pkgs.startup-script
                pkgs.gnome-session
                pkgs.gnome-shell
                pkgs.gnome-terminal
                pkgs.nautilus
                pkgs.gnome-settings-daemon
                pkgs.firefox
                dockerUser
              ];

            config = {
              User = "user:user";
              Env = [
                "HOME=/home/user"
                "LANG=en_US.UTF-8"
                "LC_ALL=en_US.UTF-8"
                "XDG_CURRENT_DESKTOP=GNOME"
                "XDG_SESSION_TYPE=x11"
              ];
              Cmd = [
                "${pkgs.startup-script}/bin/startup.sh"
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
