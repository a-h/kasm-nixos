{ stdenv }:

stdenv.mkDerivation {
  name = "rofi-config";
  
  unpackPhase = "true";
  dontUnpack = true;
  
  installPhase = ''
    mkdir -p $out/root/.config/rofi
    cp ${./rofi-config} $out/root/.config/rofi/config.rasi
  '';
}
