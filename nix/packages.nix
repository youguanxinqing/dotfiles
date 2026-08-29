{ pkgs, herdrPackage, inputs }:

let
  buildRustPackage = name: version: src:
    pkgs.rustPlatform.buildRustPackage {
      pname = name;
      inherit version src;
      cargoLock.lockFile = src + "/Cargo.lock";
    };
in
{
  ai-commit-message = buildRustPackage
    "ai-commit-message"
    "0.1.0"
    inputs.ai-commit-message-src;

  bootmux = pkgs.rustPlatform.buildRustPackage {
    pname = "bootmux";
    version = "0.3.3";
    src = inputs.bootmux-src;
    cargoLock.lockFile = inputs.bootmux-src + "/Cargo.lock";

    postInstall = ''
      install -Dm644 completion/bootmux.bash \
        $out/share/bash-completion/completions/bootmux
      install -Dm644 completion/bootmux.zsh \
        $out/share/zsh/site-functions/_bootmux
      install -Dm644 completion/bootmux.fish \
        $out/share/fish/vendor_completions.d/bootmux.fish
    '';
  };

  keep = pkgs.rustPlatform.buildRustPackage {
    pname = "keep";
    version = "0.2.1";
    src = inputs.keep-src;
    cargoLock.lockFile = inputs.keep-src + "/Cargo.lock";

    # Keep shells out to Git both in its test suite and at runtime. Git is also
    # present in the Home Manager package set; this input makes sandboxed tests
    # exercise the same integration instead of failing on an empty PATH.
    nativeCheckInputs = [ pkgs.git ];

    # This test depends on observing orphaned processes after SIGKILL. Process
    # namespaces make that timing assertion unreliable inside the Nix sandbox.
    checkFlags = [
      "--skip"
      "a_hard_killed_supervisor_leaves_orphans_that_the_next_command_reaps"
    ];
  };

  staticcheck = pkgs.buildGoModule {
    pname = "staticcheck";
    version = "2026.2.1";
    src = inputs.staticcheck-src;
    vendorHash = "sha256-3no4wPqFG0RfSsWB0z8EYxeoZ30t+Zf7ZayzFCLEm2A=";
    subPackages = [ "cmd/staticcheck" ];
  };

  lxgw-wenkai-local = pkgs.stdenvNoCC.mkDerivation {
    pname = "lxgw-wenkai-local";
    version = "dotfiles";
    src = ../fonts/lxgw-wenkai;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -d "$out/share/fonts/truetype/LXGWWenKai"
      install -m644 *.ttf "$out/share/fonts/truetype/LXGWWenKai/"
      install -Dm644 OFL.txt "$out/share/licenses/$pname/OFL.txt"
      runHook postInstall
    '';
  };

  herdr = herdrPackage;
}
