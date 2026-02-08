{ stdenv }:

stdenv.mkDerivation {
  name = "dbus-config";
  
  src = ./dbus-session.conf;
  
  unpackPhase = "true";
  
  installPhase = ''
    mkdir -p $out/etc/dbus-1
    cp ${./dbus-session.conf} $out/etc/dbus-1/session.conf
  '';
}
