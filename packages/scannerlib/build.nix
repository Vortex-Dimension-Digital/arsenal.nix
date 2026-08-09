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
  rustPlatform,
}:

let
  inherit (openvas) src version;

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
  ];

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

    OPENVAS_KRB5_ARCHIVES = lib.concatMapStringsSep ":" (
      archive: "${krb5OpenvasStatic}/lib/${archive}"
    ) krb5ArchiveNames;
    OPENVAS_KRB5_INCLUDE_DIR = "${krb5OpenvasStatic}/include";
    LIBPCAP_LIBDIR = "${libpcapArchiveDir}";
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
