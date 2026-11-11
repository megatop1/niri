#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OLD_REPO="${HOME}/dotfiles"
CONFIG_DIR="${HOME}/.config"

PACKAGES=(
    niri
    noctalia
    kitty
    alacritty
    rofi
    swayidle
)

BACKUP_DIR=""
DEPLOYMENT_STARTED=false

cleanup() {
    local status=$?

    if [[ "${status}" -ne 0 && "${DEPLOYMENT_STARTED}" == true ]]; then
        echo
        echo "ERROR: Deployment failed. Attempting rollback..."

        cd "${REPO_ROOT}"

        # Remove links created by this deployment.
        stow --delete --target="${HOME}" "${PACKAGES[@]}" || true

        # Restore previously deployed package symlinks.
        if [[ -n "${BACKUP_DIR}" && -d "${BACKUP_DIR}" ]]; then
            for package in "${PACKAGES[@]}"; do
                if [[ -L "${BACKUP_DIR}/${package}" ]]; then
                    if [[ -e "${CONFIG_DIR}/${package}" ||
                          -L "${CONFIG_DIR}/${package}" ]]; then
                        rm -- "${CONFIG_DIR}/${package}"
                    fi

                    mv "${BACKUP_DIR}/${package}" \
                        "${CONFIG_DIR}/${package}"
                fi
            done

            # Restore the obsolete Swaync symlink if backed up.
            if [[ -L "${BACKUP_DIR}/swaync" ]]; then
                if [[ -e "${CONFIG_DIR}/swaync" ||
                      -L "${CONFIG_DIR}/swaync" ]]; then
                    rm -- "${CONFIG_DIR}/swaync"
                fi

                mv "${BACKUP_DIR}/swaync" \
                    "${CONFIG_DIR}/swaync"
            fi
        fi

        echo "Rollback attempted."
    fi

    # Remove the temporary backup directory when empty.
    if [[ -n "${BACKUP_DIR}" && -d "${BACKUP_DIR}" ]]; then
        rmdir "${BACKUP_DIR}" 2>/dev/null || {
            echo "Backup retained at: ${BACKUP_DIR}"
        }
    fi

    exit "${status}"
}

trap cleanup EXIT

echo "=== Dotfiles deployment ==="
echo "Repository: ${REPO_ROOT}"
echo "Target:     ${HOME}"

command -v stow >/dev/null || {
    echo "ERROR: GNU Stow is not installed."
    exit 1
}

[[ -d "${REPO_ROOT}/.git" ]] || {
    echo "ERROR: Repository is not a Git repository."
    exit 1
}

mkdir -p "${CONFIG_DIR}"

cd "${REPO_ROOT}"

echo
echo "=== Verifying packages ==="

for package in "${PACKAGES[@]}"; do
    [[ -d "${REPO_ROOT}/${package}/.config" ]] || {
        echo "ERROR: Missing package: ${package}"
        exit 1
    }

    echo "OK: ${package}"
done

echo
echo "=== Checking existing configuration paths ==="

for package in "${PACKAGES[@]}"; do
    target="${CONFIG_DIR}/${package}"
    expected_old="${OLD_REPO}/${package}/.config/${package}"
    expected_new="${REPO_ROOT}/${package}/.config/${package}"

    if [[ -L "${target}" ]]; then
        resolved="$(readlink -f "${target}")"

        if [[ "${resolved}" != "${expected_old}" &&
              "${resolved}" != "${expected_new}" ]]; then
            echo "ERROR: Unexpected symlink:"
            echo "${target} -> $(readlink "${target}")"
            exit 1
        fi

        echo "Verified symlink: ${package}"

    elif [[ -e "${target}" ]]; then
        echo "ERROR: Existing non-symlink configuration:"
        echo "${target}"
        echo "Move or back it up manually before deployment."
        exit 1
    fi
done

echo
echo "=== Checking obsolete Swaync configuration ==="

if [[ -L "${CONFIG_DIR}/swaync" ]]; then
    swaync_resolved="$(readlink -f "${CONFIG_DIR}/swaync")"
    expected_swaync="${REPO_ROOT}/swaync/.config/swaync"

    if [[ "${swaync_resolved}" != "${expected_swaync}" ]]; then
        echo "ERROR: Unexpected Swaync symlink:"
        echo "${CONFIG_DIR}/swaync -> $(readlink "${CONFIG_DIR}/swaync")"
        exit 1
    fi

    echo "Verified existing Swaync symlink."

elif [[ -e "${CONFIG_DIR}/swaync" ]]; then
    echo "ERROR: Swaync configuration is not a symlink:"
    echo "${CONFIG_DIR}/swaync"
    echo "Leaving it untouched."
    exit 1
fi

echo
echo "=== Stow preflight test ==="

PREFLIGHT_HOME="$(mktemp -d)"

if ! stow \
    --simulate \
    --verbose=1 \
    --target="${PREFLIGHT_HOME}" \
    "${PACKAGES[@]}"; then
    echo "ERROR: Stow preflight failed."
    rm -rf "${PREFLIGHT_HOME}"
    exit 1
fi

rm -rf "${PREFLIGHT_HOME}"

echo
echo "=== Backing up existing symlinks ==="

BACKUP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/niri-stow-backup.XXXXXX")"

for package in "${PACKAGES[@]}"; do
    target="${CONFIG_DIR}/${package}"

    if [[ -L "${target}" ]]; then
        cp -a "${target}" "${BACKUP_DIR}/${package}"
        echo "Backed up: ${package}"
    fi
done

if [[ -L "${CONFIG_DIR}/swaync" ]]; then
    cp -a "${CONFIG_DIR}/swaync" "${BACKUP_DIR}/swaync"
    echo "Backed up obsolete Swaync symlink."
fi

# Enable rollback before modifying any configuration links.
DEPLOYMENT_STARTED=true

echo
echo "=== Removing old configuration symlinks ==="

for package in "${PACKAGES[@]}"; do
    target="${CONFIG_DIR}/${package}"

    if [[ -L "${target}" ]]; then
        rm -- "${target}"
        echo "Removed: ${target}"
    fi
done

if [[ -L "${CONFIG_DIR}/swaync" ]]; then
    rm -- "${CONFIG_DIR}/swaync"
    echo "Removed obsolete Swaync symlink."
fi

echo
echo "=== Deploying packages ==="

cd "${REPO_ROOT}"

stow --target="${HOME}" "${PACKAGES[@]}"

echo
echo "=== Verifying deployed configurations ==="

for package in "${PACKAGES[@]}"; do
    target="${CONFIG_DIR}/${package}"
    expected="${REPO_ROOT}/${package}/.config/${package}"

    if [[ ! -L "${target}" ]]; then
        echo "ERROR: Missing configuration symlink: ${target}"
        exit 1
    fi

    actual="$(readlink -f "${target}")"

    if [[ "${actual}" != "${expected}" ]]; then
        echo "ERROR: Incorrect destination for ${package}:"
        echo "${actual}"
        exit 1
    fi

    echo "OK: ${package} -> ${actual}"
done

if [[ -e "${CONFIG_DIR}/swaync" || -L "${CONFIG_DIR}/swaync" ]]; then
    echo "ERROR: Swaync configuration still exists after deployment."
    exit 1
fi

echo "OK: Swaync is not deployed."

DEPLOYMENT_STARTED=false

echo
echo "Dotfiles deployment complete."

