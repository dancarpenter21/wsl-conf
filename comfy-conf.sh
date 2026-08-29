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
    xz-utils \
    build-essential \
    cmake \
    ripgrep \
    fd-find

###############################################################################
# GIT CONFIG
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
# TMUX MOUSE
###############################################################################

touch "$HOME/.tmux.conf"
grep -qxF 'set -g mouse on' "$HOME/.tmux.conf" || \
    echo 'set -g mouse on' >> "$HOME/.tmux.conf"

###############################################################################
# HERMES AGENT
###############################################################################

if ! command -v hermes >/dev/null 2>&1; then
    echo "=== Installing Hermes Agent (including uv and npm) ==="
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
else
    echo "=== Hermes Agent is already installed ==="
fi

# The Hermes installer links its commands here, but a child installer cannot
# update this script's environment. Make its bundled tools available now.
export PATH="$HOME/.local/bin:$PATH"

for hermes_tool in hermes uv npm; do
    if ! command -v "$hermes_tool" >/dev/null 2>&1; then
        echo "Hermes installed, but $hermes_tool is not available on PATH." >&2
        exit 1
    fi
done

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

# KEEP_ZSHRC preserves an existing file, which might not have come from Oh My
# Zsh. Ensure the minimum required settings exist instead of assuming that it
# contains the template entries matched above.
grep -q '^ZSH=' "$HOME/.zshrc" || \
    echo 'ZSH="$HOME/.oh-my-zsh"' >> "$HOME/.zshrc"
grep -q '^ZSH_THEME=' "$HOME/.zshrc" || \
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$HOME/.zshrc"
grep -q '^plugins=' "$HOME/.zshrc" || \
    echo 'plugins=(git python zsh-autosuggestions zsh-syntax-highlighting)' >> "$HOME/.zshrc"

if ! grep -Eq '^[[:space:]]*(source|\.)[[:space:]]+.*oh-my-zsh\.sh' "$HOME/.zshrc"; then
    echo 'source "$ZSH/oh-my-zsh.sh"' >> "$HOME/.zshrc"
fi

###############################################################################
# DEFAULT SHELL
###############################################################################

zsh_path="$(command -v zsh)"
login_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"

if [ "$login_shell" != "$zsh_path" ]; then
    echo "=== Setting zsh as default shell ==="
    chsh -s "$zsh_path"
fi

echo "=== zsh and Powerlevel10k are ready ==="

###############################################################################
# INTERACTIVE CONFIGURATION
###############################################################################

if [ -t 0 ] && [ -t 1 ]; then
    if [ ! -f "$HOME/.p10k.zsh" ]; then
        echo "=== Configuring Powerlevel10k ==="
        zsh -ic 'p10k configure'
    else
        echo "=== Powerlevel10k is already configured ==="
    fi

    echo "=== Configuring Hermes Agent ==="
    hermes setup --quick
else
    echo "=== Skipping interactive Powerlevel10k and Hermes configuration ==="
    echo "Run 'p10k configure' and 'hermes setup --quick' from a terminal."
fi

###############################################################################
# FZF
###############################################################################

if [ ! -d "$HOME/.fzf" ]; then
    echo "=== Installing fzf ==="
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all
fi

###############################################################################
# SHELL CONFIGURATION
###############################################################################

if ! grep -q '# comfy-conf.sh' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" <<'EOF'

# comfy-conf.sh
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
fi

if ! grep -q '# ROCm and ROCDXG for WSL2' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" <<'EOF'

# ROCm and ROCDXG for WSL2
export PATH="/opt/rocm/bin:/opt/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export HSA_ENABLE_DXG_DETECTION=1

EOF
fi

export PATH="/opt/rocm/bin:/opt/rocm/llvm/bin:$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export HSA_ENABLE_DXG_DETECTION=1

###############################################################################
# CODING AGENTS
###############################################################################

if ! command -v codex >/dev/null 2>&1; then
    echo "=== Installing OpenAI Codex ==="
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
else
    echo "=== OpenAI Codex is already installed ==="
fi

if ! command -v grok >/dev/null 2>&1; then
    echo "=== Installing Grok Build ==="
    curl -fsSL https://x.ai/cli/install.sh | bash
else
    echo "=== Grok Build is already installed ==="
fi

###############################################################################
# ROCM + ROCDXG FOR RX 9070 XT ON WSL2
###############################################################################

if [ ! -e /dev/dxg ]; then
    echo "/dev/dxg is missing." >&2
    echo "zsh and Powerlevel10k were installed successfully, but the GPU setup" >&2
    echo "cannot continue. Install an AMD Adrenalin driver with WSL2 ROCm support" >&2
    echo "in Windows, reboot Windows, run 'wsl --update', and try again." >&2
    exit 1
fi

ROCM_VERSION="7.2.4"
# The patch-versioned amdgpu-install package is the generic Linux installer and
# does not provide the WSL use case. AMD publishes a separate Radeon/WSL
# installer for the 7.2 release line.
AMDGPU_INSTALL_RELEASE="7.2"
AMDGPU_INSTALL_VERSION="7.2.70200-1"
ROCDXG_VERSION="1.2.0"

echo "=== Installing the ROCm $ROCM_VERSION package repository ==="
ROCM_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$ROCM_TMP_DIR"' EXIT

curl -fL --retry 3 \
    --output "$ROCM_TMP_DIR/amdgpu-install.deb" \
    "https://repo.radeon.com/amdgpu-install/$AMDGPU_INSTALL_RELEASE/ubuntu/noble/amdgpu-install_${AMDGPU_INSTALL_VERSION}_all.deb"
# A previous run may have installed the newer generic package before failing on
# --usecase=wsl, so permit replacing it with the WSL-capable package.
sudo apt install -y --allow-downgrades "$ROCM_TMP_DIR/amdgpu-install.deb"

installed_rocm_version="$(dpkg-query -W -f='${Version}' rocm-core 2>/dev/null || true)"
if [[ "$installed_rocm_version" != *"$ROCM_VERSION"* ]]; then
    if [ -n "$installed_rocm_version" ]; then
        echo "ROCm $installed_rocm_version is already installed." >&2
        echo "AMD does not support in-place ROCm upgrades; run 'sudo amdgpu-uninstall'" >&2
        echo "and then rerun this script to install ROCm $ROCM_VERSION." >&2
        exit 1
    fi

    echo "=== Installing ROCm userspace components for WSL2 ==="
    sudo amdgpu-install -y --usecase=wsl,rocm --no-dkms
else
    echo "=== ROCm $ROCM_VERSION is already installed ==="
fi

echo "=== Installing ROCDXG $ROCDXG_VERSION ==="
curl -fL --retry 3 \
    --output "$ROCM_TMP_DIR/rocdxg-roct.deb" \
    "https://github.com/ROCm/librocdxg/releases/download/v$ROCDXG_VERSION/rocdxg-roct_${ROCDXG_VERSION}_amd64.deb"
sudo apt install -y "$ROCM_TMP_DIR/rocdxg-roct.deb"
sudo ldconfig

rm -rf -- "$ROCM_TMP_DIR"
trap - EXIT

echo "=== Verifying ROCm can see the RX 9070 XT ==="
if ! rocm_info="$(rocminfo 2>&1)"; then
    echo "$rocm_info" >&2
    echo "rocminfo failed. Check the Windows AMD driver and /dev/dxg." >&2
    exit 1
fi

if ! grep -q 'gfx1201' <<< "$rocm_info"; then
    echo "$rocm_info" | grep -E 'Name:|Marketing Name:' || true
    echo "ROCm did not detect the expected RX 9070 XT (gfx1201)." >&2
    exit 1
fi

echo "$rocm_info" | grep -E 'Name:.*gfx1201|Marketing Name:.*9070 XT' || true

# COMFYUI
###############################################################################

COMFYUI_DIR="${COMFYUI_DIR:-$HOME/ComfyUI}"

if [ ! -d "$COMFYUI_DIR/.git" ]; then
    if [ -e "$COMFYUI_DIR" ]; then
        echo "Cannot install ComfyUI: $COMFYUI_DIR exists but is not a git checkout." >&2
        exit 1
    fi

    echo "=== Cloning ComfyUI ==="
    git clone https://github.com/Comfy-Org/ComfyUI.git "$COMFYUI_DIR"
fi

echo "=== Creating the ComfyUI environment ==="
uv venv "$COMFYUI_DIR/.venv" --python 3.12

echo "=== Installing AMD-validated PyTorch for ROCm $ROCM_VERSION ==="
uv pip install --python "$COMFYUI_DIR/.venv/bin/python" \
    numpy==1.26.4 \
    torch==2.9.1 \
    torchvision==0.24.0 \
    torchaudio==2.9.0 \
    -f "https://repo.radeon.com/rocm/manylinux/rocm-rel-$ROCM_VERSION/"

echo "=== Installing ComfyUI dependencies ==="
uv pip install --python "$COMFYUI_DIR/.venv/bin/python" \
    -r "$COMFYUI_DIR/requirements.txt"

# AMD's WSL instructions require PyTorch to use the system HSA runtime, which
# is connected to the Windows DXG device by ROCDXG, instead of its bundled copy.
find "$COMFYUI_DIR/.venv/lib" \( -type f -o -type l \) -path \
    '*/site-packages/torch/lib/libhsa-runtime64.so*' -delete

echo "=== Verifying PyTorch GPU access ==="
"$COMFYUI_DIR/.venv/bin/python" <<'PY'
import torch

print("torch:", torch.__version__)
print("hip:", torch.version.hip)
print("available:", torch.cuda.is_available())

if "+rocm7.2.4" not in torch.__version__:
    raise SystemExit(f"Expected the ROCm 7.2.4 wheel, but installed: {torch.__version__}")

if not torch.cuda.is_available():
    raise SystemExit("PyTorch cannot access the AMD GPU through ROCm/ROCDXG")

device_name = torch.cuda.get_device_name(0)
print("device:", device_name)
if "9070 XT" not in device_name:
    raise SystemExit(f"Expected an RX 9070 XT, but PyTorch found: {device_name}")

x = torch.randn(1024, 1024, device="cuda")
y = x @ x
print("smoke-test checksum:", y.mean().item())
PY

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
echo "  ✓ ROCm $ROCM_VERSION"
echo "  ✓ ROCDXG $ROCDXG_VERSION"
echo "  ✓ PyTorch 2.9.1 for ROCm"
echo "  ✓ Hermes Agent"
echo "  ✓ OpenAI Codex"
echo "  ✓ Grok Build"
echo "  ✓ ComfyUI (RX 9070 XT)"
echo
echo "Next steps for WSL:"
echo "  1. Configure Windows Terminal to use MesloLGS NF"
echo "  2. Restart WSL"
echo "Then for WSL or Linux:"
echo "  1. Run: hermes"
echo "  2. Add models under: $COMFYUI_DIR/models"
echo "  3. Start ComfyUI with:"
echo "     cd \"$COMFYUI_DIR\" && .venv/bin/python main.py"
echo "  4. Open: http://127.0.0.1:8188"
echo
