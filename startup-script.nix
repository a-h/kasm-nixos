{ writeShellScriptBin, kasmvnc, dbus, xkeyboard-config }:

writeShellScriptBin "entrypoint.sh" ''
  #!/bin/bash
  set -e

  export PATH="${dbus}/bin:$PATH"

  DISPLAY="''${DISPLAY:-:1}"
  export DISPLAY

  # Ensure standard runtime dirs exist
  mkdir -p /tmp /tmp/.X11-unix
  
  # Generate self-signed SSL certificate for websocket
  mkdir -p /home/kasm-user/.vnc
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /home/kasm-user/.vnc/self.pem \
    -out /home/kasm-user/.vnc/self.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null || true
  
  if [ -f /home/kasm-user/.vnc/self.pem ]; then
    chmod 600 /home/kasm-user/.vnc/self.pem
    echo "SSL certificate generated: /home/kasm-user/.vnc/self.pem"
  fi
  
  # Create runtime directories for X11
  mkdir -p /tmp/.X11-unix
  mkdir -p /tmp/xkb-cache
  export XKBCOMPILED_DIR=/tmp/xkb-cache
   
  WEBSOCKET_PORT="''${NO_VNC_PORT:-6901}"

  # Start KasmVNC server (websocket on 6901)
  echo "Starting KasmVNC (websocket on ''${WEBSOCKET_PORT})..."
  ${kasmvnc}/bin/Xvnc "$DISPLAY" \
    -geometry ''${VNC_RESOLUTION:-1920x1080} \
    -depth 24 \
    -RectThreads 0 \
    -SecurityTypes None \
    -xkbdir ${xkeyboard-config}/share/X11/xkb \
    -httpd ${kasmvnc}/share/kasmvnc/www \
    -websocketPort ''${WEBSOCKET_PORT} \
    -DisableBasicAuth \
    -FrameRate ''${MAX_FRAME_RATE:-30} \
    -interface 0.0.0.0 &
  XVNC_PID=$!
  
  # Give Xvnc time to initialize
  sleep 2

  # Start the desktop environment via xstartup script
  /root/.vnc/xstartup > /tmp/xstartup.log 2>&1 &
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
