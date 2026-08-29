#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for stage in 01-base-zsh.sh 02-agents.sh 03-rocm.sh; do
    echo "=== Running comfy/$stage ==="
    bash "$SCRIPT_DIR/comfy/$stage"
done
