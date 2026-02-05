{ writeShellScriptBin, kasmvnc, gnome-session, dbus }:

writeShellScriptBin "startup.sh" ''
  #!/bin/bash
  set -ex
  
  # Create required directories
  mkdir -p /home/user/.vnc
  mkdir -p /tmp/.X11-unix
  
  # Create VNC xstartup script
  cat > /home/user/.vnc/xstartup <<'EOF'
#!/bin/sh

# Set up environment
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start D-Bus session bus
if [ -x ${dbus}/bin/dbus-launch ]; then
  eval $(${dbus}/bin/dbus-launch --sh-syntax --exit-with-session)
fi

# Start GNOME session
exec ${gnome-session}/bin/gnome-session
EOF
  chmod +x /home/user/.vnc/xstartup
  
  # Set VNC password
  VNC_PW=''${VNC_PW:-password}
  echo -e "''${VNC_PW}\n''${VNC_PW}\n" | ${kasmvnc}/bin/kasmvncpasswd -u kasm_user -wo
  chmod 600 /home/user/.kasmpasswd
  
  # Start D-Bus
  export $(${dbus}/bin/dbus-launch)
  
  # Start KasmVNC server in foreground (-fg) with GNOME desktop
  # This provides the web-accessible VNC on port 6901
  exec ${kasmvnc}/bin/kasmvncserver :0 \
    -fg \
    -SecurityTypes None \
    -geometry ''${VNC_RESOLUTION:-1920x1080} \
    -depth 24 \
    -websocketPort 6901 \
    -httpd ${kasmvnc}/share/kasmvnc/www \
    -sslOnly \
    -FrameRate ''${MAX_FRAME_RATE:-30} \
    -interface 0.0.0.0
''
