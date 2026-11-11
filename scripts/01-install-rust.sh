#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${REPO_ROOT}/manifests/versions.env"

RUSTUP_BIN="${HOME}/.cargo/bin/rustup"

echo "=== Rust toolchain installation ==="
echo "Required version: ${RUST_VERSION}"

if [[ ! -x "${RUSTUP_BIN}" ]]; then
    echo "Rustup is not installed."
    echo "Installing using the official Rustup installer..."

    INSTALLER="$(mktemp)"
    trap 'rm -f "${INSTALLER}"' EXIT

    curl --proto '=https' --tlsv1.2 -sSf \
        https://sh.rustup.rs \
        -o "${INSTALLER}"

    sh "${INSTALLER}" -y --profile default
else
    echo "Existing Rustup installation found."
fi

export PATH="${HOME}/.cargo/bin:${PATH}"

echo
echo "Installing Rust ${RUST_VERSION}..."

rustup toolchain install "${RUST_VERSION}" \
    --profile default

rustup default "${RUST_VERSION}"

echo
echo "=== Verification ==="

rustup show active-toolchain
rustc --version
cargo --version

if [[ "$(rustc --version)" != "rustc ${RUST_VERSION} "* ]]; then
    echo "ERROR: Unexpected Rust compiler version."
    exit 1
fi

if [[ "$(cargo --version)" != "cargo ${RUST_VERSION} "* ]]; then
    echo "ERROR: Unexpected Cargo version."
    exit 1
fi

echo
echo "Rust ${RUST_VERSION} installed successfully."

