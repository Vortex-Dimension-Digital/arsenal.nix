{
  lib,
  cacert,
  capnproto,
  craneLib,
  keyutils,
  krb5,
  libnl,
  libpcap,
  makeWrapper,
  net-snmp,
  openvas,
  openssl,
  perl,
  pkg-config,
  rustPlatform,
}:

let
  inherit (openvas) src version;

  # Upstream: greenbone/openvas-scanner
  # - .docker/prod.Dockerfile: krb5 1.22.2 (--prefix=/opt/krb5-static, 7 subdirs) + libpcap 1.10.6 (--disable-shared --disable-dbus)
  # - rust/doc/build.md: Bundle vs Direct (OPENVAS_KRB5_ARCHIVES / OPENVAS_KRB5_INCLUDE_DIR / LIBPCAP_LIBDIR)
  # - crates/nasl-c-lib/build_support.rs: ArchiveConfig

  libpcapStatic = libpcap.overrideAttrs (old: {
    dontDisableStatic = true;
    configureFlags = (old.configureFlags or [ ]) ++ [
      "--without-libnl"
      "--disable-rdma"
    ];
    buildInputs = lib.remove libnl (old.buildInputs or [ ]);
  });

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
        outputs = [ "out" ];
        prefix = krb5StaticPrefix;
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

  commonMeta = {
    homepage = "https://github.com/greenbone/openvas-scanner";
    changelog = "https://github.com/greenbone/openvas-scanner/releases/tag/v${version}";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };

  commonArgs = {
    inherit version;
    src = craneLib.path (src + "/rust");
    strictDeps = true;
    nativeBuildInputs = [
      capnproto
      perl
      pkg-config
      rustPlatform.bindgenHook
    ];

    # Dockerfile rust stage: capnproto + libclang-dev + libsnmp-dev.
    # net-snmp alone doesn't propagate openssl dev headers in Nix, so add openssl.
    # bzip2/sqlite/zstd remain vendored.
    buildInputs = [
      net-snmp
      openssl
    ];

    postPatch = ''
      mkdir -p ../misc
      ln -sf ${src}/misc/openvas-krb5.c ../misc/openvas-krb5.c
      ln -sf ${src}/misc/openvas-krb5.h ../misc/openvas-krb5.h
    '';

    # Stage to ephemeral $NIX_BUILD_TOP so /nix/store never reaches rustc/cc.
    # String context on krb5OpenvasStatic/libpcapStatic keeps them as build inputs
    # without embedding store paths in $out — no remove-references-to needed.
    preBuild = ''
      archiveDir="$NIX_BUILD_TOP/scannerlib-archives"
      mkdir -p "$archiveDir/include"
      for archive in ${lib.escapeShellArgs krb5ArchiveNames}; do
        ln -snf "${krb5OpenvasStatic}/lib/$archive" "$archiveDir/$archive"
      done
      ln -snf "${lib.getLib libpcapStatic}/lib/libpcap.a" "$archiveDir/libpcap.a"
      cp -rs "${krb5OpenvasStatic}/include/." "$archiveDir/include/" 2>/dev/null || cp -r "${krb5OpenvasStatic}/include/." "$archiveDir/include/"
      ln -snf "${lib.getDev libpcapStatic}/include/pcap.h" "$archiveDir/include/pcap.h" 2>/dev/null || true
      if [ -d "${lib.getDev libpcapStatic}/include/pcap" ]; then
        mkdir -p "$archiveDir/include/pcap"
        cp -rs "${lib.getDev libpcapStatic}/include/pcap/." "$archiveDir/include/pcap/" 2>/dev/null || cp -r "${lib.getDev libpcapStatic}/include/pcap/." "$archiveDir/include/pcap/"
      fi
      export OPENVAS_ARCHIVES="$archiveDir"
      export LIBPCAP_LIBDIR="$archiveDir"
      export OPENVAS_KRB5_ARCHIVES="${
        lib.concatStringsSep ":" (map (a: "$archiveDir/${a}") krb5ArchiveNames)
      }"
      export OPENVAS_KRB5_INCLUDE_DIR="$archiveDir/include"
    '';
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  disallowedReferences = [
    krb5OpenvasStatic
    libpcapStatic
    (lib.getLib libpcapStatic)
    (lib.getDev libpcapStatic)
  ];

  mkCommon = {
    inherit cargoArtifacts;
    BIN_VERSION = version;
    nativeBuildInputs = commonArgs.nativeBuildInputs ++ [ makeWrapper ];
    inherit disallowedReferences;
  };

  mkBinary =
    {
      bin,
      meta,
    }:
    craneLib.buildPackage (
      commonArgs
      // mkCommon
      // {
        pname = bin;
        cargoExtraArgs = "--bin ${bin}";

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

in
{
  inherit commonMeta mkBinary;
  workspace = craneLib.buildPackage (
    commonArgs
    // mkCommon
    // {
      doCheck = false;

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
}
