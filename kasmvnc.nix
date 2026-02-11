{ lib, stdenv, fetchurl, dpkg, makeWrapper, autoPatchelfHook
, libX11, libXext, libXrender, libXrandr, libXtst, libXdamage, libXfixes
, libxkbcommon, libxcb, libdrm, mesa, libGL, wayland
, perl, perlPackages, xauth, hostname, coreutils, openssl
, libXcursor, libxcrypt-legacy, libunwind, pixman, libXfont2, libwebp, freetype, libbsd }:

let
  perlEnv = perl.withPackages (p: [
    p.Switch
    p.ListMoreUtils
    p.TryTiny
    p.DateTime
    p.YAMLTiny
    p.HashMergeSimple
  ]);
in
stdenv.mkDerivation rec {
  pname = "kasmvnc";
  version = "1.3.3";

  src = fetchurl {
    url = "https://github.com/kasmtech/KasmVNC/releases/download/v${version}/kasmvncserver_bookworm_${version}_amd64.deb";
    sha256 = "1h652pknlb08aksw30ciysh0k1q3qzipmfz5nkxrp17aiqhzdh4b";
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    libX11
    libXext
    libXrender
    libXrandr
    libXtst
    libXdamage
    libXfixes
    libxkbcommon
    libxcb
    libdrm
    mesa
    libGL
    wayland
    openssl
    stdenv.cc.cc.lib
    libXcursor
    libxcrypt-legacy
    libunwind
    pixman
    libXfont2
    libwebp
    freetype
    libbsd
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    
    # Copy binaries
    mkdir -p $out/bin
    cp -r usr/bin/* $out/bin/
    
    # Copy libraries
    if [ -d usr/lib ]; then
      mkdir -p $out/lib
      cp -r usr/lib/* $out/lib/
    fi
    
    # Copy Perl modules from usr/share/perl5
    if [ -d usr/share/perl5 ]; then
      mkdir -p $out/lib/perl5
      cp -r usr/share/perl5/* $out/lib/perl5/
    fi
    
    # Copy share data (icons, applications, www, etc.)
    if [ -d usr/share ]; then
      mkdir -p $out/share
      cp -r usr/share/* $out/share/
    fi
    
    runHook postInstall
  '';

  postFixup = let
    path = lib.makeBinPath [ perlEnv xauth hostname coreutils openssl ];
  in ''
    # Create compatibility symlinks since kasmvncserver expects standard VNC names
    ln -sf $out/bin/Xkasmvnc $out/bin/Xvnc
    ln -sf $out/bin/kasmvncpasswd $out/bin/vncpasswd
    
    # Fix shebangs and wrap vncserver Perl script with required environment
    for script in $out/bin/vncserver $out/bin/kasmvncserver; do
      if [ -f "$script" ]; then
        # Replace the shebang to point to the Perl with packages
        sed -i "1s|^#!.*perl|#!${perlEnv}/bin/perl|" "$script"
        
        wrapProgram "$script" \
          --prefix PERL5LIB : "$out/lib/perl5" \
          --prefix PATH : "$out/bin:${path}" \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"
      fi
    done
    
    # Wrap Xkasmvnc binary to ensure library paths are set
    wrapProgram $out/bin/Xkasmvnc \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --prefix PATH : "${path}"
  '';

  meta = with lib; {
    description = "High-performance VNC server based on TurboVNC and noVNC";
    homepage = "https://github.com/kasmtech/KasmVNC";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
