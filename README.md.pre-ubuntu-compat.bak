# Niri Desktop — Ubuntu 24.04

A reproducible Niri Wayland desktop environment for **Ubuntu 24.04 LTS**, built from pinned upstream source revisions and configured with Noctalia, Rosé Pine theming, and GNU Stow-managed dotfiles.

This repository contains the installation scripts, version manifest, compatibility patches, and application configurations needed to build and deploy the desktop environment.

## Features

- **Niri:** Scrollable-tiling Wayland compositor.
- **Noctalia:** Desktop shell, application launcher, control center, notifications, wallpaper management, session menu, and screenshots.
- **Rosé Pine:** Consistent desktop and application theme.
- **Rofi:** Display layout and clipboard utilities.
- **Swayidle:** Idle management.
- **Kitty / Alacritty:** Terminal emulators.
- **GNU Stow:** Configuration deployment with backup and rollback safeguards.
- **Pinned builds:** Source repositories and commits recorded in a central manifest.

## Supported platform

| Component | Requirement |
|---|---|
| Operating system | Ubuntu 24.04 LTS |
| Architecture | x86_64 |
| Compositor | Niri |
| Desktop shell | Noctalia |
| Compiler | GCC / G++ 14 |
| Rust | Version specified in `manifests/versions.env` |
| Configuration deployment | GNU Stow |

The installation scripts explicitly check the Ubuntu version before proceeding.

## Installation

Clone the repository:

```bash
git clone git@github.com:megatop1/niri.git ~/niri
cd ~/niri
```

The installer supports four modes.

### Complete installation

```bash
./install.sh --all
```

Runs all installation stages in order:

1. System dependencies
2. Rust toolchain
3. Niri build and installation
4. WirePlumber build and installation
5. sdbus-c++ build and installation
6. STB header installation
7. Noctalia build and installation
8. Desktop applications
9. Dotfile deployment

### Build environment and desktop

```bash
./install.sh --build
```

Runs stages 00–06. Installs dependencies and builds Niri and Noctalia.

### Desktop applications

```bash
./install.sh --apps
```

Runs stage 07 to install the additional desktop applications.

### Configuration deployment

```bash
./install.sh --dotfiles
```

Runs stage 08 to deploy the six supported GNU Stow packages.

The installer displays its execution plan and requires confirmation before making changes.

Display help:

```bash
./install.sh --help
```

**Important:** The installer uses `sudo` for system package installation and system-wide builds. Review the scripts before running them.

## Repository structure

```text
niri/
├── alacritty/                 # Alacritty configuration
├── btop/                      # System monitor
├── cava/                      # Audio visualizer
├── docs/                      # Installation and troubleshooting guides (planned)
├── easyeffects/               # Audio effects
├── fastfetch/                 # System information
├── gtk/                       # GTK theming
├── install.sh                 # Installation orchestrator
├── kitty/                     # Kitty terminal configuration
├── lazygit/                   # Git TUI configuration
├── manifests/
│   └── versions.env           # Pinned versions and commits
├── niri/                      # Niri configuration
├── noctalia/                  # Noctalia configuration
├── nvim/                      # Neovim configuration
├── nvim-backup/               # Previous Neovim configuration
├── ohmyposh/                  # Oh My Posh configuration
├── patches/
│   └── noctalia/              # Ubuntu compatibility patch
├── qt6ct/                     # Qt6 theming
├── rofi/                      # Rofi configuration and scripts
├── scripts/
│   ├── 00-system-packages.sh
│   ├── 01-install-rust.sh
│   ├── 02-build-niri.sh
│   ├── 03-build-wireplumber.sh
│   ├── 04-build-sdbus-cpp.sh
│   ├── 05-install-stb-headers.sh
    ├── 06-build-noctalia.sh
    ├── 07-install-applications.sh
    └── 08-deploy-dotfiles.sh
├── swayidle/                  # Idle management
├── swaync/                    # Optional/legacy notification config
├── tmux/                      # Terminal multiplexer
├── waybar/                    # Optional alternative status bar
├── yazi/                      # Terminal file manager
├── zathura/                   # PDF viewer configuration
└── zsh/                       # Zsh configuration
