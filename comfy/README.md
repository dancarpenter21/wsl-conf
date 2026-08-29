# Comfy WSL setup

These scripts configure an Ubuntu 24.04 WSL2 environment for zsh, coding
agents, ROCm, and ComfyUI on an AMD Radeon RX 9070 XT.

Run the stages in order from the repository root:

```sh
bash comfy/01-base-zsh.sh
bash comfy/02-agents.sh
bash comfy/03-rocm.sh
```

Each stage is safe to rerun after a failure. Later stages check their important
prerequisites and identify which earlier stage to run when one is missing.

## Stages

### 1. Base zsh

Installs system packages, MesloLGS Nerd Fonts, Oh My Zsh, Powerlevel10k, zsh
plugins, fzf, and the shared zsh/tmux configuration. It also makes zsh the
default login shell.

After it finishes, configure Windows Terminal to use `MesloLGS NF`. If the
Powerlevel10k wizard was skipped, run `p10k configure` in an interactive shell.

### 2. Coding agents

Installs OpenAI Codex, Grok Build, and Hermes Agent. It adds these directories
to `~/.zshrc` and to the installer process:

```text
~/.hermes/bin       Hermes-managed uv
~/.hermes/node/bin  Hermes-managed Node and npm
~/.local/bin        Codex and Hermes command launchers
```

If Hermes setup was skipped, run `hermes setup --quick` interactively.

### 3. ROCm and ComfyUI

Installs ROCm 7.2.4 and ROCDXG 1.2.0, verifies the RX 9070 XT (`gfx1201`),
creates the ComfyUI Python environment, installs the validated ROCm PyTorch
wheels, and runs a GPU smoke test.

Before running this stage, install a Windows AMD Adrenalin driver with WSL2
ROCm support, reboot Windows, and run `wsl --update` so `/dev/dxg` is present.

Set `COMFYUI_DIR` to override the default `~/ComfyUI` checkout location:

```sh
COMFYUI_DIR="$HOME/projects/ComfyUI" bash comfy/03-rocm.sh
```

## Run everything

The compatibility wrapper runs all three stages sequentially:

```sh
bash comfy-conf.sh
```

The legacy base-only entry point remains available:

```sh
bash zsh-conf.sh
```

