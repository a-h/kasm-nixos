{ stdenv }:

stdenv.mkDerivation {
  name = "openbox-config";
  
  src = ./openbox-rc.xml;
  
  unpackPhase = "true";
  
  installPhase = ''
    mkdir -p $out/root/.config/openbox
    cp ${./openbox-rc.xml} $out/root/.config/openbox/rc.xml
  '';
}
