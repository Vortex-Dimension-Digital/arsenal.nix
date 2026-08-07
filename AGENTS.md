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
  dependency. The shared scope then resolves it to this repository's package.
  For example, OpenVAS receives this repository's `nmap`, not `pkgs.nmap`.
- Keep shared build functions for one tool family in that tool's directory;
  generic discovery must not name or configure individual tools.
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
upstream release. Nmap is the current exception because releases are published
on nmap.org rather than as discoverable GitHub releases.

When several outputs share one source, choose one update owner and add an
`update-owner` file to the other package directories. The file contains the
owner package name. The OpenVAS Rust binaries, workspace, and C scanner are
updated atomically through `openvas`; its package expression owns the shared
upstream source.

Test updater changes by temporarily using an older version, running the update,
and confirming the version and hashes are corrected. The normal entry point is:

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

## Pull Request Checklist

- Run `nix fmt`.
- Build every directly affected package.
- Run `nix flake check`.
- Run `./scripts/generate-package-docs.py --check`.
- Explain any intentional divergence from upstream or the corresponding
  Nixpkgs package.
- Include the commands used for verification.

## Safety and Reproducibility

- Never fetch from the network during a package build.
- Pin sources and dependencies with cryptographic hashes.
- Do not weaken sandboxing or tests merely to make a build pass.
- Changes should package and test security tools; they must not execute scans
  against external targets.
