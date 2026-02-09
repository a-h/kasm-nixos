{ stdenv }:

stdenv.mkDerivation {
  name = "xstartup-config";
  
  unpackPhase = "true";
  dontUnpack = true;
  
  installPhase = ''
    mkdir -p $out/root/.vnc
    cp ${./xstartup.sh} $out/root/.vnc/xstartup
    chmod +x $out/root/.vnc/xstartup
  '';
}
