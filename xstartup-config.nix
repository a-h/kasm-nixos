{ stdenv }:

stdenv.mkDerivation {
  name = "xstartup-config";
  
  src = ./xstartup.sh;
  
  unpackPhase = "true";
  
  installPhase = ''
    mkdir -p $out/root/.vnc
    cp ${./xstartup.sh} $out/root/.vnc/xstartup
    chmod +x $out/root/.vnc/xstartup
  '';
}
