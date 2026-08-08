{
  lib,
  fetchFromGitHub,
  python312,
  writableTmpDirAsHomeHook,
}:
let
  python = python312.override {
    self = python;
    packageOverrides = self: super: {
      impacket = super.impacket.overridePythonAttrs {
        version = "0.14.0-unstable-2025-12-03";
        src = fetchFromGitHub {
          owner = "fortra";
          repo = "impacket";
          rev = "caba5facdd3a01b5d0decc6daf5871839f22f792";
          hash = "sha256-jyn5qSSAipGYhHm2EROwDHa227mnmW+d+0H0/++i1OY=";
        };
        # Fix version to be compliant with Python packaging rules
        postPatch = ''
          substituteInPlace setup.py \
            --replace 'version="{}.{}.{}.{}{}"' 'version="{}.{}.{}"'
        '';
      };

      # Nixpkgs names the derivation `bloodhound-py`, but the PyPI distribution
      # (and therefore the installed `.dist-info`) is `bloodhound`, so the
      # pythonMetadataCheckPhase fails to look up `bloodhound-py`. Align the
      # derivation pname with the real distribution name.
      bloodhound-py = super.bloodhound-py.overridePythonAttrs (_: {
        pname = "bloodhound";
      });
    };
  };
in
python.pkgs.buildPythonApplication (finalAttrs: {
  pname = "netexec";
  version = "1.5.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Pennyw0rth";
    repo = "NetExec";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BKqBmpA2cSKwC9zX++Z6yTSDIyr4iZVGC/Eea6zoMLQ=";
  };

  pythonRelaxDeps = true;

  pythonRemoveDeps = [
    # Fail to detect dev version requirement
    "neo4j"
    # No python package in nixpkgs; use bloodhound-py instead.
    "bloodhound-ce"
  ];

  postPatch = ''
    substituteInPlace nxc/first_run.py \
      --replace-fail "from os import mkdir" "from os import mkdir, chmod" \
      --replace-fail "shutil.copy(default_path, NXC_PATH)" $'shutil.copy(default_path, CONFIG_PATH)\n        chmod(CONFIG_PATH, 0o600)'

    substituteInPlace pyproject.toml \
      --replace-fail " @ git+https://github.com/Pennyw0rth/Certipy" "" \
      --replace-fail " @ git+https://github.com/fortra/impacket" "" \
      --replace-fail " @ git+https://github.com/wbond/oscrypto" "" \
      --replace-fail " @ git+https://github.com/Pennyw0rth/NfsClient" ""
  '';

  build-system = with python.pkgs; [
    poetry-core
    poetry-dynamic-versioning
  ];

  dependencies = with python.pkgs; [
    jwt
    aardwolf
    aioconsole
    aiosqlite
    argcomplete
    asyauth
    beautifulsoup4
    bloodhound-py
    certipy-ad
    dploot
    dsinternals
    impacket
    lsassy
    masky
    minikerberos
    msgpack
    msldap
    neo4j
    paramiko
    pefile
    pyasn1-modules
    pylnk3
    pynfsclient
    pypsrp
    pypykatz
    python-dateutil
    python-libnmap
    pywerview
    requests
    rich
    sqlalchemy
    termcolor
    terminaltables
    xmltodict
  ];

  nativeCheckInputs = with python.pkgs; [ pytestCheckHook ] ++ [ writableTmpDirAsHomeHook ];

  meta = {
    description = "Network service exploitation tool (maintained fork of CrackMapExec)";
    homepage = "https://github.com/Pennyw0rth/NetExec";
    changelog = "https://github.com/Pennyw0rth/NetExec/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.bsd2;
    mainProgram = "nxc";
    platforms = lib.platforms.linux;
  };
})
