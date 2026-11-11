#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${REPO_ROOT}/manifests/versions.env"

BUILD_ROOT="${HOME}/build"
SOURCE_DIR="${BUILD_ROOT}/noctalia-shell"
BUILD_DIR="${SOURCE_DIR}/build-gcc14"
PATCH_FILE="${REPO_ROOT}/patches/noctalia/ubuntu-24.04-wayland.patch"

export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

echo "=== Noctalia build ==="
echo "Repository: ${NOCTALIA_REPO}"
echo "Commit:     ${NOCTALIA_COMMIT}"
echo "Compiler:   GCC ${GCC_VERSION}"

# Verify required compilers.
if ! command -v "gcc-${GCC_VERSION}" >/dev/null 2>&1 ||
   ! command -v "g++-${GCC_VERSION}" >/dev/null 2>&1; then
    echo "ERROR: GCC/G++ ${GCC_VERSION} is not installed."
    exit 1
fi

# Verify the compatibility patch.
if [[ ! -f "${PATCH_FILE}" ]]; then
    echo "ERROR: Noctalia compatibility patch is missing:"
    echo "${PATCH_FILE}"
    exit 1
fi

mkdir -p "${BUILD_ROOT}"

# Clone Noctalia if necessary.
if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
    if [[ -e "${SOURCE_DIR}" ]]; then
        echo "ERROR: ${SOURCE_DIR} exists but is not a Git repository."
        exit 1
    fi

    git clone "${NOCTALIA_REPO}" "${SOURCE_DIR}"
fi

cd "${SOURCE_DIR}"

ORIGIN="$(git remote get-url origin)"

if [[ "${ORIGIN}" != "${NOCTALIA_REPO}" ]]; then
    echo "ERROR: Unexpected Noctalia repository origin:"
    echo "${ORIGIN}"
    exit 1
fi

# Fetch and check out the pinned source.
# Fetch the pinned source.
git fetch origin "${NOCTALIA_COMMIT}"

CURRENT_COMMIT="$(git rev-parse HEAD)"

if [[ "${CURRENT_COMMIT}" != "${NOCTALIA_COMMIT}" ]]; then
    # Never switch commits with local modifications present.
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "ERROR: Noctalia source has local changes."
        echo "Review or clean the source tree before changing commits."
        git status --short
        exit 1
    fi

    echo "Checking out pinned Noctalia commit..."
    git checkout --detach "${NOCTALIA_COMMIT}"
else
    echo "Already on the pinned Noctalia commit."
fi

ACTUAL_COMMIT="$(git rev-parse HEAD)"

if [[ "${ACTUAL_COMMIT}" != "${NOCTALIA_COMMIT}" ]]; then
    echo "ERROR: Noctalia commit verification failed."
    exit 1
fi

# Determine whether the compatibility patch is already applied.
if git apply --reverse --check "${PATCH_FILE}" >/dev/null 2>&1; then
    echo "Compatibility patch is already applied."

    # Only the three expected patched files may be modified.
    EXPECTED_FILES=$'src/shell/wayland/clipboard_globals.cpp\nsrc/shell/wayland/virtual_keyboard_service.cpp\nsrc/shell/wayland/virtual_keyboard_service.h'
    ACTUAL_FILES="$(git diff --name-only | sort)"
    EXPECTED_SORTED="$(printf '%s\n' "${EXPECTED_FILES}" | sort)"

    if [[ "${ACTUAL_FILES}" != "${EXPECTED_SORTED}" ]] ||
       ! git diff --cached --quiet ||
       [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        echo "ERROR: Unexpected changes in the Noctalia source tree."
        git status --short
        exit 1
    fi
else
    # Do not overwrite unrelated local changes.
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "ERROR: Noctalia source tree has unexpected local changes."
        git status --short
        exit 1
    fi

    echo "Applying Ubuntu 24.04 compatibility patch..."

    git apply --check "${PATCH_FILE}"
    git apply "${PATCH_FILE}"
fi

echo
echo "=== Compiler versions ==="
gcc-"${GCC_VERSION}" --version | head -1
g++-"${GCC_VERSION}" --version | head -1

echo
echo "=== Configuring Noctalia ==="

if [[ -f "${BUILD_DIR}/meson-private/coredata.dat" ]]; then
    CXX="g++-${GCC_VERSION}" CC="gcc-${GCC_VERSION}" \
        meson setup --reconfigure "${BUILD_DIR}" \
            --prefix=/usr/local \
            --libdir=lib/x86_64-linux-gnu \
            --buildtype=release
else
    CXX="g++-${GCC_VERSION}" CC="gcc-${GCC_VERSION}" \
        meson setup "${BUILD_DIR}" \
            --prefix=/usr/local \
            --libdir=lib/x86_64-linux-gnu \
            --buildtype=release
fi

echo
echo "=== Building Noctalia ==="

meson compile -C "${BUILD_DIR}" -j 2

echo
echo "=== Installing Noctalia ==="

sudo meson install -C "${BUILD_DIR}"
sudo ldconfig

echo
echo "=== Verification ==="

NOCTALIA_BIN="/usr/local/bin/noctalia"

if [[ ! -x "${NOCTALIA_BIN}" ]]; then
    echo "ERROR: Noctalia executable not found:"
    echo "${NOCTALIA_BIN}"
    exit 1
fi

echo "Installed executable: ${NOCTALIA_BIN}"

"${NOCTALIA_BIN}" --version

echo
echo "Noctalia installation complete."
