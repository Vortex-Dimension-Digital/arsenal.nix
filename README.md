<p align="center">
  <img src="assets/icon.png" width="200" alt="arsenal.nix logo">
</p>

<h1 align="center">arsenal.nix</h1>

<p align="center">
  Current, reproducible offensive security tools packaged for Nix and NixOS.
</p>

<p align="center">
  <a href="https://github.com/Vortex-Dimension-Digital/arsenal.nix/actions/workflows/ci.yml"><img src="https://github.com/Vortex-Dimension-Digital/arsenal.nix/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="https://wiki.nixos.org/wiki/Flakes"><img src="https://img.shields.io/badge/Nix-Flakes-5277C3?logo=nixos&logoColor=white" alt="Nix Flakes"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Vortex-Dimension-Digital/arsenal.nix" alt="MIT license"></a>
</p>

Packages are built from pinned, hash-verified upstream sources and can be used
directly, through a namespaced package set, or as replacements for Nixpkgs
packages.

> [!WARNING]
> Use these tools only on systems you own or are explicitly authorized to test.

## Packages

<!-- BEGIN GENERATED PACKAGE DOCS -->

| Package | Description | Version |
| --- | --- | --- |
| [`dnsx`](packages/dnsx/package.nix) | Fast and multi-purpose DNS toolkit | 1.3.1 |
| [`enum4linux-ng`](packages/enum4linux-ng/package.nix) | Windows/Samba enumeration tool | 1.3.10 |
| [`feed-filter`](packages/feed-filter/package.nix) | Utility for filtering OpenVAS feed data | 23.50.24 |
| [`greenbone-certdata-sync`](packages/greenbone-certdata-sync/package.nix) | Compatibility command for synchronizing Greenbone CERT data | 25.4.2 |
| [`greenbone-feed-sync`](packages/greenbone-feed-sync/package.nix) | Tool for downloading the Greenbone Community Feed | 25.4.2 |
| [`greenbone-nvt-sync`](packages/greenbone-nvt-sync/package.nix) | Compatibility command for synchronizing Greenbone vulnerability tests | 25.4.2 |
| [`greenbone-scapdata-sync`](packages/greenbone-scapdata-sync/package.nix) | Compatibility command for synchronizing Greenbone SCAP data | 25.4.2 |
| [`gvm-libs`](packages/gvm-libs/package.nix) | Libraries module for the Greenbone Vulnerability Management Solution | 23.9.3 |
| [`httpx`](packages/httpx/package.nix) | Fast and multi-purpose HTTP toolkit | 1.11.0 |
| [`metasploit`](packages/metasploit/package.nix) | Metasploit Framework - a collection of exploits | 6.5.3 |
| [`naabu`](packages/naabu/package.nix) | Fast SYN/CONNECT port scanner | 2.6.1 |
| [`nerva`](packages/nerva/package.nix) | Fingerprinting CLI tool for various protocols | 1.69.4 |
| [`netexec`](packages/netexec/package.nix) | Network service exploitation tool (maintained fork of CrackMapExec) | 1.5.1 |
| [`nmap`](packages/nmap/package.nix) | Free and open source utility for network discovery and security auditing | 7.991 |
| [`nuclei`](packages/nuclei/package.nix) | Tool for configurable targeted scanning | 3.11.1 |
| [`nuclei-templates`](packages/nuclei-templates/package.nix) | Templates for the nuclei engine to find security vulnerabilities | 10.4.8 |
| [`nxcdb`](packages/nxcdb/package.nix) | Database navigator for NetExec | 1.5.1 |
| [`onesixtyone`](packages/onesixtyone/package.nix) | Fast SNMP Scanner | 0.3.4-unstable-2025-08-30 |
| [`openvas`](packages/openvas/package.nix) | Scanner component for Greenbone Community Edition | 23.50.24 |
| [`openvasd`](packages/openvasd/package.nix) | Rust scanner service for OpenVAS | 23.50.24 |
| [`scannerctl`](packages/scannerctl/package.nix) | CLI frontend for OpenVAS scanner utilities | 23.50.24 |
| [`scannerlib`](packages/scannerlib/package.nix) | OpenVAS Rust workspace | 23.50.24 |
| [`seclists`](packages/seclists/package.nix) | Collection of multiple types of lists used during security assessments, collected in one place | 2026.1 |
| [`smbmap`](packages/smbmap/package.nix) | SMB enumeration tool | 1.10.8 |
| [`ssh-audit`](packages/ssh-audit/package.nix) | Tool for ssh server auditing | 3.9.0 |
| [`subfinder`](packages/subfinder/package.nix) | Subdomain discovery tool | 2.16.0 |
| [`thc-hydra`](packages/thc-hydra/package.nix) | Very fast network logon cracker which support many different services | 9.7 |

<!-- END GENERATED PACKAGE DOCS -->

## Quick start

Run a package without installing it:

```console
nix run github:Vortex-Dimension-Digital/arsenal.nix#nmap -- --version
```

## Use in NixOS

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

### Namespaced overlay

The default overlay avoids collisions with Nixpkgs by exposing packages under
`pkgs.arsenal`:

```nix
{
  nixpkgs.overlays = [ inputs.arsenal.overlays.default ];
  environment.systemPackages = [ pkgs.arsenal.nmap ];
}
```

`overlays.namespaced` is an explicit alias for `overlays.default`.

### Direct overlay

To expose packages directly and replace same-named Nixpkgs packages:

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

Package definitions live in `packages/<name>/package.nix` and are discovered
automatically.

```console
nix develop
nix fmt
nix flake check
./scripts/generate-package-docs.py --check
```

The package table in this README is generated from evaluated flake metadata and
must not be edited manually:

```console
./scripts/generate-package-docs.py
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for package conventions and validation
requirements.

## Updates

Update one package:

```console
nix run .#update -- nmap
```

List the automatically discovered packages with:

```console
nix run .#update -- --list
```

The scheduled workflows check every independent package source and open a pull
request for each available update. OpenVAS C and Rust outputs update together;
flake inputs are updated separately each week. Automated pull requests are
verified but are never merged automatically.

## License

The repository's Nix packaging code is MIT licensed. Individual tools retain
their upstream licenses.
