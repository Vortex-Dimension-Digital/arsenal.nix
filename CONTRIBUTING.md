# Contributing

arsenal.nix packages current offensive security tools for Nix and NixOS.
Changes should remain reproducible, follow upstream packaging guidance, and
avoid running tools against external targets.

## Package layout

Each tool lives in its own directory:

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
another repository package as an argument uses that package. This is how
OpenVAS is built with arsenal.nix's Nmap.

Keep shared implementation for one tool family beside that tool rather than in
the generic package scope. For example, the OpenVAS Rust packages call
`packages/scannerlib/build.nix`, while their package expressions retain their
own binary selection and metadata.

Package metadata should include a description, homepage, changelog, license,
platforms, and a main program when the output is runnable. Do not add a default
package or package maintainers.

## Updating packages

Prefer `nix-update`:

```console
nix run nixpkgs#nix-update -- --flake tool-name
```

Add `nix-update-args` only when extra flags are needed, with one argument per
line. Add `update.py` only when `nix-update` cannot discover or update the
upstream release by itself. Nmap currently needs a custom updater because its
releases are discovered from nmap.org rather than GitHub tags or releases.

Use `update-owner` when several outputs share one source and should be updated
atomically. `openvasd`, `scannerctl`, `feed-filter`, and `scannerlib` all point
to `openvas`; updating any of them through the repository update app updates
`packages/openvas/package.nix` with `nix-update`.

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

## Validation

Before opening a pull request:

```console
nix fmt
nix build .#tool-name
nix flake check
./scripts/generate-package-docs.py --check
```

Explain intentional differences from upstream or Nixpkgs packaging and include
the commands used for verification in the pull request.
