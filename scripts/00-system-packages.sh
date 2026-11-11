#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f /etc/os-release ]]; then
    echo "Cannot identify operating system."
    exit 1
fi

source /etc/os-release

if [[ "${ID}" != "ubuntu" || "${VERSION_ID}" != "24.04" ]]; then
    echo "This installer requires Ubuntu 24.04 LTS."
    exit 1
fi

echo "Updating Ubuntu package indexes..."
sudo apt update

echo "Installing desktop integration and build dependencies..."

sudo apt install -y \
    git \
    curl \
    wget \
    build-essential \
    cmake \
    meson \
    ninja-build \
    pkg-config \
    stow \
    gcc-14 \
    g++-14 \
    clang \
    libudev-dev \
    libgbm-dev \
    libsodium-dev \
    libxkbcommon-dev \
    libegl1-mesa-dev \
    libwayland-dev \
    wayland-protocols \
    libinput-dev \
    libdbus-1-dev \
    libsecret-1-dev \
    libsystemd-dev \
    libseat-dev \
    libpipewire-0.3-dev \
    libpango1.0-dev \
    libdisplay-info-dev \
    libglib2.0-dev \
    liblua5.4-dev \
    pipewire \
    wireplumber \
    wl-clipboard \
    cliphist \
    swayidle \
    xwayland \
    xdg-utils \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    gnome-keyring \
    fonts-font-awesome \
    fonts-ubuntu \
    fonts-noto \
    brightnessctl \
    playerctl \
    libegl-dev \
    libgles-dev \
    libfreetype-dev \
    libfontconfig-dev \
    libcairo2-dev \
    libharfbuzz-dev \
    libpolkit-agent-1-dev \
    libpolkit-gobject-1-dev \
    libcurl4-openssl-dev \
    libqalculate-dev \
    libxml2-dev \
    libmd4c-dev \
    libtomlplusplus-dev \
    libical-dev \
    nlohmann-json3-dev \
    libpam0g-dev \
    libwebp-dev \
    libjxl-dev \
    libsndfile1-dev \
    librsvg2-dev \
    libstb-dev \
    libsdbus-c++-dev \
    libwireplumber-0.5-dev

echo
echo "Base packages installed."
echo "Ubuntu version: ${VERSION_ID}"

echo "GCC:"
gcc-14 --version

echo "G++:"
g++-14 --version
