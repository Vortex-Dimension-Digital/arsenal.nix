let
  flake = builtins.getFlake (toString ./..);
  packages = flake.packages.x86_64-linux;
in
builtins.mapAttrs (_name: package: {
  description = package.meta.description or "No description available";
  version = package.version or "unknown";
}) packages
