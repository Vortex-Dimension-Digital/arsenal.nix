{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { config, pkgs, ... }:
    let
      update = pkgs.writeShellApplication {
        name = "arsenal-update";
        runtimeInputs = [
          pkgs.nix-update
          pkgs.python3
        ];
        text = ''
          export ARSENAL_NIX_ROOT="$PWD"
          exec python ${../scripts/update.py} "$@"
        '';
      };
    in
    {
      apps.update = {
        type = "app";
        program = "${update}/bin/arsenal-update";
        meta.description = "Update an arsenal.nix package";
      };

      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      devShells.default = pkgs.mkShellNoCC {
        packages = [
          config.treefmt.build.wrapper
          pkgs.nix-update
          pkgs.python3
        ];
      };
    };
}
