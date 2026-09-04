{
  lib,
  stdenv,
  cjson,
  cmake,
  curl,
  doxygen,
  fetchFromGitHub,
  glib,
  gnutls,
  gpgme,
  hiredis,
  libgcrypt,
  libnet,
  libpcap,
  libssh,
  libuuid,
  libxcrypt,
  libxml2,
  openldap,
  paho-mqtt-c,
  pkg-config,
  radcli,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gvm-libs";
  version = "23.10.0";

  src = fetchFromGitHub {
    owner = "greenbone";
    repo = "gvm-libs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-v4MiVL+eIXS+nmLZC4dEcQWxtlgnwVDGnHw2pZLFPCE=";
  };

  # Dependency warnings should not make downstream OpenVAS updates fail.
  # Keep /run/gvm as the compiled runtime location, but do not attempt to
  # create that mutable directory while installing into the Nix store.
  postPatch = ''
    substituteInPlace CMakeLists.txt --replace-fail "-Werror" ""
    substituteInPlace base/CMakeLists.txt \
      --replace-fail 'install(DIRECTORY DESTINATION ''${GVM_RUN_DIR})' ""
  '';

  nativeBuildInputs = [
    cmake
    doxygen
    pkg-config
  ];

  buildInputs = [
    cjson
    curl
    glib
    gnutls
    gpgme
    hiredis
    libgcrypt
    libnet
    libpcap
    libssh
    libuuid
    libxcrypt
    libxml2
    openldap
    paho-mqtt-c
    radcli
    zlib
  ];

  cmakeFlags = [ "-DGVM_RUN_DIR=/run/gvm" ];

  # gvm-libs defines its own fortify level.
  hardeningDisable = [ "fortify3" ];

  meta = {
    description = "Libraries module for the Greenbone Vulnerability Management Solution";
    homepage = "https://github.com/greenbone/gvm-libs";
    changelog = "https://github.com/greenbone/gvm-libs/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
})
