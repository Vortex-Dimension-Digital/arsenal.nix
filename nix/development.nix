{ inputs, ... }:
{
  imports = [
    inputs.git-hooks-nix.flakeModule
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    { config, pkgs, ... }:
    let
      # Nix 2.35 fetches flake sources lazily, so `nix flake metadata` reports
      # a store path for this flake without copying it there, and nix-update
      # 1.16.0 then fails to evaluate the missing path. Drop the patch once a
      # nix-update release includes https://github.com/Mic92/nix-update/pull/692.
      nix-update = pkgs.nix-update.overridePythonAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (pkgs.fetchpatch {
            name = "nix-update-prefetch-lazy-flake-sources.patch";
            url = "https://github.com/Mic92/nix-update/commit/d545c1fad667e573128cad0db55fdc77134a4d3c.patch";
            hash = "sha256-CVSihQevWIwKSnjKo9ilw1hdi4a1t0xr6DunAUKSBFA=";
          })
        ];
      });

      update = pkgs.writeShellApplication {
        name = "arsenal-update";
        runtimeInputs = [
          nix-update
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
          nix-update
          pkgs.python3
        ];
        shellHook = config.pre-commit.installationScript;
      };
    };
}
