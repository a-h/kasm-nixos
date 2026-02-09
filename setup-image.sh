#!/bin/bash
# Setup script to prepare FHS-like structure and configs at build time

set -e

OUTPUT_DIR="${1:-.}"

echo "Setting up FHS image structure..."

# D-Bus configuration directory
mkdir -p "$OUTPUT_DIR/etc/dbus-1/session.d"
cp dbus-session.conf "$OUTPUT_DIR/etc/dbus-1/session.conf"
cp dbus-session.conf "$OUTPUT_DIR/etc/dbus-1/session.d/kasm.conf"

# XKB configuration
mkdir -p "$OUTPUT_DIR/etc/X11"
mkdir -p "$OUTPUT_DIR/usr/share/X11"

# Device directories
mkdir -p "$OUTPUT_DIR/proc/bus/input"
mkdir -p "$OUTPUT_DIR/dev/input"
mkdir -p "$OUTPUT_DIR/dev/shm"

# Runtime directories
mkdir -p "$OUTPUT_DIR/run/user/1000"
mkdir -p "$OUTPUT_DIR/var/lib/dbus"
mkdir -p "$OUTPUT_DIR/tmp"

# D-Bus machine ID
touch "$OUTPUT_DIR/etc/machine-id"

# XDG directories
mkdir -p "$OUTPUT_DIR/etc/xdg"

echo "FHS setup complete"
