{
  lib,
  stdenv,
  bun,
  makeWrapper,
  nodejs_24,
  t3codeSrc,
  codexSupport ? true,
  codex,
}:

let
  packageJson = lib.importJSON "${t3codeSrc}/apps/server/package.json";
in
stdenv.mkDerivation {
  pname = "t3-cli";
  inherit (packageJson) version;

  src = t3codeSrc;

  nativeBuildInputs = [
    bun
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
    ${nodejs_24}/bin/node "$turbo_entrypoint" run build --filter=@t3tools/web --filter=t3

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/apps/server" "$out/bin"
    cp -r apps/server/dist "$out/apps/server/dist"
    cp apps/server/package.json "$out/apps/server/package.json"

    makeWrapper ${nodejs_24}/bin/node "$out/bin/t3" \
      --add-flags "$out/apps/server/dist/bin.mjs" \
      ${lib.optionalString codexSupport ''
        --prefix PATH : "${lib.makeBinPath [ codex ]}"
      ''}

    runHook postInstall
  '';

  meta = with lib; {
    description = "T3 Code CLI built from the local monorepo source";
    homepage = "https://github.com/pingdotgg/t3code";
    license = licenses.mit;
    mainProgram = "t3";
    platforms = platforms.unix;
  };
}
