{ writeTextFile }:

writeTextFile {
  name = "xstartup";
  text = ''
    #!/bin/sh
    
    # Set up environment
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    
    # Start D-Bus session bus
    if [ -x /usr/bin/dbus-launch ]; then
      eval $(dbus-launch --sh-syntax --exit-with-session)
    fi
    
    # Start GNOME session
    exec gnome-session
  '';
  executable = true;
}
