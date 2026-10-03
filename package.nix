{ lib
, stdenv
, stdenvNoCC
, alsa-lib
, at-spi2-atk
, at-spi2-core
, autoPatchelfHook
, cairo
, cups
, dbus
, dpkg
, expat
, fetchurl
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libX11
, libXcomposite
, libXdamage
, libXext
, libXfixes
, libXrandr
, libXrender
, libXScrnSaver
, libXtst
, libdrm
, libgbm
, libnotify
, libsecret
, libuuid
, libxcb
, libxkbcommon
, libxshmfence
, makeWrapper
, mesa
, nspr
, nss
, pango
, systemd
, wayland
, xdg-utils
, unzip
, codexSupport ? true
, codex
, opencodeSupport ? false
, opencode
, cursorSupport ? false
, cursor-cli
, claudeSupport ? false
, claude-code
, githubSupport ? false
, gh
, gitlabSupport ? true
, glab
, azureSupport ? false
, azure-cli
, bitbucketSupport ? false
, bitbucket-cli
}:

let
  pname = "t3code";
  version = "0.0.45";
  linuxAmd64Hash = "sha256-aEvJF5EaW9lK56Hjczg4S69yx66r648RyWqcY1sp43U=";
  linuxArm64Hash = "sha256-8c4sYWl7p7wS0IQdwSSrINvVok9WkUFuhxywi230H1w=";
  darwinArm64Hash = "sha256-J+48WUpKEOjLrWvXJJlymsGhBtkPHDn7igP9kwpbvQY=";

  commonMeta = {
    description = "T3 Code desktop app packaged from upstream release artifacts";
    homepage = "https://github.com/pingdotgg/t3code";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    downloadPage = "https://github.com/pingdotgg/t3code/releases";
    license = lib.licenses.mit;
    mainProgram = pname;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };

  linuxPackage =
    let
      linuxAsset = if stdenv.hostPlatform.isx86_64 then "amd64" else "arm64";
      linuxHash = if stdenv.hostPlatform.isx86_64 then linuxAmd64Hash else linuxArm64Hash;
      src = fetchurl {
        url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-${linuxAsset}.deb";
        hash = linuxHash;
      };
    in
    stdenv.mkDerivation {
      inherit pname version src;
      nativeBuildInputs = [
        autoPatchelfHook
        dpkg
        makeWrapper
      ];

      buildInputs = [
        alsa-lib
        at-spi2-atk
        at-spi2-core
        cairo
        cups
        dbus
        expat
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk3
        libX11
        libXcomposite
        libXdamage
        libXext
        libXfixes
        libXrandr
        libXrender
        libXScrnSaver
        libXtst
        libdrm
        libgbm
        libnotify
        libsecret
        libuuid
        libxcb
        libxkbcommon
        libxshmfence
        mesa
        nspr
        nss
        pango
        systemd
        wayland
      ];

      dontConfigure = true;
      dontBuild = true;
      dontUnpack = true;
      autoPatchelfIgnoreMissingDeps = [
        "libc.musl-x86_64.so.1"
        "libc.musl-aarch64.so.1"
      ];

      installPhase = ''
        runHook preInstall

        unpacked="$TMPDIR/t3code"
        dpkg-deb -x "$src" "$unpacked"

        mkdir -p "$out/bin" "$out/lib/t3code" "$out/share"
        cp -r "$unpacked/opt/T3 Code (Alpha)/." "$out/lib/t3code/"
        cp -r "$unpacked/usr/share/." "$out/share/"

        substituteInPlace "$out/share/applications/t3code.desktop" \
          --replace-fail 'Exec="/opt/T3 Code (Alpha)/t3code" %U' 'Exec=t3code %U'

        makeWrapper \
          "$out/lib/t3code/t3code" \
          "$out/bin/${pname}" \
          --set CHROME_DESKTOP t3code.desktop \
          --set T3CODE_DISABLE_AUTO_UPDATE true \
          --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
          --prefix XDG_DATA_DIRS : "$out/share" \
          ${lib.optionalString codexSupport ''
            --prefix PATH : "${lib.makeBinPath [ codex ]}"
          ''}

        runHook postInstall
      '';

      meta = commonMeta;
    };

  darwinAppName = "T3 Code (Alpha).app";
  darwinExecutable = "T3 Code (Alpha)";
  darwinAsset = "T3-Code-${version}-arm64.zip";
  darwinHash = darwinArm64Hash;

  darwinPackage = stdenvNoCC.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/${darwinAsset}";
      hash = darwinHash;
    };

    nativeBuildInputs = [
      makeWrapper
      unzip
    ];

    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      mv "${darwinAppName}" "$out/Applications/"

      makeWrapper \
        "$out/Applications/${darwinAppName}/Contents/MacOS/${darwinExecutable}" \
        "$out/bin/${pname}" \
        ${lib.concatStringsSep " \\
        " (lib.filter (s: s != "") [
          (lib.optionalString codexSupport ''--prefix PATH : "${lib.makeBinPath [ codex ]}"'')
          (lib.optionalString opencodeSupport ''--prefix PATH : "${lib.makeBinPath [ opencode ]}"'')
          (lib.optionalString cursorSupport ''--prefix PATH : "${lib.makeBinPath [ cursor-cli ]}"'')
          (lib.optionalString claudeSupport ''--prefix PATH : "${lib.makeBinPath [ claude-code ]}"'')
          (lib.optionalString githubSupport ''--prefix PATH : "${lib.makeBinPath [ gh ]}"'')
          (lib.optionalString gitlabSupport ''--prefix PATH : "${lib.makeBinPath [ glab ]}"'')
          (lib.optionalString azureSupport ''--prefix PATH : "${lib.makeBinPath [ azure-cli ]}"'')
          (lib.optionalString bitbucketSupport ''--prefix PATH : "${lib.makeBinPath [ bitbucket-cli ]}"'')
        ])}


      runHook postInstall
    '';

    meta = commonMeta;
  };
in
if stdenv.hostPlatform.isLinux && (stdenv.hostPlatform.isx86_64 || stdenv.hostPlatform.isAarch64) then
  linuxPackage
else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64 then
  darwinPackage
else
  throw "t3code desktop is only packaged for x86_64-linux, aarch64-linux, and aarch64-darwin"
