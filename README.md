# wsl-conf
Some nice configs for Linux and WSL.

Don't forget to set:
```
git config --global user.name <name>
git config --global user.email <email>
```

The setup script installs MesloLGS Nerd Fonts for the current Linux user. On WSL,
configure Windows Terminal to use MesloLGS NF after running it.

The staged zsh, coding-agent, ROCm, and ComfyUI setup is documented in
[comfy/README.md](comfy/README.md).

On WSL use the following to work with KeyPassXC:
```
git config --global core.sshCommand "ssh.exe"
```

[NerdFonts source](https://github.com/romkatv/dotfiles-public/tree/ca64c0b2114c86980388c712e92b74ed737e3443/.local/share/fonts/NerdFonts)
