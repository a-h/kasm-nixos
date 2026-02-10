{ writeShellScriptBin, kasmvnc, dbus, xkeyboard-config, xorg, util-linux }:

writeShellScriptBin "entrypoint.sh" ''
  #!/bin/bash
  set -e

  export PATH="${dbus}/bin:$PATH"

  # Docker exec rejects symlinked /etc/passwd that points outside the container root.
  # Replace symlinks with real files early so Kasm provisioning can exec into the container.
  for f in /etc/passwd /etc/group /etc/shadow; do
    if [ -L "$f" ]; then
      tmp="$(mktemp)"
      cp -L "$f" "$tmp"
      rm -f "$f"
      mv "$tmp" "$f"
      chmod 644 "$f"
    fi
  done
  chmod 600 /etc/shadow 2>/dev/null || true

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
  mkdir -p /tmp /run /tmp/.X11-unix
  chmod 1777 /tmp /tmp/.X11-unix
  
  # Create required directories
  mkdir -p /home/user/.vnc
  mkdir -p /tmp/.X11-unix

  # Ensure the Kasm user exists for the desktop session
  if ! grep -q '^kasm-user:' /etc/passwd; then
    echo 'kasm-user:x:1000:1000:Kasm User:/home/kasm-user:/bin/bash' >> /etc/passwd
  fi
  if ! grep -q '^kasm-user:' /etc/group; then
    echo 'kasm-user:x:1000:' >> /etc/group
  fi
  mkdir -p /home/kasm-user
  chown -R 1000:1000 /home/kasm-user
  
  # Set up user's home directory with proper permissions
  mkdir -p /home/kasm-user/.config /home/kasm-user/.cache /home/kasm-user/.local/share
  chown -R 1000:1000 /home/kasm-user

  # Ensure user runtime dir exists for D-Bus
  mkdir -p /run/user/1000
  chown 1000:1000 /run/user/1000
  chmod 0700 /run/user/1000
  
  # Generate self-signed SSL certificate for websocket
  mkdir -p /home/kasm-user/.vnc
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /home/kasm-user/.vnc/self.pem \
    -out /home/kasm-user/.vnc/self.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null || true
  
  if [ -f /home/kasm-user/.vnc/self.pem ]; then
    chmod 600 /home/kasm-user/.vnc/self.pem
    chown 1000:1000 /home/kasm-user/.vnc/self.pem
    echo "SSL certificate generated: /home/kasm-user/.vnc/self.pem"
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
   
  WEBSOCKET_PORT="''${NO_VNC_PORT:-6901}"

  # Start KasmVNC server (websocket on 6901)
  echo "Starting KasmVNC (websocket on ''${WEBSOCKET_PORT})..."
  ${util-linux}/bin/setpriv --reuid=1000 --regid=1000 --clear-groups -- ${kasmvnc}/bin/Xvnc "$DISPLAY" \
    -geometry ''${VNC_RESOLUTION:-1920x1080} \
    -depth 24 \
    -RectThreads 0 \
    -SecurityTypes None \
    -httpd ${kasmvnc}/share/kasmvnc/www \
    -websocketPort ''${WEBSOCKET_PORT} \
    -DisableBasicAuth \
    -FrameRate ''${MAX_FRAME_RATE:-30} \
    -interface 0.0.0.0 &
  XVNC_PID=$!
  
  # Give Xvnc time to initialize
  sleep 2

  # Start the desktop environment via xstartup script
  ${util-linux}/bin/setpriv --reuid=1000 --regid=1000 --clear-groups -- /root/.vnc/xstartup > /tmp/xstartup.log 2>&1 &
  XSTARTUP_PID=$!

  # Ensure children are properly cleaned up on exit
  cleanup() {
    echo "[entrypoint] Shutting down services..." >&2
    kill $XVNC_PID $XSTARTUP_PID 2>/dev/null || true
    exit 0
  }
  trap cleanup TERM INT EXIT
  
  # Health check and monitoring
  echo "[entrypoint] Services started: Xvnc PID=$XVNC_PID, xstartup PID=$XSTARTUP_PID" >&2
  
  # Monitor services and log warnings if they die
  while true; do
    if ! kill -0 $XVNC_PID 2>/dev/null; then
      echo "[WARNING] KasmVNC (PID $XVNC_PID) has exited unexpectedly" | tee -a /tmp/container-health.log >&2
    fi
    if ! kill -0 $XSTARTUP_PID 2>/dev/null; then
      echo "[WARNING] xstartup session (PID $XSTARTUP_PID) has exited. Check /tmp/xstartup.log for details" | tee -a /tmp/container-health.log >&2
    fi
    sleep 10
  done
''
