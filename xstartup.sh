#!/bin/sh
export DISPLAY=${DISPLAY:-:1}
export XDG_RUNTIME_DIR=/run/user/1000

# Run the desktop environment as user 1000 using setpriv
echo "[xstartup] Starting desktop environment as user..." >&2
exec setpriv --reuid=1000 --regid=1000 --init-groups sh -c '
  export DISPLAY='"$DISPLAY"'
  export XDG_RUNTIME_DIR=/run/user/1000
  export HOME=/home/user
  export XDG_CONFIG_HOME=/home/user/.config
  export XDG_CACHE_HOME=/home/user/.cache
  export XDG_DATA_HOME=/home/user/.local/share
  export XDG_CURRENT_DESKTOP=XFCE
  export XDG_SESSION_DESKTOP=xfce
  export XDG_SESSION_TYPE=x11
  export SSL_CERT_FILE='"$SSL_CERT_FILE"'
  export NIX_SSL_CERT_FILE='"$NIX_SSL_CERT_FILE"'
  
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
  export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --config-file=/tmp/dbus-config/session.conf --print-address --fork)
  echo "[xstartup] DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" >&2
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
  
  # Start xfconfd for configuration management and wait for it to be ready
  xfconfd &
  sleep 2
  # Verify xfconfd is accessible
  for i in 1 2 3 4 5; do
    if xfconf-query -c xfce4-panel -l >/dev/null 2>&1; then
      echo "[xstartup] xfconfd is ready" >&2
      break
    fi
    echo "[xstartup] Waiting for xfconfd..." >&2
    sleep 1
  done
  
  xfsettingsd &
  sleep 1
  xfwm4 &
  sleep 1
  xfce4-panel &
  xfdesktop &
  
  # Keep the session alive
  sleep infinity
'

