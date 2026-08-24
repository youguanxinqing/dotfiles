set -gx EDITOR nvim
set -gx XDG_CONFIG_HOME "$HOME/.config"

# Keep third-party CLI entry points in the one user bin directory. Toolchain
# caches and versioned runtimes remain in their managers' own directories.
set -gx CARGO_INSTALL_ROOT "$HOME/.local"
set -gx GOBIN "$HOME/.local/bin"

# Mainland China mirrors. These configure downloads; they are not PATH entries.
set -gx RUSTUP_DIST_SERVER https://rsproxy.cn
set -gx RUSTUP_UPDATE_ROOT https://rsproxy.cn/rustup

if test -d "$HOME/tools/flutter"
    set -gx PUB_HOSTED_URL https://pub.flutter-io.cn
    set -gx FLUTTER_STORAGE_BASE_URL https://storage.flutter-io.cn
end
