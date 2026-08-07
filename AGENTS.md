# Repository Guidelines

## Objective

Keep offensive security tools current, reproducible, and easy to consume from
Nix and NixOS. Package software only from pinned, hash-verified sources, and
preserve the repository's authorization warning in user-facing documentation.

## Project Structure

- `flake.nix` composes the repository with flake-parts.
- `nix/packages.nix` discovers package directories and creates the shared
  package scope, package outputs, apps, checks, and overlays.
- `nix/development.nix` defines the development shell, formatter, and update
  app.
- Packages live in `packages/<name>/package.nix`.
- A package may also contain a tool-family `build.nix`, `nix-update-args`,
  `update-owner`, patches, or a custom `update.py`.
- `assets/` contains hand-maintained README and repository artwork.
- Repository automation lives in `scripts/` and `.github/workflows/`.

## Build, Test, and Development Commands

- Enter the development shell: `nix develop`.
- Build one package: `nix build .#<package>`.
- Run a CLI: `nix run .#<package> -- --help`.
- Run all package and repository checks: `nix flake check`.
- Format Nix files: `nix fmt`.
- Regenerate the README package table:
  `./scripts/generate-package-docs.py`.
- Check that generated README content is current:
  `./scripts/generate-package-docs.py --check`.

## Package Conventions

- Use 2-space indentation in Nix.
- Keep each derivation small and follow the closest upstream or Nixpkgs
  package when one exists.
- Include `description`, `homepage`, `changelog`, `license`, and `platforms`
  metadata. Add `mainProgram` for runnable packages.
- Do not add package maintainers until the repository adopts a maintainer
  policy.
- Declare another in-repository package as a function argument when it is a
  dependency. The shared scope then resolves it to this repository's package
  rather than the same-named package from Nixpkgs.
- Keep shared build functions for one tool family in that tool's directory;
  generic discovery must not name or configure individual tools.
- When one derivation installs several entry points, expose each useful command
  through a small package directory with its own `meta.mainProgram`. Reuse the
  original derivation output instead of rebuilding it.
- Do not add a default package. Every package is selected explicitly.
- Linux-only tools must set `meta.platforms = lib.platforms.linux`.

## Updating Packages

Prefer `nix-update` over a custom updater:

```console
nix run nixpkgs#nix-update -- --flake <package>
```

Keep the version and source hash in the package expression whenever possible so
`nix-update` can find them. Put additional arguments in
`packages/<name>/nix-update-args`, one argument per line. The repository update
app and CI pass those arguments to `nix-update`.

Use `packages/<name>/update.py` only when `nix-update` cannot discover the
upstream release or update its source expression correctly. Keep custom
updaters package-local.

When several outputs share one source, choose one update owner and add an
`update-owner` file to the other package directories. The file contains the
owner package name. The owner package expression contains the shared version,
source, and hash so every dependent output updates atomically.

Every new package must have a verified updater before it is merged. Verify it
by temporarily downgrading the package expression one version behind the
current release, running the update, and confirming the updater restores the
correct version and hashes. Apply the same check whenever an updater or its
arguments change. The normal entry point is:

```console
nix run .#update -- <package>
```

## Generated Documentation

The package table between the generated markers in `README.md` must never be
edited by hand. Package names, descriptions, and versions come from evaluated
flake metadata. After adding, removing, renaming, or updating a package, run:

```console
./scripts/generate-package-docs.py
```

CI rejects stale generated content.

Content outside the generated markers and files under `assets/` are maintained
by hand. Preserve the authorization warning near the beginning of `README.md`.

## Automation

- CI checks generated documentation and runs `nix flake check` for pushes and
  pull requests.
- CI and updater workflows share unchanged Nix store paths through GitHub
  Actions cache. Keep the full flake check dependency-aware instead of adding
  brittle path-based package filters.
- Scheduled workflows propose package and flake-input updates with pull
  requests.
- Automation must never merge pull requests without an explicit repository
  policy change.
- Local pre-commit hooks are optional. CI is authoritative, so validation must
  remain runnable through the documented commands without hooks.

## Pull Request Checklist

- Run `nix fmt`.
- Build every directly affected package.
- Run `nix flake check`.
- Run `./scripts/generate-package-docs.py --check`.
- For a new package, verify the updater by downgrading one version and running
  `nix run .#update -- <package>`.
- Explain any intentional divergence from upstream or the corresponding
  Nixpkgs package.
- Include the commands used for verification.

## Safety and Reproducibility

- Never fetch from the network during a package build.
- Pin sources and dependencies with cryptographic hashes.
- Do not weaken sandboxing or tests merely to make a build pass.
- Changes should package and test security tools; they must not execute scans
  against external targets.
