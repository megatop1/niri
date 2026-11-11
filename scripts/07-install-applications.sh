#!/usr/bin/env bash
set -euo pipefail

echo "=== Desktop application installation ==="

source /etc/os-release

if [[ "${ID}" != "ubuntu" || "${VERSION_ID}" != "24.04" ]]; then
    echo "ERROR: This installer requires Ubuntu 24.04 LTS."
    exit 1
fi

echo "Updating package indexes..."
sudo apt update

echo "Installing desktop applications..."

sudo apt install -y \
    policykit-1-gnome \
    kitty \
    alacritty \
    firefox \
    thunar \
    btop \
    cmus \
    rofi \
    wl-mirror \
    pavucontrol \
    blueman

echo
echo "Desktop applications installed."
