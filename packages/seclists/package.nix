{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "seclists";
  version = "2026.2";

  src = fetchFromGitHub {
    owner = "danielmiessler";
    repo = "SecLists";
    tag = finalAttrs.version;
    hash = "sha256-nZD89CcYwyAHvRuajljz+kMGS3AEmd/ymKk3kKkNlf8=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/wordlists/seclists
    find . -maxdepth 1 -type d -regextype posix-extended -regex '^./[A-Z].*' -exec cp -R {} $out/share/wordlists/seclists \;
    find $out/share/wordlists/seclists -name "*.md" -delete

    runHook postInstall
  '';

  meta = {
    description = "Collection of multiple types of lists used during security assessments, collected in one place";
    homepage = "https://github.com/danielmiessler/seclists";
    changelog = "https://github.com/danielmiessler/SecLists/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
