#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${REPO_ROOT}/manifests/versions.env"

BUILD_ROOT="${HOME}/build"
SOURCE_DIR="${BUILD_ROOT}/wireplumber-0.5"
BUILD_DIR="${SOURCE_DIR}/build"

export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

echo "=== WirePlumber build ==="
echo "Repository: ${WIREPLUMBER_REPO}"
echo "Commit:     ${WIREPLUMBER_COMMIT}"
echo "Version:    ${WIREPLUMBER_VERSION}"

# Create the build root.
mkdir -p "${BUILD_ROOT}"

# Clone WirePlumber if the source directory does not exist.
if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
    if [[ -e "${SOURCE_DIR}" ]]; then
        echo "ERROR: ${SOURCE_DIR} exists but is not a Git repository."
        exit 1
    fi

    git clone "${WIREPLUMBER_REPO}" "${SOURCE_DIR}"
fi

cd "${SOURCE_DIR}"

# Verify the repository origin.
ORIGIN="$(git remote get-url origin)"

if [[ "${ORIGIN}" != "${WIREPLUMBER_REPO}" ]]; then
    echo "ERROR: Unexpected WirePlumber repository origin:"
    echo "${ORIGIN}"
    exit 1
fi

# Never overwrite local source modifications.
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: WirePlumber source directory has uncommitted changes."
    echo "Review or clean the working tree before continuing."
    git status --short
    exit 1
fi

# Fetch the pinned WirePlumber commit.
echo "Fetching pinned WirePlumber commit..."
git fetch origin "${WIREPLUMBER_COMMIT}"

CURRENT_COMMIT="$(git rev-parse HEAD)"

if [[ "${CURRENT_COMMIT}" != "${WIREPLUMBER_COMMIT}" ]]; then
    echo "Checking out pinned WirePlumber commit..."
    git checkout --detach "${WIREPLUMBER_COMMIT}"
else
    echo "Already on the pinned WirePlumber commit."
fi

# Verify the checked-out commit.
ACTUAL_COMMIT="$(git rev-parse HEAD)"

if [[ "${ACTUAL_COMMIT}" != "${WIREPLUMBER_COMMIT}" ]]; then
    echo "ERROR: WirePlumber commit verification failed."
    exit 1
fi

# Configure WirePlumber.
echo
echo "=== Configuring WirePlumber ==="

if [[ -f "${BUILD_DIR}/meson-private/coredata.dat" ]]; then
    meson setup --reconfigure "${BUILD_DIR}" \
        --prefix=/usr/local \
        --libdir=lib \
        --buildtype=release \
        -Dsystemd=disabled \
        -Ddoc=disabled \
        -Dintrospection=disabled \
        -Dsystem-lua=true
else
    meson setup "${BUILD_DIR}" \
        --prefix=/usr/local \
        --libdir=lib \
        --buildtype=release \
        -Dsystemd=disabled \
        -Ddoc=disabled \
        -Dintrospection=disabled \
        -Dsystem-lua=true
fi

# Build WirePlumber.
echo
echo "=== Building WirePlumber ==="

meson compile -C "${BUILD_DIR}"

# Install WirePlumber.
echo
echo "=== Installing WirePlumber ==="

sudo meson install -C "${BUILD_DIR}"
sudo ldconfig

# Verify the locally installed version.
echo
echo "=== Verification ==="

INSTALLED_VERSION="$(pkg-config --modversion wireplumber-0.5)"

echo "Expected version:  ${WIREPLUMBER_VERSION}"
echo "Installed version: ${INSTALLED_VERSION}"

if [[ "${INSTALLED_VERSION}" != "${WIREPLUMBER_VERSION}" ]]; then
    echo "ERROR: Expected WirePlumber ${WIREPLUMBER_VERSION}, found ${INSTALLED_VERSION}."
    exit 1
fi

echo
echo "WirePlumber installation complete."

