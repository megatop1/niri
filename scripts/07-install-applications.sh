#!/usr/bin/env bash
set -euo pipefail

echo "=== Desktop application installation ==="

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/platform.sh"
require_supported_ubuntu


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
