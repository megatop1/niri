#!/usr/bin/env bash

# Shared operating-system detection for the Niri installer.
# Supported releases: Ubuntu 24.04 LTS and Ubuntu 26.04 LTS.

require_supported_ubuntu() {
    if [[ ! -r /etc/os-release ]]; then
        echo "ERROR: Cannot identify operating system."
        return 1
    fi

    source /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        echo "ERROR: This installer requires Ubuntu."
        echo "Detected distribution: ${PRETTY_NAME:-unknown}"
        return 1
    fi

    case "${VERSION_ID:-}" in
        24.04|26.04)
            UBUNTU_VERSION="${VERSION_ID}"
            export UBUNTU_VERSION
            ;;
        *)
            echo "ERROR: Unsupported Ubuntu release: ${VERSION_ID:-unknown}"
            echo "Supported releases: Ubuntu 24.04 LTS and Ubuntu 26.04 LTS."
            return 1
            ;;
    esac

    echo "Detected supported platform: ${PRETTY_NAME}"
}
