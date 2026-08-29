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

if [ ! -f "$HOME/.zshrc" ]; then
    echo "~/.zshrc is missing. Run comfy/01-base-zsh.sh first." >&2
    exit 1
fi

# Stages run as separate processes, so restore the paths from 02-agents.sh.
export PATH="$HOME/.hermes/bin:$HOME/.hermes/node/bin:$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
    echo "uv is missing. Run comfy/02-agents.sh first." >&2
    exit 1
fi

if ! grep -Eq '^# (comfy ROCm and ROCDXG for WSL2|ROCm and ROCDXG for WSL2)$' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" <<'EOF'

# comfy ROCm and ROCDXG for WSL2
export PATH="/opt/rocm/bin:/opt/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export HSA_ENABLE_DXG_DETECTION=1
EOF
fi

export PATH="/opt/rocm/bin:/opt/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export HSA_ENABLE_DXG_DETECTION=1

if [ ! -e /dev/dxg ]; then
    echo "/dev/dxg is missing." >&2
    echo "Install an AMD Adrenalin driver with WSL2 ROCm support in Windows," >&2
    echo "reboot Windows, run 'wsl --update', and try again." >&2
    exit 1
fi

ROCM_VERSION="7.2.4"
AMDGPU_INSTALL_RELEASE="7.2"
AMDGPU_INSTALL_VERSION="7.2.70200-1"
ROCDXG_VERSION="1.2.0"

echo "=== Installing the ROCm $ROCM_VERSION package repository ==="
ROCM_TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$ROCM_TMP_DIR"' EXIT

curl -fL --retry 3 \
    --output "$ROCM_TMP_DIR/amdgpu-install.deb" \
    "https://repo.radeon.com/amdgpu-install/$AMDGPU_INSTALL_RELEASE/ubuntu/noble/amdgpu-install_${AMDGPU_INSTALL_VERSION}_all.deb"
sudo apt install -y --allow-downgrades "$ROCM_TMP_DIR/amdgpu-install.deb"

installed_rocm_version="$(dpkg-query -W -f='${Version}' rocm-core 2>/dev/null || true)"
if [[ "$installed_rocm_version" != *"$ROCM_VERSION"* ]]; then
    if [ -n "$installed_rocm_version" ]; then
        echo "ROCm $installed_rocm_version is already installed." >&2
        echo "AMD does not support in-place ROCm upgrades; run 'sudo amdgpu-uninstall'" >&2
        echo "and rerun this script to install ROCm $ROCM_VERSION." >&2
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

###############################################################################
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

# Use the system HSA runtime connected to the Windows DXG device by ROCDXG.
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

echo
echo "======================================"
echo "ROCm and ComfyUI installation complete"
echo "======================================"
echo
echo "Next steps:"
echo "  1. Restart WSL"
echo "  2. Add models under: $COMFYUI_DIR/models"
echo "  3. Start ComfyUI with:"
echo "     cd \"$COMFYUI_DIR\" && .venv/bin/python main.py"
echo "  4. Open: http://127.0.0.1:8188"
