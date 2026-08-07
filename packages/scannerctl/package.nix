{ callPackage }:

(callPackage ../scannerlib/build.nix { }).mkBinary {
  bin = "scannerctl";
  meta.description = "CLI frontend for OpenVAS scanner utilities";
}
