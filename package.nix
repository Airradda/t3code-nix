{ lib
, stdenv
, stdenvNoCC
, appimageTools
, fetchurl
, makeWrapper
, unzip
, codexSupport ? true, codex
, opencodeSupport ? false, opencode
, cursorSupport ? false, cursor-cli
, claudeSupport ? false, claude-code
, githubSupport ? false, gh
, gitlabSupport ? true, glab
, azureSupport ? false, azure-cli
, bitbucketSupport ? false, bitbucket-cli
}:

let
  pname = "t3code";
  version = "0.0.25";
  linuxHash = "sha256-aO1gFdYRs/9kvT8/1W4/v5e8os9E7rJl46BTK9SUglI=";
  darwinX64Hash = "sha256-85HpUbgJ87K3BrSQ/g17guUUXwAieYtDbcRWgPAHEmg=";
  darwinArm64Hash = "sha256-tVe1k3DmlVGX1rzN3s3ivLIYsBkixx06B0eQJQBZX9g=";

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
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };

  linuxPackage =
    let
      src = fetchurl {
        url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
        hash = linuxHash;
      };

      appimageContents = appimageTools.extractType2 {
        inherit pname version src;
      };
    in
    appimageTools.wrapType2 {
      inherit pname version src;
      nativeBuildInputs = [ makeWrapper ];

      extraInstallCommands = ''
        mkdir -p "$out/share"

        if [ -d ${appimageContents}/usr/share ]; then
          cp -r ${appimageContents}/usr/share/* "$out/share/"
        fi

        desktop_file="$(find "$out/share" -type f -name '*.desktop' | head -n 1 || true)"
        if [ -z "$desktop_file" ]; then
          desktop_source="$(find ${appimageContents} -maxdepth 2 -type f -name '*.desktop' | head -n 1 || true)"
          if [ -n "$desktop_source" ]; then
            desktop_file="$out/share/applications/$(basename "$desktop_source")"
            install -Dm444 "$desktop_source" "$desktop_file"
          fi
        fi

        if [ -n "$desktop_file" ]; then
          desktop_basename="$(basename "$desktop_file")"

          sed -i \
            -e 's|Exec=AppRun|Exec=${pname}|g' \
            -e 's|Exec=AppRun %U|Exec=${pname} %U|g' \
            -e 's|TryExec=AppRun|TryExec=${pname}|g' \
            -e 's|^StartupWMClass=.*$|StartupWMClass=t3-code-desktop|g' \
            "$desktop_file"

          wrapProgram "$out/bin/${pname}" \
            --set CHROME_DESKTOP "$desktop_basename" \
            --prefix XDG_DATA_DIRS : "$out/share" \
            ${lib.optionalString codexSupport ''
              --prefix PATH : "${lib.makeBinPath [ codex ]}"
            ''}
        fi

        if [ -f ${appimageContents}/.DirIcon ]; then
          install -Dm444 ${appimageContents}/.DirIcon "$out/share/pixmaps/${pname}.png"
        fi
      '';

      meta = commonMeta;
    };

  darwinAppName = "T3 Code (Alpha).app";
  darwinExecutable = "T3 Code (Alpha)";
  darwinAsset =
    if stdenv.hostPlatform.isAarch64 then
      "T3-Code-${version}-arm64.zip"
    else
      "T3-Code-${version}-x64.zip";
  darwinHash =
    if stdenv.hostPlatform.isAarch64 then
      darwinArm64Hash
    else
      darwinX64Hash;

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
if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64 then
  linuxPackage
else if stdenv.hostPlatform.isDarwin then
  darwinPackage
else
  throw "t3code desktop is only packaged for x86_64-linux, x86_64-darwin, and aarch64-darwin"
