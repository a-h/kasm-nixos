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
    kasmvnc-flake = {
      url = "github:a-h/KasmVNC";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, version, kasmvnc-flake }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            # Use KasmVNC from the upstream flake (built from source)
            kasmvnc = kasmvnc-flake.packages.${system}.kasmvnc;
            entrypoint-script = final.callPackage ./startup-script.nix { };
            openbox-config = final.callPackage ./openbox-config.nix { };
            dbus-config = final.callPackage ./dbus-config.nix { };
            xstartup-config = final.callPackage ./xstartup-config.nix { };
            version = version.packages.${system}.default;
          })
        ];
      };

      # Proper XKB configuration directory structure and config files  
      # Also includes required device directories for X11 input
      xkbAndConfig = pkgs.runCommand "xkb-and-config" { } ''
        # XKB files at standard location
        mkdir -p $out/etc/X11
        cp -r ${pkgs.xkeyboard-config}/share/X11/xkb $out/etc/X11/
        
        # Also at /usr/share for X servers that look there
        mkdir -p $out/usr/share/X11
        cp -r ${pkgs.xkeyboard-config}/share/X11/xkb $out/usr/share/X11/
        
        # Create device directories needed for X11 input
        mkdir -p $out/proc/bus/input
        mkdir -p $out/dev/input
        mkdir -p $out/dev/shm
        
        # KasmVNC configuration
        mkdir -p $out/usr/share/kasmvnc
        mkdir -p $out/etc/kasmvnc
        cp ${./kasmvnc_defaults.yaml} $out/usr/share/kasmvnc/kasmvnc_defaults.yaml
      '';

      devTools = [
        pkgs.git
        pkgs.curl
        pkgs.wget
        pkgs.jq
        pkgs.skopeo
        pkgs.version
      ];

      # Create a unified environment with all packages properly linked
      desktopEnv = pkgs.buildEnv {
        name = "desktop-environment";
        paths = [
          pkgs.coreutils
          pkgs.bash
          pkgs.util-linux
          pkgs.perl
          pkgs.cacert
          pkgs.openssl
          pkgs.glibcLocales
          pkgs.dbus
          pkgs.which
          pkgs.curl
          pkgs.nano
          pkgs.xorg.setxkbmap
          pkgs.xorg.xkbcomp
          pkgs.xorg.xrdb
          pkgs.xorg.xcbutil
          pkgs.xorg.xsetroot
          pkgs.xterm
          pkgs.openbox
          pkgs.findutils
          pkgs.gnugrep
          pkgs.kasmvnc
          pkgs.gnome-session
          pkgs.gnome-shell
          pkgs.gnome-terminal
          pkgs.nautilus
          pkgs.gnome-settings-daemon
          pkgs.firefox
        ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = devTools;
      };

      packages.${system} = {
        kasmvnc = pkgs.kasmvnc;
        desktop = pkgs.dockerTools.buildLayeredImage {
          name = "ghcr.io/a-h/kasm-nixos/desktop";
          tag = "latest";

          # Individual layers for each major component
          contents = [
            pkgs.dockerTools.fakeNss
            desktopEnv
            pkgs.openbox-config
            pkgs.dbus-config
            pkgs.xstartup-config
            pkgs.entrypoint-script
            xkbAndConfig
          ];

          config = {
            User = "root";
            Env = [
              "PATH=${desktopEnv}/bin:${pkgs.entrypoint-script}/bin"
              "HOME=/home/user"
              "LANG=en_US.UTF-8"
              "LANGUAGE=en_US.UTF-8"
              "LC_ALL=en_US.UTF-8"
              "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
              "DISPLAY=:1"
              "XDG_CURRENT_DESKTOP=GNOME"
              "XDG_SESSION_TYPE=x11"
              "XKB_CONFIG_ROOT=/etc/X11/xkb"
            ];
            Entrypoint = [
              "${pkgs.entrypoint-script}/bin/entrypoint.sh"
            ];
            Cmd = [
            ];
            ExposedPorts = {
              "6080/tcp" = { };
              "6901/tcp" = { };
            };
          };
        };
      };
    };
}