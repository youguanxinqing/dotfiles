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
  pi-knowledge = pkgs.callPackage ./pi-knowledge { };

  # This release has no runtime dependencies; Pi provides its peer modules.
  pi-open-tui = pkgs.fetchzip {
    name = "pi-open-tui-0.3.13";
    url = "https://registry.npmjs.org/pi-open-tui/-/pi-open-tui-0.3.13.tgz";
    hash = "sha256-zGhEZN5PnX7pQ5iAfgKWqxHiTURPE76AE+KKDBw96sw=";
  };

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
# rexume 只为 Linux 发静态 musl 二进制（macOS 走 Homebrew，见 modules/rexume），
# 静态链接，不用 patchelf。升级：改 version 和两个 hash（取 release 里的 .sha256）。
// pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  rexume =
    let
      version = "0.1.26";
      arch = pkgs.stdenv.hostPlatform.parsed.cpu.name;
      hash = {
        x86_64 = "sha256-gxldW88p+fHqaGJ1sCdjQa0qKa6ko5rabOM1nm1aKtM=";
        aarch64 = "sha256-+5/vIzci/J0MTEumb7uGiAwjB6m7DZWGUh1Ftcor54s=";
      }.${arch};
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "rexume";
      inherit version;
      src = pkgs.fetchurl {
        url = "https://github.com/Entwining/rexume/releases/download/v${version}/rexume-${version}-${arch}-unknown-linux-musl.tar.gz";
        inherit hash;
      };
      installPhase = ''
        runHook preInstall
        install -Dm755 bin/rexume "$out/bin/rexume"
        install -Dm644 LICENSE "$out/share/licenses/rexume/LICENSE"
        runHook postInstall
      '';
    };
}
