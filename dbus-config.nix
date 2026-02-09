{ stdenv }:

stdenv.mkDerivation {
  name = "dbus-config";
  
  unpackPhase = "true";
  dontUnpack = true;
  
  installPhase = ''
    mkdir -p $out/etc/dbus-1/session.d
    cp ${./dbus-session.conf} $out/etc/dbus-1/session.d/kasm.conf
  '';
}
