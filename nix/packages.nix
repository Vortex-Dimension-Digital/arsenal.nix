{ inputs, lib, ... }:
let
  packageNames = builtins.attrNames (
    lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ../packages)
  );

  mkPackageSet =
    pkgs:
    let
      scope = lib.makeScope pkgs.newScope (
        self:
        {
          craneLib = inputs.crane.mkLib pkgs;
        }
        // lib.genAttrs packageNames (name: self.callPackage (../packages + "/${name}/package.nix") { })
      );
    in
    lib.genAttrs packageNames (name: scope.${name});

  namespacedOverlay = final: _previous: {
    arsenal = mkPackageSet final;
  };

  directOverlay = final: _previous: mkPackageSet final;
in
{
  flake.overlays = {
    default = namespacedOverlay;
    namespaced = namespacedOverlay;
    direct = directOverlay;
  };

  perSystem =
    { pkgs, ... }:
    let
      arsenalPackages = (pkgs.extend namespacedOverlay).arsenal;
    in
    {
      packages = arsenalPackages;

      apps = lib.mapAttrs (_name: package: {
        type = "app";
        program = lib.getExe package;
        meta.description = package.meta.description;
      }) (lib.filterAttrs (_name: package: package.meta ? mainProgram) arsenalPackages);

      checks = lib.mapAttrs' (name: package: lib.nameValuePair "package-${name}" package) arsenalPackages;
    };
}
