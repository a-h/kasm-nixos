#!/bin/sh
export DISPLAY=${DISPLAY:-:1}
export XDG_RUNTIME_DIR=/run/user/1000

# Start dbus-daemon with minimal config
echo "[xstartup] Starting dbus-daemon..." >&2
export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --fork --config-file=/etc/dbus-1/session.conf --print-address 2>/dev/null)

echo "[xstartup] DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
echo "[xstartup] X server is running at $DISPLAY"

# Set a desktop background
xsetroot -solid "#1e1e1e" &

# Start Openbox window manager
echo "[xstartup] Starting Openbox window manager..." >&2
exec openbox
