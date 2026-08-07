{ callPackage }:

(callPackage ../scannerlib/build.nix { }).mkBinary {
  bin = "feed-filter";
  meta.description = "Utility for filtering OpenVAS feed data";
}
