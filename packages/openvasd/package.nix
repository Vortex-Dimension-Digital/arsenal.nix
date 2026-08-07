{ callPackage }:

(callPackage ../scannerlib/build.nix { }).mkBinary {
  bin = "openvasd";
  meta.description = "Rust scanner service for OpenVAS";
}
