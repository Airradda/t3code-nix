{
  lib,
  stdenv,
  stdenvNoCC,
  appimageTools,
  bun,
  electron,
  fetchurl,
  makeWrapper,
  nodejs_24,
  t3codeSrc,
  unzip,
  codexSupport ? true, codex
}:

let
  pname = "t3code";
  localDesktopPackageJson = lib.importJSON "${t3codeSrc}/apps/desktop/package.json";
  version = localDesktopPackageJson.version;
  commonMeta = {
    description = "T3 Code desktop app";
    homepage = "https://github.com/pingdotgg/t3code";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    downloadPage = "https://github.com/pingdotgg/t3code/releases";
    license = lib.licenses.mit;
    mainProgram = pname;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
    ];
  };

  linuxPackage = stdenv.mkDerivation {
    inherit pname version;

    src = t3codeSrc;

    nativeBuildInputs = [
      bun
      electron
      makeWrapper
      nodejs_24
    ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      export HOME="$TMPDIR/home"
      export XDG_CACHE_HOME="$TMPDIR/.cache"
      export BUN_INSTALL_CACHE_DIR="$TMPDIR/.bun-install"
      mkdir -p "$HOME" "$XDG_CACHE_HOME" "$BUN_INSTALL_CACHE_DIR"

      export PATH="$PWD/node_modules/.bin:$PATH"

      patchShebangs .

      turbo_entrypoint="$(readlink -f node_modules/.bin/turbo)"
      ${nodejs_24}/bin/node "$turbo_entrypoint" run build --filter=@t3tools/desktop --filter=t3

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p \
        "$out/apps/desktop" \
        "$out/apps/server" \
        "$out/bin" \
        "$out/share/applications" \
        "$out/share/pixmaps"

      cp -r apps/desktop/dist-electron "$out/apps/desktop/dist-electron"
      cp -r apps/desktop/resources "$out/apps/desktop/resources"
      cp -r apps/server/dist "$out/apps/server/dist"

      install -Dm444 assets/prod/black-universal-1024.png "$out/share/pixmaps/${pname}.png"

      cat > "$out/share/applications/${pname}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=T3 Code (Alpha)
Exec=${pname} %U
TryExec=${pname}
Icon=${pname}
StartupWMClass=t3code
Categories=Development;
Terminal=false
EOF

      makeWrapper ${electron}/bin/electron "$out/bin/${pname}" \
        --set CHROME_DESKTOP "${pname}.desktop" \
        --prefix XDG_DATA_DIRS : "$out/share" \
        --run "cd '$out/apps/desktop'" \
        --add-flags "dist-electron/main.cjs" \
        ${lib.optionalString codexSupport ''
          --prefix PATH : "${lib.makeBinPath [ codex ]}"
        ''}

      runHook postInstall
    '';

    meta = commonMeta // {
      description = "T3 Code desktop app built from the local monorepo source";
    };
  };

in
if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64 then
  linuxPackage
else if stdenv.hostPlatform.isDarwin then
  throw "local t3code source packaging is currently wired only for x86_64-linux"
else
  throw "local t3code source packaging is currently wired only for x86_64-linux"
