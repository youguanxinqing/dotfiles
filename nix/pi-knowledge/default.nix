{ lib, buildNpmPackage, python3, autoPatchelfHook, stdenv }:

buildNpmPackage {
  pname = "pi-knowledge";
  version = (lib.importJSON ./package.json).dependencies.pi-knowledge;
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./package.json ./package-lock.json ];
  };
  npmDepsHash = "sha256-gDjusmqP90Rd1mLCwGvGR1yOgFGrkVAbfiD/FUb6FII=";

  nativeBuildInputs = [ python3 ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  # Build SQLite and the parsers against Nix's Node, with no runtime compiler
  # or npm needed. The CPU ONNX runtime is included in its npm tarball.
  ONNXRUNTIME_NODE_INSTALL_CUDA = "skip";
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/node_modules"
    cp -a node_modules/. "$out/node_modules/"
    cp -a node_modules/pi-knowledge/. "$out/"
    ${lib.optionalString (stdenv.isLinux && !stdenv.hostPlatform.isMusl) ''
      # NixOS uses glibc; the bundled musl variant cannot be linked here.
      rm -f "$out/node_modules/better-sqlite3/prebuilds/"linuxmusl-*.node
    ''}
    runHook postInstall
  '';
}
