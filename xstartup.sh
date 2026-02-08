#!/bin/sh
export DISPLAY=${DISPLAY:-:1}
export XDG_RUNTIME_DIR=/run/user/1000

# Run the desktop environment as user 1000 using setpriv
echo "[xstartup] Starting desktop environment as user..." >&2
exec setpriv --reuid=1000 --regid=1000 --init-groups sh -c '
  export DISPLAY='"$DISPLAY"'
  export XDG_RUNTIME_DIR=/run/user/1000
  export HOME=/home/user
  
  # Start dbus-daemon
  export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --fork --config-file=/etc/dbus-1/session.conf --print-address 2>/dev/null)
  echo "[xstartup] DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" >&2
  echo "[xstartup] X server is running at $DISPLAY" >&2
  
  # Set a desktop background
  xsetroot -solid "#1e1e1e" &
  
  # Start Openbox window manager
  echo "[xstartup] Starting Openbox window manager as user..." >&2
  exec openbox
'
