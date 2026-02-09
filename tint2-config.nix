{ stdenv }:

stdenv.mkDerivation {
  name = "tint2-config";
  
  unpackPhase = "true";
  dontUnpack = true;
  
  installPhase = ''
    mkdir -p $out/root/.config/tint2
    cp ${./tint2rc} $out/root/.config/tint2/tint2rc
  '';
}
