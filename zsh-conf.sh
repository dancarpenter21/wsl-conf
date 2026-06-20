#!/usr/bin/env bash

set -euo pipefail

echo "=== Updating packages ==="
sudo apt update
sudo apt upgrade -y

echo "=== Installing base packages ==="
sudo apt install -y \
    zsh \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    ripgrep \
    fd-find \
    ca-certificates

###############################################################################
# OH MY ZSH
###############################################################################

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "=== Installing Oh My Zsh ==="
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

###############################################################################
# POWERLEVEL10K
###############################################################################

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

if [ ! -d "$P10K_DIR" ]; then
    echo "=== Installing Powerlevel10k ==="
    git clone --depth=1 \
        https://github.com/romkatv/powerlevel10k.git \
        "$P10K_DIR"
fi

###############################################################################
# ZSH PLUGINS
###############################################################################

AUTOSUGGEST_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

if [ ! -d "$AUTOSUGGEST_DIR" ]; then
    echo "=== Installing zsh-autosuggestions ==="
    git clone \
        https://github.com/zsh-users/zsh-autosuggestions \
        "$AUTOSUGGEST_DIR"
fi

SYNTAX_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

if [ ! -d "$SYNTAX_DIR" ]; then
    echo "=== Installing zsh-syntax-highlighting ==="
    git clone \
        https://github.com/zsh-users/zsh-syntax-highlighting \
        "$SYNTAX_DIR"
fi

###############################################################################
# CONFIGURE ZSH
###############################################################################

if [ ! -f "$HOME/.zshrc" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
fi

sed -i \
    's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' \
    "$HOME/.zshrc"

sed -i \
    's/^plugins=(.*)/plugins=(git python zsh-autosuggestions zsh-syntax-highlighting)/' \
    "$HOME/.zshrc"

###############################################################################
# FZF
###############################################################################

if [ ! -d "$HOME/.fzf" ]; then
    echo "=== Installing fzf ==="
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all
fi

###############################################################################
# NVM
###############################################################################

if [ ! -d "$HOME/.nvm" ]; then
    echo "=== Installing NVM ==="
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"

    echo "=== Installing latest LTS Node ==="
    nvm install --lts
    nvm alias default 'lts/*'
fi

###############################################################################
# RUSTUP
###############################################################################

if [ ! -d "$HOME/.cargo" ]; then
    echo "=== Installing Rust ==="
    curl https://sh.rustup.rs -sSf | sh -s -- -y
fi

source "$HOME/.cargo/env"

###############################################################################
# UV
###############################################################################

if ! command -v uv >/dev/null 2>&1; then
    echo "=== Installing uv ==="
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

###############################################################################
# SHELL CONFIGURATION
###############################################################################

grep -q 'cargo/env' "$HOME/.zshrc" || cat >> "$HOME/.zshrc" <<'EOF'

# Rust
source "$HOME/.cargo/env"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# uv
export PATH="$HOME/.local/bin:$PATH"

# Use Windows OpenSSH agent when running inside WSL
if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v ssh.exe >/dev/null 2>&1; then
    export GIT_SSH_COMMAND="ssh.exe"
fi

# Ubuntu installs fd as fdfind
alias fd='fdfind'

# Local machine-specific overrides
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

EOF

###############################################################################
# DEFAULT SHELL
###############################################################################

if [ "$SHELL" != "$(which zsh)" ]; then
    echo "=== Setting zsh as default shell ==="
    chsh -s "$(which zsh)"
fi

###############################################################################
# SUMMARY
###############################################################################

echo
echo "======================================"
echo "Installation complete"
echo "======================================"
echo
echo "Installed:"
echo "  ✓ zsh"
echo "  ✓ oh-my-zsh"
echo "  ✓ powerlevel10k"
echo "  ✓ zsh-autosuggestions"
echo "  ✓ zsh-syntax-highlighting"
echo "  ✓ fzf"
echo "  ✓ fd-find"
echo "  ✓ ripgrep"
echo "  ✓ nvm"
echo "  ✓ node (LTS)"
echo "  ✓ rustup"
echo "  ✓ cargo"
echo "  ✓ uv"
echo
echo "Next steps for WSL:"
echo "  1. Install a Nerd Font (MesloLGS NF recommended)"
echo "  2. Configure Windows Terminal to use the Nerd Font"
echo "  3. Restart WSL"
echo "Then for WSL or Linux:"
echo "  1. Run: p10k configure"
echo
