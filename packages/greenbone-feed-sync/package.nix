{
  lib,
  python3,
  fetchFromGitHub,
  makeWrapper,
  pkgs,
  rsync,
}:

python3.pkgs.buildPythonApplication (finalAttrs: {
  pname = "greenbone-feed-sync";
  version = "25.4.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "greenbone";
    repo = "greenbone-feed-sync";
    tag = "v${finalAttrs.version}";
    hash = "sha256-tHCVAAPxt63tnmcTlIzfYm85uaCTH/VRZoT9DU0p7I0=";
  };

  build-system = with python3.pkgs; [ hatchling ];

  dependencies = with python3.pkgs; [
    rich
    shtab
  ];

  nativeBuildInputs = [ makeWrapper ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ rsync ])
  ];

  nativeCheckInputs = with python3.pkgs; [
    pkgs.rsync
    pontos
    pytestCheckHook
  ];

  pythonImportsCheck = [ "greenbone.feed.sync" ];

  meta = {
    description = "Tool for downloading the Greenbone Community Feed";
    homepage = "https://github.com/greenbone/greenbone-feed-sync";
    changelog = "https://github.com/greenbone/greenbone-feed-sync/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "greenbone-feed-sync";
    platforms = lib.platforms.linux;
  };
})
