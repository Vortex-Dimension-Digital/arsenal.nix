{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  dnsutils,
  coreutils,
  openssl,
  net-tools,
  util-linux,
  procps,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "testssl.sh";
  version = "3.2.4";

  src = fetchFromGitHub {
    owner = "testssl";
    repo = "testssl.sh";
    tag = "v${finalAttrs.version}";
    hash = "sha256-mZBERNCgLga13+BtzkpXNurDz9ZI6p9flfr+W7WoTiU=";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    coreutils
    dnsutils
    net-tools
    openssl
    procps
    util-linux
  ];

  postPatch = ''
    substituteInPlace testssl.sh \
      --replace-fail TESTSSL_INSTALL_DIR:-\"\"   TESTSSL_INSTALL_DIR:-\"$out\" \
      --replace-fail PROG_NAME=\"\$\(basename\ \"\$0\"\)\" PROG_NAME=\"testssl.sh\"
  '';

  installPhase = ''
    install -D testssl.sh $out/bin/testssl.sh
    cp -r etc $out

    wrapProgram $out/bin/testssl.sh --prefix PATH ':' ${lib.makeBinPath finalAttrs.buildInputs}
  '';

  meta = {
    description = "CLI tool to check a server's TLS/SSL capabilities";
    longDescription = ''
      CLI tool which checks a server's service on any port for the support of
      TLS/SSL ciphers, protocols as well as recent cryptographic flaws and more.
    '';
    homepage = "https://testssl.sh/";
    changelog = "https://github.com/testssl/testssl.sh/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl2Only;
    mainProgram = "testssl.sh";
    platforms = lib.platforms.linux;
  };
})
