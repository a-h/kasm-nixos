{ lib, stdenv, fetchurl, dpkg, makeWrapper, libX11, perl, perlPackages, xauth, hostname, coreutils }:

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
  ];

  buildInputs = [
    libX11
    perl
    perlPackages.Switch
    perlPackages.ListMoreUtils
    perlPackages.TryTiny
    perlPackages.DateTime
    perlPackages.YAMLTiny
    perlPackages.HashMergeSimple
    xauth
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
    
    # Copy share data (icons, applications, etc.)
    if [ -d usr/share ]; then
      mkdir -p $out/share
      cp -r usr/share/* $out/share/
    fi
    
    runHook postInstall
  '';

  postFixup = let
    path = lib.makeBinPath [ perlEnv xauth hostname coreutils ];
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
          --prefix PATH : "$out/bin:${path}"
      fi
    done
  '';

  meta = with lib; {
    description = "High-performance VNC server based on TurboVNC and noVNC";
    homepage = "https://github.com/kasmtech/KasmVNC";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
