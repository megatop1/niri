#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/platform.sh"
require_supported_ubuntu


echo "Updating Ubuntu package indexes..."
sudo apt update

echo "Installing eza repository prerequisites..."
sudo apt install -y gpg wget

echo "Adding the official eza APT repository..."

sudo mkdir -p /etc/apt/keyrings

wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg

echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null

sudo chmod 644 /etc/apt/keyrings/gierens.gpg
sudo chmod 644 /etc/apt/sources.list.d/gierens.list

sudo apt update

echo "Installing desktop integration and build dependencies..."

sudo apt install -y \
    git \
    vim \
    neovim \
    curl \
    wget \
    build-essential \
    cmake \
    meson \
    ninja-build \
    pkg-config \
    xclip \
    eza \
    stow \
    fzf \
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
    libsdbus-c++-dev

echo
echo "=== Installing Starship ==="

if command -v starship >/dev/null 2>&1; then
    echo "Starship is already installed."
    starship --version
else
    echo "Installing Starship using the official installer..."

    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes

    if ! command -v starship >/dev/null 2>&1; then
        echo "ERROR: Starship installation failed or binary is not in PATH."
        exit 1
    fi

    echo "Starship installed successfully."
    starship --version
fi

echo
echo "=== Configuring eza aliases ==="

BASHRC="${HOME}/.bashrc"

if ! grep -qF '# >>> Niri eza aliases >>>' "${BASHRC}"; then
    cat >> "${BASHRC}" <<'EOF'

# >>> Niri eza aliases >>>
alias ls='eza --icons --color=always'
alias ll='eza -lah --icons --color=always'
alias la='eza -a --icons --color=always'
alias l='eza -lah --icons --color=always'
alias lt='eza --tree --icons'
# <<< Niri eza aliases <<<
EOF

    echo "eza aliases added to ${BASHRC}"
else
    echo "eza aliases already configured. Skipping."
fi

echo
echo "=== Configuring eza theme environment ==="

EZA_COLOR_MARKER="# >>> Niri eza color environment >>>"

if ! grep -qF "${EZA_COLOR_MARKER}" "${BASHRC}"; then
    cat >> "${BASHRC}" <<'EOF'

# >>> Niri eza color environment >>>
# Let eza use its own theme instead of GNU dircolors.
unset LS_COLORS
# <<< Niri eza color environment <<<
EOF

    echo "eza color environment configured in ${BASHRC}"
else
    echo "eza color environment already configured. Skipping."
fi

echo
echo "Base packages installed."
echo "Ubuntu version: ${VERSION_ID}"

echo
echo "GCC:"
gcc-14 --version

echo
echo "G++:"
g++-14 --version

echo
echo "Starship:"
starship --version

echo
echo "fzf:"
fzf --version
