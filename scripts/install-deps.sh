#!/bin/bash

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Rust if not already installed
if ! command_exists rustc; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

    # Update rust repo source
    cat > ~/.cargo/config << 'EOF'
[source.crates-io]
replace-with = 'rsproxy-sparse'
[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"
[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"
[net]
git-fetch-with-cli = true
EOF

    # Source rust environment for current session
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed"
fi

# Install goup-rs if not already installed
if ! command_exists goup; then
    echo "Installing goup-rs..."
    cargo install goup-rs --git https://github.com/thinkgos/goup-rs
    goup init
else
    echo "goup-rs is already installed"
fi

# Install ripgrep if not already installed
if ! command_exists rg; then
    echo "Installing ripgrep..."
    cargo install ripgrep
else
    echo "ripgrep is already installed"
fi

# Install fnm if not already installed
if ! command_exists fnm; then
    echo "Installing fnm..."
    cargo install fnm
else
    echo "fnm is already installed"
fi

# Install just if not already installed
if ! command_exists just; then
    echo "Installing just..."
    cargo install just
else
    echo "just is already installed"
fi

# Install delta if not already installed
if ! command_exists delta; then
    echo "Installing delta..."
    cargo install git-delta

    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    git config --global delta.navigate true
    git config --global merge.conflictStyle zdiff3
else
    echo "delta is already installed"
fi

# Install fzf if not already installed
if ! command_exists fzf; then
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install
else
    echo "fzf is already installed"
fi

# TODO install uv

echo "All dependencies installation completed!"

