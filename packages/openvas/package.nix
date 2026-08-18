{
  lib,
  stdenv,
  autoPatchelfHook,
  bison,
  cmake,
  cmakeFlags ? [ ],
  curl,
  doxygen,
  fetchFromGitHub,
  file,
  git,
  glib,
  gnutls,
  gpgme,
  gvm-libs,
  json-glib,
  krb5,
  libbsd,
  libclang,
  libgcrypt,
  libksba,
  libpcap,
  libsepol,
  libssh,
  libtasn1,
  makeWrapper,
  net-snmp,
  nmap,
  p11-kit,
  paho-mqtt-c,
  pandoc,
  pcre2,
  pkg-config,
  util-linux,
}:

let
  defaultCmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_INSTALL_PREFIX=/usr"
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "openvas-scanner";
  version = "23.50.17";

  src = fetchFromGitHub {
    owner = "greenbone";
    repo = "openvas-scanner";
    tag = "v${finalAttrs.version}";
    hash = "sha256-tkXgI6KRens2sELlyHQYu4Wh1lFHKzNGQ3SCZFLQLOc=";
  };

  patches = [ ./fix-gcc-warnings.patch ];

  nativeBuildInputs = [
    autoPatchelfHook
    bison
    cmake
    doxygen
    git
    makeWrapper
    pandoc
    pkg-config
  ];

  buildInputs = [
    curl
    file
    glib
    gnutls
    gpgme
    gvm-libs
    json-glib
    krb5
    libbsd
    libclang
    libgcrypt
    libksba
    libpcap
    libsepol
    libssh
    libtasn1
    net-snmp
    p11-kit
    paho-mqtt-c
    pcre2
    util-linux
  ];

  # Consumer flags are appended so appliance builds can specialize runtime
  # paths with `.override { cmakeFlags = [ ... ]; }` without repeating these
  # package defaults.
  cmakeFlags = defaultCmakeFlags ++ cmakeFlags;

  installPhase = ''
    runHook preInstall

    DESTDIR="$out" cmake --install .

    mkdir -p "$out/bin"
    ln -s "$out/usr/sbin/openvas" "$out/bin/openvas"

    for program in openvas-nasl openvas-nasl-lint; do
      if [[ -x "$out/usr/bin/$program" ]]; then
        ln -s "$out/usr/bin/$program" "$out/bin/$program"
      fi
    done

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/usr/sbin/openvas" \
      --prefix PATH : ${lib.makeBinPath [ nmap ]}
  '';

  meta = {
    description = "Scanner component for Greenbone Community Edition";
    homepage = "https://github.com/greenbone/openvas-scanner";
    changelog = "https://github.com/greenbone/openvas-scanner/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.gpl2Only;
    mainProgram = "openvas";
    platforms = lib.platforms.linux;
  };
})
