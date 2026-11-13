#!/usr/bin/env bash
set -euo pipefail

FONT_NAME="JetBrainsMono Nerd Font"
FONT_DIR="${HOME}/.local/share/fonts/JetBrainsMono"
DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"

echo "=== Nerd Font installation ==="

for cmd in curl tar fc-match fc-cache; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: ${cmd}"
        exit 1
    fi
done

# Skip downloading if Fontconfig already resolves the requested family.
CURRENT_MATCH="$(fc-match -f '%{family}' "${FONT_NAME}")"

if [[ "${CURRENT_MATCH}" == *"${FONT_NAME}"* ]]; then
    echo "${FONT_NAME} is already installed."
    echo "Skipping download."
    exit 0
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

echo "Downloading ${FONT_NAME}..."

curl --fail --location --silent --show-error \
    "${DOWNLOAD_URL}" \
    --output "${TEMP_DIR}/JetBrainsMono.tar.xz"

echo "Extracting fonts..."

mkdir -p "${TEMP_DIR}/extracted"

tar -xf "${TEMP_DIR}/JetBrainsMono.tar.xz" \
    -C "${TEMP_DIR}/extracted"

mapfile -d '' FONT_FILES < <(
    find "${TEMP_DIR}/extracted" -type f \
        \( -iname '*.ttf' -o -iname '*.otf' \) \
        -print0
)

if [[ "${#FONT_FILES[@]}" -eq 0 ]]; then
    echo "ERROR: No TTF or OTF font files found in archive."
    exit 1
fi

mkdir -p "${FONT_DIR}"

echo "Installing ${#FONT_FILES[@]} font files..."

for font in "${FONT_FILES[@]}"; do
    install -m 644 "${font}" "${FONT_DIR}/"
done

echo "Refreshing font cache..."
fc-cache -f "${FONT_DIR}"

echo
echo "=== Font verification ==="

MATCH="$(fc-match -f '%{family}' "${FONT_NAME}")"

if [[ "${MATCH}" != *"${FONT_NAME}"* ]]; then
    echo "ERROR: ${FONT_NAME} could not be verified."
    echo "Fontconfig returned: ${MATCH}"
    exit 1
fi

echo "Verified: ${MATCH}"
echo "${FONT_NAME} installed successfully."
