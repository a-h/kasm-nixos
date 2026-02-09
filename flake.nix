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
            xstartup-config = final.callPackage ./xstartup-config.nix { };
            version = version.packages.${system}.default;
          })
        ];
      };

      # FHS image layout with all required configs and directories
      fhsLayout = pkgs.runCommand "fhs-layout" { } ''
        set -e
        mkdir -p $out
        
        # XKB files at standard location
        mkdir -p $out/etc/X11
        cp -r ${pkgs.xkeyboard-config}/share/X11/xkb $out/etc/X11/
        mkdir -p $out/usr/share/X11
        cp -r ${pkgs.xkeyboard-config}/share/X11/xkb $out/usr/share/X11/
        
        # D-Bus configuration (both paths for compatibility)
        mkdir -p $out/etc/dbus-1/session.d
        cp ${./dbus-session.conf} $out/etc/dbus-1/session.conf
        cp ${./dbus-session.conf} $out/etc/dbus-1/session.d/kasm.conf
        
        # Device directories for X11 input
        mkdir -p $out/proc/bus/input
        mkdir -p $out/dev/input
        mkdir -p $out/dev/shm
        
        # Runtime directories
        mkdir -p $out/run/user/1000
        mkdir -p $out/var/lib/dbus
        mkdir -p $out/tmp
        mkdir -p $out/etc/xdg

        # XDG defaults and D-Bus services at FHS locations
        cp -rL ${pkgs.xfce.xfce4-session}/etc/xdg/. $out/etc/xdg/ 2>/dev/null || true
        # Ensure panel config directory exists and copy panel defaults
        chmod -R u+w $out/etc/xdg 2>/dev/null || true
        mkdir -p $out/etc/xdg/xfce4/panel
        if [ -f ${pkgs.xfce.xfce4-panel}/etc/xdg/xfce4/panel/default.xml ]; then
          cp ${pkgs.xfce.xfce4-panel}/etc/xdg/xfce4/panel/default.xml $out/etc/xdg/xfce4/panel/default.xml
        fi
        mkdir -p $out/usr/share/dbus-1/services
        # Create xfconf D-Bus service file with correct path
        cat > $out/usr/share/dbus-1/services/org.xfce.Xfconf.service <<'EOF'
[D-BUS Service]
Name=org.xfce.Xfconf
Exec=${pkgs.xfce.xfconf}/lib/xfce4/xfconf/xfconfd
SystemdService=xfconfd.service
EOF
        # Create xfce4-notifyd D-Bus service if panel provides it
        if [ -f ${pkgs.xfce.xfce4-panel}/share/dbus-1/services/org.xfce.Panel.service ]; then
          cp ${pkgs.xfce.xfce4-panel}/share/dbus-1/services/org.xfce.Panel.service $out/usr/share/dbus-1/services/
        fi
        cp -rL ${pkgs.gsettings-desktop-schemas}/share/glib-2.0 $out/usr/share/ 2>/dev/null || true
        mkdir -p $out/usr/share/xfce4
        cp -rL ${pkgs.xfce.xfce4-session}/share/xfce4/. $out/usr/share/xfce4/ 2>/dev/null || true
        cp -rL ${pkgs.xfce.xfce4-settings}/share/xfce4/. $out/usr/share/xfce4/ 2>/dev/null || true
        cp -rL ${pkgs.xfce.xfce4-panel}/share/xfce4/. $out/usr/share/xfce4/ 2>/dev/null || true
        cp -rL ${pkgs.xfce.xfdesktop}/share/xfce4/. $out/usr/share/xfce4/ 2>/dev/null || true
        mkdir -p $out/usr/share/applications
        cp -rL ${pkgs.xfce.xfce4-session}/share/applications/. $out/usr/share/applications/ 2>/dev/null || true
        cp -rL ${pkgs.xfce.xfce4-panel}/share/applications/. $out/usr/share/applications/ 2>/dev/null || true
        cp -rL ${pkgs.xfce.xfce4-settings}/share/applications/. $out/usr/share/applications/ 2>/dev/null || true
        cp -rL ${pkgs.xfce.xfdesktop}/share/applications/. $out/usr/share/applications/ 2>/dev/null || true
        cp -rL ${pkgs.xfce.thunar}/share/applications/. $out/usr/share/applications/ 2>/dev/null || true
        
        # Copy icon themes to /usr/share/icons for proper icon display
        mkdir -p $out/usr/share/icons
        cp -rL ${pkgs.hicolor-icon-theme}/share/icons/. $out/usr/share/icons/ 2>/dev/null || true
        cp -rL ${pkgs.adwaita-icon-theme}/share/icons/. $out/usr/share/icons/ 2>/dev/null || true
        # Copy icons from XFCE packages
        for pkg in ${pkgs.xfce.xfwm4} ${pkgs.xfce.xfce4-panel} ${pkgs.xfce.xfdesktop} ${pkgs.xfce.xfce4-settings}; do
          if [ -d "$pkg/share/icons" ]; then
            cp -rL "$pkg/share/icons/." $out/usr/share/icons/ 2>/dev/null || true
          fi
        done
        
        # Session descriptors - symlink xsessions from xfce4-session to standard location
        mkdir -p $out/usr/share/xsessions
        ln -s ${pkgs.xfce.xfce4-session}/share/xsessions/xfce.desktop $out/usr/share/xsessions/xfce.desktop
        
        # Symlink XFCE4 binaries to /usr/bin for compatibility with session files
        mkdir -p $out/usr/bin
        ln -s ${pkgs.xfce.xfce4-session}/bin/xfce4-session $out/usr/bin/xfce4-session
        ln -s ${pkgs.xfce.xfwm4}/bin/xfwm4 $out/usr/bin/xfwm4
        ln -s ${pkgs.xfce.xfce4-panel}/bin/xfce4-panel $out/usr/bin/xfce4-panel
        ln -s ${pkgs.xfce.xfce4-settings}/bin/xfsettingsd $out/usr/bin/xfsettingsd
        ln -s ${pkgs.xfce.xfdesktop}/bin/xfdesktop $out/usr/bin/xfdesktop
        ln -s ${pkgs.xfce.thunar}/bin/Thunar $out/usr/bin/Thunar
        ln -s ${pkgs.xfce.xfconf}/lib/xfce4/xfconf/xfconfd $out/usr/bin/xfconfd
        ln -s ${pkgs.xterm}/bin/xterm $out/usr/bin/xterm
        ln -s ${pkgs.firefox}/bin/firefox $out/usr/bin/firefox
        
        # Create desktop application entries
        cat > $out/usr/share/applications/xterm.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=X Terminal Emulator
Exec=xterm
Icon=utilities-terminal
Categories=System;TerminalEmulator;
Terminal=false
EOF
        
        cat > $out/usr/share/applications/firefox.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox Web Browser
Comment=Browse the World Wide Web
Exec=firefox %u
Icon=firefox
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;
Terminal=false
EOF
        
        # KasmVNC configuration
        mkdir -p $out/usr/share/kasmvnc
        mkdir -p $out/etc/kasmvnc
        cp ${./kasmvnc_defaults.yaml} $out/usr/share/kasmvnc/kasmvnc_defaults.yaml
        
        # CA certificates for NSS/p11-kit
        mkdir -p $out/etc/ssl/certs
        mkdir -p $out/etc/pki/tls/certs
        ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/ca-bundle.crt
        ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/pki/tls/certs/ca-bundle.crt
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
          pkgs.shadow
          pkgs.perl
          pkgs.cacert
          pkgs.openssl
          pkgs.glibcLocales
          pkgs.dbus
          pkgs.glib
          pkgs.gsettings-desktop-schemas
          pkgs.which
          pkgs.curl
          pkgs.nano
          pkgs.xorg.setxkbmap
          pkgs.xorg.xkbcomp
          pkgs.xorg.xrdb
          pkgs.xorg.xcbutil
          pkgs.xorg.xsetroot
          pkgs.xterm
          pkgs.xfce.xfce4-session
          pkgs.xfce.xfwm4
          pkgs.xfce.xfce4-panel
          pkgs.xfce.xfce4-settings
          pkgs.xfce.xfce4-appfinder
          pkgs.xfce.xfconf
          pkgs.xfce.thunar
          pkgs.xfce.xfdesktop
          pkgs.hicolor-icon-theme
          pkgs.adwaita-icon-theme
          pkgs.xdg-utils
          pkgs.desktop-file-utils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.kasmvnc
          pkgs.gnome-terminal
          pkgs.nautilus
          pkgs.firefox
          pkgs.p11-kit
          pkgs.nssTools
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
            pkgs.xstartup-config
            pkgs.entrypoint-script
            fhsLayout
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
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
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