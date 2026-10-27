{ inputs, ... }:
{
  imports = [
    inputs.git-hooks-nix.flakeModule
    inputs.treefmt-nix.flakeModule
  ];

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

      pre-commit = {
        # The package-docs hook evaluates the flake, which the build sandbox
        # cannot do, so CI runs the hooks from the development shell instead.
        check.enable = false;
        settings.hooks = {
          treefmt.enable = true;
          package-docs = {
            enable = true;
            name = "README package table";
            entry = "${pkgs.python3.interpreter} scripts/generate-package-docs.py";
            files = ''^(flake\.(nix|lock)|nix/.*|packages/.*|scripts/generate-package-docs\..*|README\.md)$'';
            pass_filenames = false;
          };
        };
      };

      devShells.default = pkgs.mkShellNoCC {
        packages = [
          config.pre-commit.settings.package
          config.treefmt.build.wrapper
          pkgs.nix-update
          pkgs.python3
        ];
        shellHook = config.pre-commit.installationScript;
      };
    };
}
