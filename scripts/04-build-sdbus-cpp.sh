#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${REPO_ROOT}/manifests/versions.env"

BUILD_ROOT="${HOME}/build"
SOURCE_DIR="${BUILD_ROOT}/sdbus-cpp-2"
BUILD_DIR="${SOURCE_DIR}/build"

echo "=== sdbus-c++ build ==="
echo "Repository: ${SDBUS_CPP_REPO}"
echo "Tag:        ${SDBUS_CPP_TAG}"
echo "Commit:     ${SDBUS_CPP_COMMIT}"

mkdir -p "${BUILD_ROOT}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
    if [[ -e "${SOURCE_DIR}" ]]; then
        echo "ERROR: ${SOURCE_DIR} exists but is not a Git repository."
        exit 1
    fi

    git clone "${SDBUS_CPP_REPO}" "${SOURCE_DIR}"
fi

cd "${SOURCE_DIR}"

ORIGIN="$(git remote get-url origin)"

if [[ "${ORIGIN}" != "${SDBUS_CPP_REPO}" ]]; then
    echo "ERROR: Unexpected sdbus-c++ repository origin:"
    echo "${ORIGIN}"
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: sdbus-c++ source directory has uncommitted changes."
    exit 1
fi

echo "Fetching pinned sdbus-c++ commit and tag..."

git fetch origin "${SDBUS_CPP_COMMIT}"

git fetch origin \
    "refs/tags/${SDBUS_CPP_TAG}:refs/tags/${SDBUS_CPP_TAG}"

TAG_COMMIT="$(git rev-parse "${SDBUS_CPP_TAG}^{commit}")"

if [[ "${TAG_COMMIT}" != "${SDBUS_CPP_COMMIT}" ]]; then
    echo "ERROR: sdbus-c++ tag and pinned commit do not match."
    echo "Tag commit:      ${TAG_COMMIT}"
    echo "Expected commit: ${SDBUS_CPP_COMMIT}"
    exit 1
fi

CURRENT_COMMIT="$(git rev-parse HEAD)"

if [[ "${CURRENT_COMMIT}" != "${SDBUS_CPP_COMMIT}" ]]; then
    echo "Checking out pinned sdbus-c++ commit..."
    git checkout --detach "${SDBUS_CPP_COMMIT}"
else
    echo "Already on the pinned sdbus-c++ commit."
fi

ACTUAL_COMMIT="$(git rev-parse HEAD)"

if [[ "${ACTUAL_COMMIT}" != "${SDBUS_CPP_COMMIT}" ]]; then
    echo "ERROR: sdbus-c++ commit verification failed."
    exit 1
fi

echo
echo "Configuring sdbus-c++..."

cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_SHARED_LIBS=ON \
    -DSDBUSCPP_BUILD_LIBSYSTEMD=OFF \
    -DSDBUSCPP_BUILD_TESTS=OFF \
    -DSDBUSCPP_BUILD_CODEGEN=OFF \
    -DSDBUSCPP_BUILD_EXAMPLES=OFF \
    -DSDBUSCPP_BUILD_DOCS=OFF

echo
echo "Building sdbus-c++..."

cmake --build "${BUILD_DIR}" -j2

echo
echo "Installing sdbus-c++..."

sudo cmake --install "${BUILD_DIR}"
sudo ldconfig

echo
echo "=== Verification ==="

INSTALLED_VERSION="$(
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}" \
        pkg-config --modversion sdbus-c++
)"

echo "Installed version: ${INSTALLED_VERSION}"

if [[ "${INSTALLED_VERSION}" != "${SDBUS_CPP_VERSION}" ]]; then
    echo "ERROR: Expected sdbus-c++ ${SDBUS_CPP_VERSION}, found ${INSTALLED_VERSION}."
    exit 1
fi

echo "sdbus-c++ installation complete."
