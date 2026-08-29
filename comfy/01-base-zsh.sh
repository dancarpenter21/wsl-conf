#!/usr/bin/env bash

set -euo pipefail

if ! grep -qi microsoft /proc/version; then
    echo "This script is intended for WSL2." >&2
    exit 1
fi

# shellcheck source=/dev/null
source /etc/os-release
if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
    echo "This script requires Ubuntu 24.04 under WSL2." >&2
    exit 1
fi

echo "=== Updating packages ==="
sudo apt update
sudo apt upgrade -y

echo "=== Installing base packages ==="
sudo apt install -y \
    curl ca-certificates fontconfig zsh git wget unzip xz-utils \
    build-essential cmake ripgrep fd-find

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
        curl -fL --retry 3 --output "$font_path.tmp" \
            "${NERD_FONTS_BASE_URL}/${font// /%20}"
        mv "$font_path.tmp" "$font_path"
    fi
done
fc-cache -f "$NERD_FONTS_DIR"

###############################################################################
# GIT AND DEFAULT SHELL
###############################################################################

git config --global init.defaultBranch main
zsh_path="$(command -v zsh)"
login_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$login_shell" != "$zsh_path" ]; then
    echo "=== Setting zsh as default shell ==="
    chsh -s "$zsh_path"
fi

###############################################################################
# OH MY ZSH, POWERLEVEL10K, AND PLUGINS
###############################################################################

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "=== Installing Oh My Zsh ==="
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    echo "=== Installing Powerlevel10k ==="
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

AUTOSUGGEST_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
if [ ! -d "$AUTOSUGGEST_DIR" ]; then
    echo "=== Installing zsh-autosuggestions ==="
    git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGEST_DIR"
fi

SYNTAX_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
if [ ! -d "$SYNTAX_DIR" ]; then
    echo "=== Installing zsh-syntax-highlighting ==="
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$SYNTAX_DIR"
fi

###############################################################################
# CONFIGURE ZSH
###############################################################################

if [ ! -f "$HOME/.zshrc" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
fi

sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
sed -i 's/^plugins=(.*)/plugins=(git python zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
grep -q '^ZSH=' "$HOME/.zshrc" || echo 'ZSH="$HOME/.oh-my-zsh"' >> "$HOME/.zshrc"
grep -q '^ZSH_THEME=' "$HOME/.zshrc" || echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$HOME/.zshrc"
grep -q '^plugins=' "$HOME/.zshrc" || echo 'plugins=(git python zsh-autosuggestions zsh-syntax-highlighting)' >> "$HOME/.zshrc"
if ! grep -Eq '^[[:space:]]*(source|\.)[[:space:]]+.*oh-my-zsh\.sh' "$HOME/.zshrc"; then
    echo 'source "$ZSH/oh-my-zsh.sh"' >> "$HOME/.zshrc"
fi

if ! grep -Eq '^# (comfy base zsh|comfy-conf\.sh)$' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" <<'EOF'

# comfy base zsh
# Use Windows OpenSSH agent when running inside WSL
if [[ -n "${WSL_DISTRO_NAME:-}" ]] && command -v ssh.exe >/dev/null 2>&1; then
    export GIT_SSH_COMMAND="ssh.exe"
fi

# Ubuntu installs fd as fdfind
alias fd='fdfind'

# Local machine-specific overrides
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
EOF
fi

###############################################################################
# FZF AND TMUX
###############################################################################

if [ ! -d "$HOME/.fzf" ]; then
    echo "=== Installing fzf ==="
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all
fi

touch "$HOME/.tmux.conf"
grep -qxF 'set -g mouse on' "$HOME/.tmux.conf" || echo 'set -g mouse on' >> "$HOME/.tmux.conf"

if [ -t 0 ] && [ -t 1 ] && [ ! -f "$HOME/.p10k.zsh" ]; then
    echo "=== Configuring Powerlevel10k ==="
    zsh -ic 'p10k configure'
elif [ ! -f "$HOME/.p10k.zsh" ]; then
    echo "=== Skipping interactive Powerlevel10k configuration ==="
    echo "Run 'p10k configure' from a terminal."
fi

echo "=== Base zsh configuration complete ==="
