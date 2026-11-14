#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

SCRIPTS_DIR="${REPO_ROOT}/scripts"
MANIFEST="${REPO_ROOT}/manifests/versions.env"

WALLPAPER_SOURCE="${REPO_ROOT}/default.png"
WALLPAPER_DIR="${HOME}/Pictures/wallpapers"
WALLPAPER_DEST="${WALLPAPER_DIR}/default.png"

LOG_DIR="${HOME}/.local/state/niri-installer/logs"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="${LOG_DIR}/install-${TIMESTAMP}.log"

MODE=""
DEPLOY_WALLPAPER=false

usage() {
    cat <<'EOF'
Niri Desktop Installer

Usage:
  ./install.sh [OPTION]

Options:
  --all        Run the complete installation (00-08).
  --build      Install dependencies and build Niri/Noctalia (00-06).
  --apps       Install desktop applications (07).
  --dotfiles   Deploy configuration files using GNU Stow (08).
  --htb        Install HTB and penetration testing tools (10).
  --help       Display this help message.

Examples:
  ./install.sh --all
  ./install.sh --build
  ./install.sh --apps
  ./install.sh --dotfiles
  ./install.sh --htb 

The installer supports Ubuntu 24.04 LTS and Ubuntu 26.04 LTS.
EOF
}

fail() {
    echo
    echo "ERROR: $*"
    exit 1
}

run_script() {
    local script="$1"
    local description="$2"
    local path="${SCRIPTS_DIR}/${script}"

    if [[ ! -x "${path}" ]]; then
        fail "Script is missing or not executable: ${path}"
    fi

    echo
    echo "============================================================"
    echo "STEP: ${description}"
    echo "SCRIPT: ${script}"
    echo "============================================================"
    echo

    if ! "${path}"; then
        fail "Installation failed during ${description} (${script})."
    fi

    echo
    echo "Completed: ${description}"
}

deploy_wallpaper() {
    if [[ "${DEPLOY_WALLPAPER}" != true ]]; then
        return
    fi

    echo
    echo "============================================================"
    echo "STEP: Default wallpaper deployment"
    echo "============================================================"

    mkdir -p "${WALLPAPER_DIR}"

    install -m 0644 "${WALLPAPER_SOURCE}" "${WALLPAPER_DEST}"

    echo "Wallpaper installed:"
    echo "  Source:      ${WALLPAPER_SOURCE}"
    echo "  Destination: ${WALLPAPER_DEST}"
}

# Parse command-line arguments.
if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

case "$1" in
    --all|--build|--apps|--dotfiles|--htb)
        MODE="$1"
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        usage
        fail "Unknown option: $1"
        ;;
esac

# Verify the operating system.
source "${SCRIPTS_DIR}/lib/platform.sh"
require_supported_ubuntu || fail "Unsupported operating system."


# Verify the repository structure.
if [[ ! -f "${MANIFEST}" ]]; then
    fail "Version manifest is missing: ${MANIFEST}"
fi

for script in \
    00-system-packages.sh \
    01-install-rust.sh \
    02-build-niri.sh \
    03-build-wireplumber.sh \
    04-build-sdbus-cpp.sh \
    05-install-stb-headers.sh \
    06-build-noctalia.sh \
    07-install-applications.sh \
    08-deploy-dotfiles.sh \
    09-install-nerd-fonts.sh
do
    if [[ ! -x "${SCRIPTS_DIR}/${script}" ]]; then
        fail "Required script is missing or not executable: ${script}"
    fi
done

# Select the installation steps.
case "${MODE}" in
    --all)
        DEPLOY_WALLPAPER=true
        STEPS=(
            "00-system-packages.sh|System packages and build dependencies"
            "01-install-rust.sh|Rust toolchain"
            "02-build-niri.sh|Niri"
            "03-build-wireplumber.sh|WirePlumber"
            "04-build-sdbus-cpp.sh|sdbus-c++"
            "05-install-stb-headers.sh|STB headers"
            "06-build-noctalia.sh|Noctalia"
            "07-install-applications.sh|Desktop applications"
            "08-deploy-dotfiles.sh|Dotfiles deployment"
            "09-install-nerd-fonts.sh|Nerd Fonts"
	    "10-install-htb-tools.sh|HTB and penetration testing tools"
        )
        ;;
    --build)
        STEPS=(
            "00-system-packages.sh|System packages and build dependencies"
            "01-install-rust.sh|Rust toolchain"
            "02-build-niri.sh|Niri"
            "03-build-wireplumber.sh|WirePlumber"
            "04-build-sdbus-cpp.sh|sdbus-c++"
            "05-install-stb-headers.sh|STB headers"
            "06-build-noctalia.sh|Noctalia"
        )
        ;;
    --apps)
        STEPS=(
            "07-install-applications.sh|Desktop applications"
            "09-install-nerd-fonts.sh|Nerd Fonts"
        )
        ;;
    --dotfiles)
        DEPLOY_WALLPAPER=true
        STEPS=(
            "08-deploy-dotfiles.sh|Dotfiles deployment"
        )
        ;;
    --htb)
        STEPS=(
            "10-install-htb-tools.sh|HTB and penetration testing tools"
        )
        ;;
esac

# Verify wallpaper source if deployment is selected.
if [[ "${DEPLOY_WALLPAPER}" == true && ! -f "${WALLPAPER_SOURCE}" ]]; then
    fail "Default wallpaper is missing: ${WALLPAPER_SOURCE}"
fi

# Show the planned operation.
echo
echo "============================================================"
echo "NIRI DESKTOP INSTALLER"
echo "============================================================"
echo "Repository: ${REPO_ROOT}"
echo "Ubuntu:     ${VERSION_ID}"
echo "Mode:       ${MODE}"
echo "Steps:      ${#STEPS[@]}"
echo
echo "The following operations will run:"

for step in "${STEPS[@]}"; do
    IFS='|' read -r script description <<< "${step}"
    echo "  - ${description} (${script})"
done

if [[ "${DEPLOY_WALLPAPER}" == true ]]; then
    echo "  - Default wallpaper deployment"
    echo "      ${WALLPAPER_SOURCE}"
    echo "      -> ${WALLPAPER_DEST}"
fi

echo
echo "No installation has started yet."
read -r -p "Continue? [y/N] " answer

case "${answer}" in
    y|Y|yes|YES)
        ;;
    *)
        echo "Installation cancelled."
        exit 0
        ;;
esac

# Authenticate sudo once before starting installation.
echo
echo "============================================================"
echo "SUDO AUTHENTICATION"
echo "============================================================"
echo "Please enter your password. It will be cached for installation."

sudo -v || fail "Sudo authentication failed."

# Keep sudo credentials alive throughout the installation.
while true; do
    sudo -n -v
    sleep 60
    kill -0 "$$" || exit
done 2>/dev/null &

SUDO_KEEPALIVE_PID=$!

cleanup() {
    kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
}

trap cleanup EXIT

# Initialize logging after confirmation.
mkdir -p "${LOG_DIR}"

touch "${LOG_FILE}"

exec > >(tee -a "${LOG_FILE}") 2>&1

START_TIME="$(date +%s)"

echo
echo "Installation started: $(date)"
echo "Log file: ${LOG_FILE}"

# Run the selected steps.
for step in "${STEPS[@]}"; do
    IFS='|' read -r script description <<< "${step}"
    run_script "${script}" "${description}"
done

# Deploy the default wallpaper.
deploy_wallpaper

END_TIME="$(date +%s)"
ELAPSED=$((END_TIME - START_TIME))

echo
echo "============================================================"
echo "INSTALLATION COMPLETED"
echo "============================================================"
echo "Mode:     ${MODE}"
echo "Duration: ${ELAPSED} seconds"
echo "Log:      ${LOG_FILE}"
echo
echo "All selected steps completed successfully."
