# arsenal.nix

Up-to-date offensive security tools packaged for Nix and NixOS.

> Use these tools only on systems you own or are explicitly authorized to test.

## Packages

<!-- BEGIN GENERATED PACKAGE DOCS -->

| Package | Description | Version |
| --- | --- | --- |
| [`feed-filter`](packages/feed-filter/package.nix) | Utility for filtering OpenVAS feed data | 23.50.14 |
| [`greenbone-certdata-sync`](packages/greenbone-certdata-sync/package.nix) | Compatibility command for synchronizing Greenbone CERT data | 25.4.1 |
| [`greenbone-feed-sync`](packages/greenbone-feed-sync/package.nix) | Tool for downloading the Greenbone Community Feed | 25.4.1 |
| [`greenbone-nvt-sync`](packages/greenbone-nvt-sync/package.nix) | Compatibility command for synchronizing Greenbone vulnerability tests | 25.4.1 |
| [`greenbone-scapdata-sync`](packages/greenbone-scapdata-sync/package.nix) | Compatibility command for synchronizing Greenbone SCAP data | 25.4.1 |
| [`gvm-libs`](packages/gvm-libs/package.nix) | Libraries module for the Greenbone Vulnerability Management Solution | 23.9.2 |
| [`nmap`](packages/nmap/package.nix) | Free and open source utility for network discovery and security auditing | 7.991 |
| [`openvas`](packages/openvas/package.nix) | Scanner component for Greenbone Community Edition | 23.50.14 |
| [`openvasd`](packages/openvasd/package.nix) | Rust scanner service for OpenVAS | 23.50.14 |
| [`scannerctl`](packages/scannerctl/package.nix) | CLI frontend for OpenVAS scanner utilities | 23.50.14 |
| [`scannerlib`](packages/scannerlib/package.nix) | OpenVAS Rust workspace | 23.50.14 |

<!-- END GENERATED PACKAGE DOCS -->

## Try it

```console
nix run github:Vortex-Dimension-Digital/arsenal.nix#nmap -- --version
```

## NixOS

Add the flake as an input and install a package directly:

```nix
{
  inputs.arsenal.url = "github:Vortex-Dimension-Digital/arsenal.nix";

  outputs =
    {
      nixpkgs,
      arsenal,
      ...
    }:
    {
      nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          {
            environment.systemPackages = [
              arsenal.packages.x86_64-linux.nmap
            ];
          }
        ];
      };
    };
}
```

Or use the namespaced overlay:

```nix
{
  nixpkgs.overlays = [ inputs.arsenal.overlays.default ];
  environment.systemPackages = [ pkgs.arsenal.nmap ];
}
```

`overlays.namespaced` is an explicit alias for `overlays.default`. To expose
the packages directly and override same-named Nixpkgs packages, use:

```nix
{
  nixpkgs.overlays = [ inputs.arsenal.overlays.direct ];
  environment.systemPackages = [
    pkgs.nmap
    pkgs.openvas
  ];
}
```

## Development

Package definitions are discovered automatically from
`packages/<name>/package.nix`.

```console
nix develop
nix fmt
nix build .#nmap
nix flake check
```

The package table in this README is generated from evaluated flake metadata:

```console
./scripts/generate-package-docs.py
```

Run an updater locally with:

```console
nix run .#update -- nmap
```

List the automatically discovered packages with:

```console
nix run .#update -- --list
```

The scheduled update workflow checks every independent package source, builds
changed packages, and opens one pull request per update. The OpenVAS C and Rust
outputs update together. Flake inputs are updated separately each week.

The repository's Nix packaging code is MIT licensed. Individual tools retain
their upstream licenses.
