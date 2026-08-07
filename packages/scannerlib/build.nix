{
  lib,
  stdenvNoCC,
  bzip2,
  cacert,
  capnproto,
  craneLib,
  gnumake,
  gvm-libs,
  keyutils,
  krb5,
  libclang,
  libedit,
  libgcrypt,
  libgpg-error,
  libnl,
  libpcap,
  libverto,
  makeWrapper,
  net-snmp,
  openvas,
  openssl,
  perl,
  pkg-config,
  removeReferencesTo,
  rustPlatform,
  sqlite,
  zstd,
}:

let
  inherit (openvas) src version;

  libgpgErrorStatic = libgpg-error.overrideAttrs (old: {
    dontDisableStatic = true;
    configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-static" ];
  });

  libgcryptStatic =
    (libgcrypt.override {
      libgpg-error = libgpgErrorStatic;
    }).overrideAttrs
      (old: {
        dontDisableStatic = true;
        configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-static" ];
      });

  libpcapStatic = libpcap.overrideAttrs (old: {
    dontDisableStatic = true;
    configureFlags = (old.configureFlags or [ ]) ++ [
      "--disable-dbus"
      "--without-libnl"
    ];
    buildInputs = lib.remove libnl (old.buildInputs or [ ]);
    propagatedBuildInputs = lib.remove (lib.getDev libnl) (old.propagatedBuildInputs or [ ]);
  });

  krb5OpenvasStatic = krb5.overrideAttrs (old: {
    dontDisableStatic = true;
    configureFlags = lib.remove "--with-libedit" (old.configureFlags or [ ]) ++ [
      "--enable-static"
      "--disable-shared"
      "--without-system-verto"
      "--without-libedit"
      "--without-keyutils"
      "--disable-rpath"
    ];
    buildInputs = lib.remove keyutils (
      lib.remove libedit (lib.remove libverto (old.buildInputs or [ ]))
    );
    propagatedBuildInputs = lib.remove (lib.getDev keyutils) (
      lib.remove (lib.getDev libedit) (
        lib.remove (lib.getDev libverto) (old.propagatedBuildInputs or [ ])
      )
    );

    buildPhase = ''
      runHook preBuild

      for dir in \
        util/support \
        util/et \
        util/profile \
        include \
        lib/crypto \
        lib/krb5 \
        lib/gssapi
      do
        make -C "$dir" -j"$NIX_BUILD_CORES"
      done

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      make install-mkdirs

      for dir in \
        util/support \
        util/et \
        util/profile \
        include \
        lib/crypto \
        lib/krb5 \
        lib/gssapi
      do
        make -C "$dir" install
      done

      runHook postInstall
    '';
  });

  openvasArchives = stdenvNoCC.mkDerivation {
    pname = "openvas-archives";
    inherit version;

    dontUnpack = true;

    installPhase = ''
      mkdir -p "$out/include"

      ln -s "${lib.getLib libgcryptStatic}/lib/libgcrypt.a" "$out/libgcrypt.a"
      ln -s "${lib.getLib libgpgErrorStatic}/lib/libgpg-error.a" "$out/libgpg-error.a"
      ln -s "${lib.getLib libpcapStatic}/lib/libpcap.a" "$out/libpcap.a"

      ln -s "${lib.getLib krb5OpenvasStatic}/lib/libgssapi_krb5.a" "$out/libgssapi_krb5.a"
      ln -s "${lib.getLib krb5OpenvasStatic}/lib/libkrb5.a" "$out/libkrb5.a"
      ln -s "${lib.getLib krb5OpenvasStatic}/lib/libk5crypto.a" "$out/libk5crypto.a"
      ln -s "${lib.getLib krb5OpenvasStatic}/lib/libcom_err.a" "$out/libcom_err.a"
      ln -s "${lib.getLib krb5OpenvasStatic}/lib/libkrb5support.a" "$out/libkrb5support.a"

      cp -r "${lib.getDev libgcryptStatic}/include/." "$out/include/"
      cp -r "${lib.getDev libgpgErrorStatic}/include/." "$out/include/"
      cp -r "${lib.getDev libpcapStatic}/include/." "$out/include/"
      cp -r "${lib.getDev krb5OpenvasStatic}/include/." "$out/include/"
    '';
  };

  commonArgs = {
    pname = "scannerlib";
    inherit version;
    src = craneLib.path (src + "/rust");
    strictDeps = true;

    nativeBuildInputs = [
      capnproto
      gnumake
      perl
      pkg-config
      rustPlatform.bindgenHook
    ];

    buildInputs = [
      bzip2
      gvm-libs
      krb5
      libclang
      libgcrypt
      libgpg-error
      libpcap
      net-snmp
      openssl
      sqlite
      zstd
    ];

    OPENVAS_ARCHIVES = "${openvasArchives}";
    LIBPCAP_LIBDIR = "${openvasArchives}";
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

  removeStaticArchiveReferences = ''
    # The Kerberos archives are fully linked into the binaries. Remove their
    # embedded build paths so Nix does not retain the archives at runtime.
    find "$out/bin" -type f -exec \
      remove-references-to -t ${lib.getLib krb5OpenvasStatic} {} +
  '';

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
        nativeBuildInputs = commonArgs.nativeBuildInputs ++ [
          makeWrapper
          removeReferencesTo
        ];
        disallowedReferences = [ (lib.getLib krb5OpenvasStatic) ];

        preCheck = ''
          export LD_LIBRARY_PATH=${lib.makeLibraryPath commonArgs.buildInputs}
          export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
        '';
        cargoTestExtraArgs = "-- --skip container_image_scanner";

        postFixup = ''
          wrapProgram "$out/bin/${bin}" \
            --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
          ${removeStaticArchiveReferences}
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
      nativeBuildInputs = commonArgs.nativeBuildInputs ++ [
        makeWrapper
        removeReferencesTo
      ];
      disallowedReferences = [ (lib.getLib krb5OpenvasStatic) ];

      postFixup = ''
        for program in "$out/bin/"*; do
          wrapProgram "$program" \
            --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
        done
        ${removeStaticArchiveReferences}
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
