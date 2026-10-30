{ self }:

{ config, pkgs, lib, ... }:

let
  dotfilesPackages = self.packages.${pkgs.stdenv.hostPlatform.system};
  piPackages = {
    inherit (dotfilesPackages) pi-open-tui;
  };
  piPackageRoot = "${config.home.homeDirectory}/.pi/agent/nix-packages";
  piPackageManifest = pkgs.writeText "pi-packages.json" (builtins.toJSON {
    root = piPackageRoot;
    names = builtins.attrNames piPackages;
  });
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

  # Keep terminal-specific appearance out of the desktop's global defaults.
  programs.alacritty = {
    enable = true;
    settings = {
      colors.transparent_background_colors = true;
      font = {
        size = 14.0;
        normal.family = "LXGW WenKai Mono Screen";
        bold.family = "LXGW WenKai Mono Screen";
        italic.family = "LXGW WenKai Mono Screen";
        bold_italic.family = "LXGW WenKai Mono Screen";
      };
      window = {
        decorations = "None";
        opacity = 0.9;
      };
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

  home.file = lib.mapAttrs' (name: source:
    lib.nameValuePair ".pi/agent/nix-packages/${name}" { inherit source; }
  ) piPackages // {
    # Link tracked helpers while preserving unrelated local executables.
    ".local/bin" = {
      source = self.outPath + "/bin";
      recursive = true;
    };
  };

  # Pi writes model choices and resource filters here. Merge only our packages
  # rather than replacing settings.json with a read-only store symlink.
  home.activation.piPackages = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    run ${pkgs.python3}/bin/python3 ${./pi-settings.py} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/settings.json"} \
      ${piPackageManifest}
  '';

  systemd.user.services.note-sync = {
    Unit.Description = "Synchronize notes with their Git upstream";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${self.outPath}/cron/note-sync.sh ${config.home.homeDirectory}/Documents/noarmal-note-seq";
      Environment = "PATH=${lib.makeBinPath [ pkgs.git pkgs.openssh pkgs.coreutils pkgs.util-linux ]}";
      TimeoutStartSec = "10min";
    };
  };
  systemd.user.timers.note-sync = {
    Unit.Description = "Synchronize notes every 30 minutes";
    Timer = {
      OnCalendar = "*:0/30";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
