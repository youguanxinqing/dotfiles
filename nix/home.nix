{ self }:

{ config, pkgs, lib, ... }:

let
  dotfilesPackages = self.packages.${pkgs.stdenv.hostPlatform.system};
  dotfilesRoot = "${config.home.homeDirectory}/dotfiles";
  outOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;
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

    # Home Manager keeps ownership of the generated config.fish so it can load
    # session variables. The actual Fish entry point stays live in the dotfiles
    # checkout and still runs after every conf.d snippet.
    shellInit = ''
      source "${dotfilesRoot}/configs/fish/config.fish"
    '';
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

  # Keep Fish's supporting configuration live in the same checkout as its
  # config.fish entry point. This deliberately uses out-of-store links so edits
  # made through ~/dotfiles apply to newly started shells without a rebuild.
  xdg.configFile."fish/conf.d" = {
    source = outOfStoreSymlink "${dotfilesRoot}/configs/fish/conf.d";
  };
  xdg.configFile."fish/functions" = {
    source = outOfStoreSymlink "${dotfilesRoot}/configs/fish/functions";
  };
  xdg.configFile."fish/completions" = {
    source = outOfStoreSymlink "${dotfilesRoot}/configs/fish/completions";
  };

  home.sessionPath = lib.mkAfter [ "$HOME/.local/bin" ];

  # Recursive Home Manager deployment links every tracked helper while allowing
  # unrelated runtime/user files to coexist below ~/.local/bin.
  home.file.".local/bin" = {
    source = self.outPath + "/bin";
    recursive = true;
  };
}
