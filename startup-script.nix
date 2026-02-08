{ writeShellScriptBin, kasmvnc, dbus, xkeyboard-config, xorg }:

writeShellScriptBin "entrypoint.sh" ''
  #!/bin/bash
  set -ex

  export PATH="${dbus}/bin:$PATH"

  DISPLAY="''${DISPLAY:-:1}"
  export DISPLAY

  # Ensure machine-id exists for D-Bus
  if [ ! -s /etc/machine-id ]; then
    ${dbus}/bin/dbus-uuidgen --ensure=/etc/machine-id
  fi
  mkdir -p /var/lib/dbus
  if [ ! -s /var/lib/dbus/machine-id ]; then
    ln -sf /etc/machine-id /var/lib/dbus/machine-id
  fi

  # Ensure standard runtime dirs exist
  mkdir -p /tmp /run
  chmod 1777 /tmp
  
  # Create required directories
  mkdir -p /home/user/.vnc
  mkdir -p /tmp/.X11-unix

  # Ensure a non-root user exists for the desktop session
  if ! grep -q '^user:' /etc/passwd; then
    echo 'user:x:1000:1000::/home/user:/bin/sh' >> /etc/passwd
  fi
  if ! grep -q '^user:' /etc/group; then
    echo 'user:x:1000:' >> /etc/group
  fi
  mkdir -p /home/user
  chown -R 1000:1000 /home/user

  # Ensure user runtime dir exists for D-Bus
  mkdir -p /run/user/1000
  chown 1000:1000 /run/user/1000
  chmod 0700 /run/user/1000
  
  # Generate self-signed SSL certificate for websocket
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /home/user/.vnc/self.pem \
    -out /home/user/.vnc/self.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null || true
  
  if [ -f /home/user/.vnc/self.pem ]; then
    chmod 600 /home/user/.vnc/self.pem
    chown 1000:1000 /home/user/.vnc/self.pem
    echo "SSL certificate generated: /home/user/.vnc/self.pem"
  fi
  
  # Xvnc was compiled with hardcoded paths for XKB
  # buildLayeredImage doesn't preserve symlinks, so recreate them at runtime
  rm -rf /usr/share/X11/xkb /etc/X11/xkb
  mkdir -p /usr/share/X11 /etc/X11 /usr/bin
  ln -s "${xkeyboard-config}/share/X11/xkb" /usr/share/X11/xkb
  ln -s "${xkeyboard-config}/share/X11/xkb" /etc/X11/xkb
  
  # Xvnc expects xkbcomp at /usr/bin/xkbcomp
  ln -sf "${xorg.xkbcomp}/bin/xkbcomp" /usr/bin/xkbcomp
  
  # Create runtime directories for X11
  mkdir -p /tmp/.X11-unix
  mkdir -p /tmp/xkb-cache
  export XKBCOMPILED_DIR=/tmp/xkb-cache
   
  # Create minimal input device files for Xvnc
  mkdir -p /dev/input
  touch /dev/input/mice /dev/input/keyboard
  touch /dev/input/event0 /dev/input/event1 /dev/input/event2
   
  # Start KasmVNC server (websocket on 6901)
  echo "Starting KasmVNC (websocket on 6901)..."
  ${kasmvnc}/bin/Xvnc "$DISPLAY" \
    -geometry ''${VNC_RESOLUTION:-1920x1080} \
    -depth 24 \
    -RectThreads 0 \
    -SecurityTypes None \
    -websocketPort 6901 \
    -httpd ${kasmvnc}/share/kasmvnc/www \
    -DisableBasicAuth \
    -cert /home/user/.vnc/self.pem \
    -key /home/user/.vnc/self.pem \
    -FrameRate ''${MAX_FRAME_RATE:-30} \
    -interface 0.0.0.0 \
    &
  XVNC_PID=$!
  
  # Give Xvnc time to initialize
  sleep 2

  # Start the desktop environment via xstartup script
  /root/.vnc/xstartup &

  # Keep the container running
  wait $XVNC_PID
''

