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

# Codex installs its launcher in ~/.local/bin. Hermes installs its managed uv
# and Node/npm toolchains under ~/.hermes. Configure zsh directly rather than
# sourcing .zshrc here: .zshrc is interactive configuration and this is Bash.
AGENTS_PATH='$HOME/.local/bin:$HOME/.hermes/bin:$HOME/.hermes/node/bin'
if ! grep -Fq "$AGENTS_PATH" "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" <<'EOF'

# comfy coding agents (Codex and Hermes-managed uv/Node/npm)
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$HOME/.hermes/node/bin:$PATH"
EOF
fi
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$HOME/.hermes/node/bin:$PATH"

if ! command -v codex >/dev/null 2>&1; then
    echo "=== Installing OpenAI Codex ==="
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
else
    echo "=== OpenAI Codex is already installed ==="
fi

# The installer creates the launcher during the command above. Refresh PATH in
# this process and fail here with a useful diagnostic if installation did not.
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$HOME/.hermes/node/bin:$PATH"
if ! command -v codex >/dev/null 2>&1; then
    echo "Codex installed, but ~/.local/bin/codex is not available on PATH." >&2
    exit 1
fi

if ! command -v grok >/dev/null 2>&1; then
    echo "=== Installing Grok Build ==="
    curl -fsSL https://x.ai/cli/install.sh | bash
else
    echo "=== Grok Build is already installed ==="
fi

if ! command -v hermes >/dev/null 2>&1; then
    echo "=== Installing Hermes Agent (including uv and npm) ==="
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
else
    echo "=== Hermes Agent is already installed ==="
fi

export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$HOME/.hermes/node/bin:$PATH"
for hermes_tool in hermes uv npm; do
    if ! command -v "$hermes_tool" >/dev/null 2>&1; then
        echo "Hermes installed, but $hermes_tool is not available on PATH." >&2
        exit 1
    fi
done

if [ -t 0 ] && [ -t 1 ]; then
    echo "=== Configuring Hermes Agent ==="
    hermes setup --quick
else
    echo "=== Skipping interactive Hermes configuration ==="
    echo "Run 'hermes setup --quick' from a terminal."
fi

echo "=== Coding agents installation complete ==="
