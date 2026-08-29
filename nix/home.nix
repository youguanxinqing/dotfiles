{ self }:

{ pkgs, lib, ... }:

let
  dotfilesPackages = self.packages.${pkgs.stdenv.hostPlatform.system};
  sqliteLibrary =
    "${pkgs.sqlite.out}/lib/libsqlite3${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
  neovimWithSqlite = pkgs.symlinkJoin {
    name = "neovim-with-sqlite";
    paths = [ pkgs.neovim ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/nvim" --set LIBSQLITE "${sqliteLibrary}"
    '';
  };
in
{
  home.packages = lib.mkAfter (
    (with pkgs; [
      ast-grep
      bat
      black
      cargo
      clang-tools
      cmake
      delta
      direnv
      eza
      fd
      fzf
      gawk
      gcc
      gh
      git
      go
      gopls
      gotools
      isort
      jq
      just
      libnotify
      neovimWithSqlite
      nodejs
      opencode
      openssl
      perl
      pkg-config
      procps
      protobuf
      python3
      ripgrep
      rtk
      ruff
      rustc
      sqlite
      tcl
      tesseract
      tig
      tmux
      tree-sitter
      util-linux
      uv
      wget
      wl-clipboard
      xclip
      xsel
      xz
      zellij
      zoxide
      zstd
    ])
    ++ (with dotfilesPackages; [
      ai-commit-message
      bootmux
      herdr
      keep
      staticcheck
    ])
  );

  programs.fish = {
    enable = true;
    generateCompletions = false;

    # Fish loads conf.d before config.fish. Keeping this repository entry point
    # in shellInit preserves that ordering while Home Manager still owns its
    # generated config.fish and session variables.
    shellInit = builtins.readFile (self.outPath + "/configs/fish/config.fish");
  };

  # Keep the LXGW font scoped to Alacritty instead of changing the desktop's
  # global monospace default.
  programs.alacritty = {
    enable = true;
    settings.font = {
      size = 14.0;
      normal.family = "LXGW WenKai Mono Screen";
      bold.family = "LXGW WenKai Mono Screen";
      italic.family = "LXGW WenKai Mono Screen";
      bold_italic.family = "LXGW WenKai Mono Screen";
    };
  };

  # These are the same files used by the Bash installer on Arch Linux and
  # macOS. Homebrew and version-manager fragments remain available there and
  # are harmless no-ops on a Nix-native host when their commands are absent.
  xdg.configFile."fish/conf.d" = {
    source = self.outPath + "/configs/fish/conf.d";
    recursive = true;
  };
  xdg.configFile."fish/functions" = {
    source = self.outPath + "/configs/fish/functions";
    recursive = true;
  };
  xdg.configFile."fish/completions" = {
    source = self.outPath + "/configs/fish/completions";
    recursive = true;
  };

  home.sessionPath = lib.mkAfter [ "$HOME/.local/bin" ];

  # Recursive Home Manager deployment links every tracked helper while allowing
  # unrelated runtime/user files to coexist below ~/.local/bin.
  home.file.".local/bin" = {
    source = self.outPath + "/bin";
    recursive = true;
  };
}
