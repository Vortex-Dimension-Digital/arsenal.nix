# Contributing

arsenal.nix packages current offensive security tools for Nix and NixOS.
Changes should remain reproducible, follow upstream packaging guidance, and
avoid running tools against external targets. Preserve the authorization
warning in `README.md` whenever editing user-facing documentation.

## Development environment

Enter the repository shell before working:

```console
nix develop
```

It provides the formatter, `nix-update`, and the tools used by repository
scripts. Local pre-commit hooks are not required; the commands documented below
are the same checks enforced by CI.

## Package layout

Every public package or app has its own directory:

```text
packages/
└── tool-name/
    ├── build.nix        # optional shared implementation
    ├── package.nix
    ├── nix-update-args  # optional
    ├── update-owner     # optional shared-source package name
    └── update.py        # optional
```

The flake and update workflow discover directories containing `package.nix`
automatically. Package expressions are called from a shared scope, so declaring
another repository package as an argument uses that package instead of the
same-named package from Nixpkgs.

Keep shared implementation for one tool family beside that tool rather than in
the generic package scope. Individual package expressions should retain their
own executable selection and metadata.

Package metadata should include a description, homepage, changelog, license,
platforms, and a main program when the output is runnable. Do not add a default
package or package maintainers.

### Shared sources and entry points

Keep one canonical source owner when several outputs come from the same
upstream release. The owner contains the version, source, and hash; related
package directories select outputs or executables from that shared build.

For a shared executable distribution, alias packages should reuse the original
derivation and change only metadata such as `description` and `mainProgram`.
They must not rebuild identical sources. Give every non-owner package an
`update-owner` file containing the canonical package name.

## Adding a package

1. Check whether Nixpkgs already has a package expression and use it as the
   baseline when appropriate.
2. Pin the upstream source and every generated dependency with cryptographic
   hashes.
3. Add complete metadata and `mainProgram` for runnable packages.
4. Build the package and run a harmless command such as `--help` or
   `--version`.
5. Regenerate the README package table.
6. Add updater configuration only when plain `nix-update` is insufficient.

## Updating packages

The normal repository entry point is:

```console
nix run .#update -- tool-name
```

It follows `update-owner`, reads package-local `nix-update-args`, and falls back
to a custom updater only when one exists. To invoke `nix-update` directly:

```console
nix run nixpkgs#nix-update -- --flake tool-name
```

Add `nix-update-args` only when extra flags are needed, with one argument per
line. Add `update.py` only when `nix-update` cannot discover or update the
upstream release by itself. Keep any custom updater inside its package
directory.

Use `update-owner` when several outputs share one source and should be updated
atomically. Updating a non-owner package through the repository app resolves
the owner and updates its canonical package expression.

Test an updater by temporarily downgrading its version, running the updater, and
confirming that it restores the latest version and hashes:

```console
nix run .#update -- tool-name
```

## Generated package documentation

The package table in `README.md` is generated from flake metadata. Do not edit
the content between its generated markers by hand. Regenerate and verify it
with:

```console
./scripts/generate-package-docs.py
./scripts/generate-package-docs.py --check
```

Only the table between the generated markers is automated. The README hero,
authorization warning, explanatory content, and files under `assets/` are
maintained by hand.

## Automation

CI verifies generated documentation and runs the flake checks on pushes and
pull requests. Scheduled workflows update package sources and flake inputs,
verify the result, and open pull requests. They never merge pull requests
automatically. Workflows share Nix build results through GitHub Actions cache,
so unchanged derivations are reused while the complete dependency-aware flake
check still runs.

## Validation

Before opening a pull request:

```console
nix fmt
nix build .#tool-name
nix flake check
./scripts/generate-package-docs.py --check
```

Explain intentional differences from upstream or Nixpkgs packaging and include
the commands used for verification in the pull request. Package and test these
tools, but never run scans against external targets as part of validation.
