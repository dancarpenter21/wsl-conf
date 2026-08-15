#!/usr/bin/env bash

set -euo pipefail

echo "=== Updating packages ==="
sudo apt update
sudo apt upgrade -y

echo "=== Installing font prerequisites ==="
sudo apt install -y \
    curl \
    ca-certificates \
    fontconfig

###############################################################################
# NERD FONTS
###############################################################################

NERD_FONTS_DIR="$HOME/.local/share/fonts/NerdFonts"
NERD_FONTS_COMMIT="ca64c0b2114c86980388c712e92b74ed737e3443"
NERD_FONTS_BASE_URL="https://raw.githubusercontent.com/romkatv/dotfiles-public/$NERD_FONTS_COMMIT/.local/share/fonts/NerdFonts"
NERD_FONTS=(
    "MesloLGS NF Bold Italic.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Regular.ttf"
)

echo "=== Installing Nerd Fonts ==="
mkdir -p "$NERD_FONTS_DIR"

for font in "${NERD_FONTS[@]}"; do
    font_path="$NERD_FONTS_DIR/$font"

    if [ ! -f "$font_path" ]; then
        curl -fL --retry 3 \
            --output "$font_path.tmp" \
            "${NERD_FONTS_BASE_URL}/${font// /%20}"
        mv "$font_path.tmp" "$font_path"
    fi
done

fc-cache -f "$NERD_FONTS_DIR"

echo "=== Installing base packages ==="
sudo apt install -y \
    zsh \
    git \
    wget \
    unzip \
    build-essential \
    ripgrep \
    fd-find

###############################################################################
# Git configs
###############################################################################

git config --global init.defaultBranch main

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
# TMUX MOUSE
###############################################################################

cat >> ~/.tmux.conf << 'EOF'
set -g mouse on
EOF

###############################################################################
# SUMMARY
###############################################################################

echo
echo "======================================"
echo "Installation complete"
echo "======================================"
echo
echo "Installed:"
echo "  ✓ MesloLGS Nerd Fonts"
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
echo "  1. Configure Windows Terminal to use MesloLGS NF"
echo "  2. Restart WSL"
echo "Then for WSL or Linux:"
echo "  1. Run: p10k configure"
echo
