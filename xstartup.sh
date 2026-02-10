#!/bin/sh
export DISPLAY=${DISPLAY:-:1}
export XDG_RUNTIME_DIR=/run/user/1000

# Run the desktop environment (entrypoint already drops to kasm-user)
echo "[xstartup] Starting desktop environment as user..." >&2
set +e  # Continue on error for individual components
  
export DISPLAY="$DISPLAY"
export XDG_RUNTIME_DIR=/run/user/1000
export HOME=/home/kasm-user
export XDG_CONFIG_HOME=/home/kasm-user/.config
export XDG_CACHE_HOME=/home/kasm-user/.cache
export XDG_DATA_HOME=/home/kasm-user/.local/share
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export XDG_SESSION_TYPE=x11
export SSL_CERT_FILE="$SSL_CERT_FILE"
export NIX_SSL_CERT_FILE="$NIX_SSL_CERT_FILE"
  
  # Use standard FHS locations populated in the image
  export PATH="/usr/bin:$PATH"
  export XDG_CONFIG_DIRS="/etc/xdg"
  export XDG_DATA_DIRS="/usr/share:/usr/local/share"
  
  echo "[xstartup] XDG_CONFIG_DIRS=$XDG_CONFIG_DIRS" >&2
  echo "[xstartup] XDG_DATA_DIRS=$XDG_DATA_DIRS" >&2
  echo "[xstartup] PATH=$PATH" >&2
  
  # Create D-Bus session config at runtime (write to /tmp since /etc is read-only)
  mkdir -p /tmp/dbus-config
cat > /tmp/dbus-config/session.conf <<'EOF'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow receive_sender="*" eavesdrop="true"/>
    <allow own="*"/>
    <allow user="*"/>
  </policy>
</busconfig>
EOF
  
  # Start D-Bus session
  DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --config-file=/tmp/dbus-config/session.conf --print-address --fork 2>/dev/null)
  if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    echo "[xstartup] WARNING: Failed to start D-Bus, continuing anyway" >&2
  else
    export DBUS_SESSION_BUS_ADDRESS
    echo "[xstartup] DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" >&2
  fi
  
  echo "[xstartup] X server is running at $DISPLAY" >&2
  
  # Write D-Bus address to file for session components
  mkdir -p ~/.dbus/session-bus
  echo "$DBUS_SESSION_BUS_ADDRESS" > ~/.dbus/session-bus/address
  
  # Start a desktop background
  xsetroot -solid "#1e1e1e" &
  
  # Initialize panel configuration from defaults
  echo "[xstartup] Initializing panel configuration..." >&2
  mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
  if [ ! -f ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml ] && [ -f /etc/xdg/xfce4/panel/default.xml ]; then
    cp /etc/xdg/xfce4/panel/default.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
  fi
  
  # Start XFCE components directly (session manager has issues with Nix wrappers)
  echo "[xstartup] Starting XFCE components..." >&2
  
  # Track critical service failures
  CRITICAL_FAILURE=0
  STATUS_FILE=/tmp/desktop-status.txt
  echo "STARTING" > $STATUS_FILE
  
  # Start xfconfd for configuration management and wait for it to be ready (CRITICAL)
  echo "[xstartup] Starting xfconfd (critical)..." >&2
  if xfconfd 2>/dev/null &
  then
    XFCONFD_PID=$!
    echo "[xstartup] xfconfd started (PID $XFCONFD_PID)" >&2
    sleep 2
    # Verify xfconfd is accessible
    XFCONFD_READY=0
    for i in 1 2 3 4 5; do
      if xfconf-query -c xfce4-panel -l >/dev/null 2>&1; then
        echo "[xstartup] xfconfd is ready" >&2
        XFCONFD_READY=1
        break
      fi
      echo "[xstartup] Waiting for xfconfd..." >&2
      sleep 1
    done
    if [ $XFCONFD_READY -eq 0 ]; then
      echo "[xstartup] ERROR: xfconfd failed to become ready" >&2
      echo "CRITICAL_FAILURE: xfconfd not ready" >> $STATUS_FILE
      CRITICAL_FAILURE=1
    fi
  else
    echo "[xstartup] ERROR: Failed to start xfconfd" >&2
    echo "CRITICAL_FAILURE: xfconfd failed to start" >> $STATUS_FILE
    CRITICAL_FAILURE=1
  fi
  
  # Start window manager (CRITICAL for desktop usability)
  echo "[xstartup] Starting xfwm4 (critical)..." >&2
  if xfwm4 2>/dev/null &
  then
    XFWM4_PID=$!
    sleep 1
    if kill -0 $XFWM4_PID 2>/dev/null; then
      echo "[xstartup] xfwm4 is running (PID $XFWM4_PID)" >&2
    else
      echo "[xstartup] ERROR: xfwm4 exited immediately" >&2
      echo "CRITICAL_FAILURE: xfwm4 exited" >> $STATUS_FILE
      CRITICAL_FAILURE=1
    fi
  else
    echo "[xstartup] ERROR: Failed to start xfwm4" >&2
    echo "CRITICAL_FAILURE: xfwm4 failed to start" >> $STATUS_FILE
    CRITICAL_FAILURE=1
  fi
  
  # Start other XFCE components (OPTIONAL - enhance experience but not critical)
  echo "[xstartup] Starting optional components..." >&2
  xfsettingsd 2>/dev/null &
  sleep 1
  xfce4-panel 2>/dev/null &
  xfdesktop 2>/dev/null &
  
  # Report final status
  if [ $CRITICAL_FAILURE -eq 1 ]; then
    echo "[xstartup] CRITICAL FAILURES DETECTED - Desktop may not function properly" >&2
    echo "DEGRADED" >> $STATUS_FILE
    
    # Display visual error notification if xmessage is available
    if command -v xmessage >/dev/null 2>&1; then
      xmessage -center -buttons OK:0 -default OK \
        "WARNING: Critical Desktop Services Failed\n\nThe desktop environment is running in degraded mode.\nSome components failed to start.\n\nCheck /tmp/desktop-status.txt and /tmp/xstartup.log for details." &
    fi
  else
    echo "[xstartup] All critical services started successfully" >&2
    echo "HEALTHY" >> $STATUS_FILE
  fi
  
  cat $STATUS_FILE >&2
  
  echo "[xstartup] XFCE startup complete, keeping session alive" >&2
  
  # Keep the session alive indefinitely
  while true; do
    sleep 60
  done
