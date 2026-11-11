#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${REPO_ROOT}/manifests/versions.env"

BUILD_ROOT="${HOME}/build"
NIRI_DIR="${BUILD_ROOT}/niri"

export PATH="${HOME}/.cargo/bin:${PATH}"

echo "=== Niri build ==="
echo "Repository: ${NIRI_REPO}"
echo "Commit:     ${NIRI_COMMIT}"
echo "Rust:       ${RUST_VERSION}"

# Verify the Rust toolchain.
if ! command -v rustup >/dev/null 2>&1; then
    echo "ERROR: Rustup is not installed."
    echo "Run 01-install-rust.sh first."
    exit 1
fi

if [[ "$(rustc --version)" != "rustc ${RUST_VERSION} "* ]]; then
    echo "ERROR: Expected Rust ${RUST_VERSION}."
    rustc --version
    exit 1
fi

mkdir -p "${BUILD_ROOT}"

# Clone Niri if the source directory does not exist.
if [[ ! -d "${NIRI_DIR}/.git" ]]; then
    if [[ -e "${NIRI_DIR}" ]]; then
        echo "ERROR: ${NIRI_DIR} exists but is not a Git repository."
        exit 1
    fi

    git clone "${NIRI_REPO}" "${NIRI_DIR}"
fi

cd "${NIRI_DIR}"

# Verify the repository origin.
ORIGIN="$(git remote get-url origin)"

if [[ "${ORIGIN}" != "${NIRI_REPO}" ]]; then
    echo "ERROR: Unexpected Niri repository origin:"
    echo "${ORIGIN}"
    exit 1
fi

# Avoid overwriting local source modifications.
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: Niri source directory has uncommitted changes."
    echo "Please review or clean the working tree before continuing."
    exit 1
fi

# Fetch the pinned Niri commit.
echo "Fetching pinned Niri commit..."
git fetch origin "${NIRI_COMMIT}"

CURRENT_COMMIT="$(git rev-parse HEAD)"

if [[ "${CURRENT_COMMIT}" != "${NIRI_COMMIT}" ]]; then
    echo "Checking out pinned Niri commit..."
    git checkout --detach "${NIRI_COMMIT}"
else
    echo "Already on the pinned Niri commit."
fi

ACTUAL_COMMIT="$(git rev-parse HEAD)"

if [[ "${ACTUAL_COMMIT}" != "${NIRI_COMMIT}" ]]; then
    echo "ERROR: Niri commit verification failed."
    exit 1
fi

# Verify the lockfile exists.
if [[ ! -f Cargo.lock ]]; then
    echo "ERROR: Cargo.lock is missing."
    exit 1
fi

# Build using the pinned Rust toolchain.
echo
echo "Building Niri..."

rustup run "${RUST_VERSION}" cargo build --release --locked

NIRI_BINARY="${NIRI_DIR}/target/release/niri"

if [[ ! -x "${NIRI_BINARY}" ]]; then
    echo "ERROR: Niri release binary was not produced."
    exit 1
fi

# Install Niri.
echo
echo "Installing Niri binary and session resources..."

sudo install -Dm755 \
    "${NIRI_BINARY}" \
    /usr/local/bin/niri

sudo install -Dm755 \
    resources/niri-session \
    /usr/local/bin/niri-session

sudo install -Dm644 \
    resources/niri.desktop \
    /usr/share/wayland-sessions/niri.desktop

sudo install -Dm644 \
    resources/niri-portals.conf \
    /usr/share/xdg-desktop-portal/niri-portals.conf

sudo install -Dm644 \
    resources/niri.service \
    /etc/systemd/user/niri.service

sudo install -Dm644 \
    resources/niri-shutdown.target \
    /etc/systemd/user/niri-shutdown.target

sudo systemctl daemon-reload

echo
echo "=== Verification ==="

NIRI_INSTALLED="/usr/local/bin/niri"

if [[ ! -x "${NIRI_INSTALLED}" ]]; then
    echo "ERROR: Niri executable was not installed:"
    echo "${NIRI_INSTALLED}"
    exit 1
fi

echo "Installed binary: ${NIRI_INSTALLED}"
"${NIRI_INSTALLED}" --version

echo
echo "Niri installation complete."
