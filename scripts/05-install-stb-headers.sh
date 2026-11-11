#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${REPO_ROOT}/manifests/versions.env"

BUILD_ROOT="${HOME}/build"
SOURCE_DIR="${BUILD_ROOT}/stb-headers"

echo "=== STB header installation ==="
echo "Repository: ${STB_REPO}"
echo "Commit:     ${STB_COMMIT}"

mkdir -p "${BUILD_ROOT}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
    if [[ -e "${SOURCE_DIR}" ]]; then
        echo "ERROR: ${SOURCE_DIR} exists but is not a Git repository."
        exit 1
    fi

    git clone "${STB_REPO}" "${SOURCE_DIR}"
fi

cd "${SOURCE_DIR}"

ORIGIN="$(git remote get-url origin)"

if [[ "${ORIGIN}" != "${STB_REPO}" ]]; then
    echo "ERROR: Unexpected STB repository origin:"
    echo "${ORIGIN}"
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: STB source directory has uncommitted changes."
    exit 1
fi

echo "Fetching pinned STB commit..."
git fetch origin "${STB_COMMIT}"
git checkout --detach "${STB_COMMIT}"

ACTUAL_COMMIT="$(git rev-parse HEAD)"

if [[ "${ACTUAL_COMMIT}" != "${STB_COMMIT}" ]]; then
    echo "ERROR: STB commit verification failed."
    exit 1
fi

# Verify both source headers exist.
for header in \
    deprecated/stb_image_resize2.h \
    stb_image_write.h
do
    if [[ ! -f "${SOURCE_DIR}/${header}" ]]; then
        echo "ERROR: Missing STB header: ${header}"
        exit 1
    fi
done

echo
echo "Installing STB headers..."

sudo install -Dm644 \
    "${SOURCE_DIR}/deprecated/stb_image_resize2.h" \
    /usr/local/include/stb/stb_image_resize2.h

sudo install -Dm644 \
    "${SOURCE_DIR}/stb_image_write.h" \
    /usr/local/include/stb/stb_image_write.h


echo
echo "=== Verification ==="

for header in \
    stb_image_resize2.h \
    stb_image_write.h
do
    SOURCE_HEADER="${SOURCE_DIR}/${header}"

    if [[ "${header}" == "stb_image_resize2.h" ]]; then
        SOURCE_HEADER="${SOURCE_DIR}/deprecated/${header}"
    fi

    INSTALLED_HEADER="/usr/local/include/stb/${header}"

    if ! sudo cmp -s "${SOURCE_HEADER}" "${INSTALLED_HEADER}"; then
        echo "ERROR: Installed header does not match source:"
        echo "${header}"
        exit 1
    fi

    echo "OK: ${INSTALLED_HEADER}"
done

echo
echo "STB headers installed and verified successfully."
