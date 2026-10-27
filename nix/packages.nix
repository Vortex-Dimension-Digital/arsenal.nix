{ inputs, lib, ... }:
let
  packageNames = builtins.attrNames (
    lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ../packages)
  );

  # Both overlays expose the scope as `pkgs.arsenal`, so consumers can change a
  # package or `craneLib` with `overrideScope`, and the packages depending on
  # it follow.
  mkScope =
    pkgs:
    lib.makeScope pkgs.newScope (
      self:
      {
        craneLib = inputs.crane.mkLib pkgs;
      }
      // lib.genAttrs packageNames (name: self.callPackage (../packages + "/${name}/package.nix") { })
    );

  namespacedOverlay = final: _previous: {
    arsenal = mkScope final;
  };

  # Reads the packages back from `final.arsenal` so they follow an overridden
  # scope.
  directOverlay =
    final: _previous:
    {
      arsenal = mkScope final;
    }
    // lib.genAttrs packageNames (name: final.arsenal.${name});
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
      scope = (pkgs.extend namespacedOverlay).arsenal;
      arsenalPackages = lib.genAttrs packageNames (name: scope.${name});
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
