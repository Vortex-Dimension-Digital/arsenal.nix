{
  lib,
  cacert,
  capnproto,
  craneLib,
  keyutils,
  krb5,
  libnl,
  libpcap,
  linkFarm,
  makeWrapper,
  net-snmp,
  openvas,
  perl,
  pkg-config,
  runCommand,
  rustPlatform,
}:

let
  inherit (openvas) src version;

  # Upstream reference: greenbone/openvas-scanner
  # - .docker/prod.Dockerfile: krb5-build (krb5 1.22.2, --prefix=/opt/krb5-static,
  #   --enable-static --disable-shared --without-system-verto --without-libedit
  #   --without-keyutils --disable-rpath, 7 subdirs) + pcap-build (libpcap 1.10.6,
  #   --disable-shared --disable-dbus) + build-archives (/archives bundle)
  # - rust/doc/build.md: Bundle (OPENVAS_ARCHIVES/LIBPCAP_LIBDIR) is Dockerfile default;
  #   Direct (OPENVAS_KRB5_ARCHIVES/OPENVAS_KRB5_INCLUDE_DIR/LIBPCAP_LIBDIR) is
  #   supported alternative (Example 2). This file uses Direct style to avoid
  #   an extra aggregator derivation while staying compatible with
  #   crates/nasl-c-lib/build_support.rs:ArchiveConfig.
  # - rust/crates/nasl-c-lib/README.md: build-cache/archives layout

  libpcapStatic = libpcap.overrideAttrs (old: {
    dontDisableStatic = true;
    configureFlags = (old.configureFlags or [ ]) ++ [
      "--disable-dbus"
      "--without-libnl"
    ];
    buildInputs = lib.remove libnl (old.buildInputs or [ ]);
    propagatedBuildInputs = lib.remove (lib.getDev libnl) (old.propagatedBuildInputs or [ ]);
  });

  libpcapArchiveDir = linkFarm "scannerlib-libpcap" [
    {
      name = "libpcap.a";
      path = "${lib.getLib libpcapStatic}/lib/libpcap.a";
    }
  ];

  krb5StaticPrefix = "/opt/krb5-static";
  krb5ArchiveNames = [
    "libgssapi_krb5.a"
    "libkrb5.a"
    "libk5crypto.a"
    "libcom_err.a"
    "libkrb5support.a"
  ];
  krb5BuildDirs = [
    "util/support"
    "util/et"
    "util/profile"
    "include"
    "lib/crypto"
    "lib/krb5"
    "lib/gssapi"
  ];

  krb5OpenvasStatic =
    (krb5.override {
      staticOnly = true;
      withLibedit = false;
    }).overrideAttrs
      (old: {
        # Match upstream's build-only prefix. DESTDIR stages installation so
        # the Nix output path is not compiled into the static archives.
        outputs = [ "out" ];
        prefix = krb5StaticPrefix;
        setOutputFlags = false;
        outputChecks = { };
        postConfigure = "";
        preInstall = "";
        postInstall = "";
        preFixup = "";

        configureFlags = (old.configureFlags or [ ]) ++ [
          "--without-keyutils"
          "--disable-rpath"
        ];
        buildInputs = lib.remove keyutils (old.buildInputs or [ ]);

        buildPhase = ''
          runHook preBuild

          for dir in ${lib.escapeShellArgs krb5BuildDirs}; do
            make -C "$dir" -j"$NIX_BUILD_CORES"
          done

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          stage="$TMPDIR/krb5-stage"
          make install-mkdirs DESTDIR="$stage"
          for dir in ${lib.escapeShellArgs krb5BuildDirs}; do
            make -C "$dir" install DESTDIR="$stage"
          done

          root="$stage${krb5StaticPrefix}"
          mkdir -p "$out/lib" "$out/include"
          for archive in ${lib.escapeShellArgs krb5ArchiveNames}; do
            install -m 644 "$root/lib/$archive" "$out/lib/$archive"
          done
          cp -r "$root/include/." "$out/include/"

          runHook postInstall
        '';
      });

  staticBuildReferences = [
    krb5OpenvasStatic
    libpcapArchiveDir
    libpcapStatic
    scannerlibArchives
  ];

  # Bundle parity with .docker/prod.Dockerfile:build-archives (/archives)
  # Upstream's Rust stage sets OPENVAS_ARCHIVES=/archives and
  # LIBPCAP_LIBDIR=/archives (flat layout: 6 *.a + include/). This bundle
  # mirrors that layout for consumers that rely on the bundle fallback
  # (build_support.rs: resolve_default_lookup → build-cache/archives).
  # Direct vars OPENVAS_KRB5_* remain primary — build_support prefers them
  # when set (see libopenvas-krb5-sys/build.rs). Keeping both styles makes
  # the build compatible with either configuration per rust/doc/build.md.
  scannerlibArchives = runCommand "scannerlib-archives" { } ''
    mkdir -p $out/include/gssapi $out/include/krb5
    ln -s ${lib.getLib libpcapStatic}/lib/libpcap.a $out/libpcap.a
    for archive in ${lib.escapeShellArgs krb5ArchiveNames}; do
      ln -s ${krb5OpenvasStatic}/lib/$archive $out/$archive
    done
    cp -r ${krb5OpenvasStatic}/include/* $out/include/
    cp ${lib.getDev libpcapStatic}/include/pcap.h $out/include/pcap.h
    if [ -d ${lib.getDev libpcapStatic}/include/pcap ]; then
      mkdir -p $out/include/pcap
      cp -r ${lib.getDev libpcapStatic}/include/pcap/* $out/include/pcap/
    fi
  '';

  commonArgs = {
    pname = "scannerlib";
    inherit version;
    src = craneLib.path (src + "/rust");
    strictDeps = true;

    nativeBuildInputs = [
      capnproto
      perl
      pkg-config
      rustPlatform.bindgenHook
    ];

    buildInputs = [ net-snmp ];

    # Direct style (per rust/doc/build.md Example 2) + Bundle style (Example 1 / Dockerfile)
    # Keep both for compatibility; build_support.rs prefers Direct when set.
    # LIBPCAP_LIBDIR and OPENVAS_ARCHIVES both point to the bundle here to
    # mirror prod.Dockerfile's `ENV OPENVAS_ARCHIVES=/archives
    # LIBPCAP_LIBDIR=/archives` (flat /archives with 6 libs).
    OPENVAS_ARCHIVES = "${scannerlibArchives}";
    OPENVAS_KRB5_ARCHIVES = lib.concatMapStringsSep ":" (
      archive: "${krb5OpenvasStatic}/lib/${archive}"
    ) krb5ArchiveNames;
    OPENVAS_KRB5_INCLUDE_DIR = "${krb5OpenvasStatic}/include";
    LIBPCAP_LIBDIR = "${scannerlibArchives}";
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  postPatch = ''
    mkdir -p ../misc
    ln -sf ${src}/misc/openvas-krb5.c ../misc/openvas-krb5.c
    ln -sf ${src}/misc/openvas-krb5.h ../misc/openvas-krb5.h
  '';

  commonMeta = {
    homepage = "https://github.com/greenbone/openvas-scanner";
    changelog = "https://github.com/greenbone/openvas-scanner/releases/tag/v${version}";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };

  mkBinary =
    {
      bin,
      meta,
    }:
    craneLib.buildPackage (
      commonArgs
      // {
        inherit cargoArtifacts postPatch;
        BIN_VERSION = version;
        pname = bin;
        cargoExtraArgs = "--bin ${bin}";
        nativeBuildInputs = commonArgs.nativeBuildInputs ++ [ makeWrapper ];
        disallowedReferences = staticBuildReferences;

        preCheck = ''
          export LD_LIBRARY_PATH=${lib.makeLibraryPath commonArgs.buildInputs}
          export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
        '';
        cargoTestExtraArgs = "-- --skip container_image_scanner";

        postFixup = ''
          wrapProgram "$out/bin/${bin}" \
            --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
        '';

        meta = commonMeta // { mainProgram = bin; } // meta;
      }
    );

  scannerlib = craneLib.buildPackage (
    commonArgs
    // {
      inherit cargoArtifacts postPatch;
      BIN_VERSION = version;
      doCheck = false;
      nativeBuildInputs = commonArgs.nativeBuildInputs ++ [ makeWrapper ];
      disallowedReferences = staticBuildReferences;

      postFixup = ''
        for program in "$out/bin/"*; do
          wrapProgram "$program" \
            --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
        done
      '';

      meta = commonMeta // {
        description = "OpenVAS Rust workspace";
      };
    }
  );
in
{
  inherit commonMeta mkBinary;
  workspace = scannerlib;
}
