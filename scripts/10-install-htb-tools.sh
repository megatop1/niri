#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Niri Rice Setup - HTB / Pentesting Tools
# Installs common Hack The Box and security lab tools.
# ============================================================

SCRIPT_NAME="10-install-htb-tools.sh"

# Re-run as root if necessary.
if [[ "${EUID}" -ne 0 ]]; then
    echo "Elevated privileges required. Requesting sudo..."
    exec sudo -E bash "$0" "$@"
fi

echo
echo "============================================================"
echo " Installing HTB / Pentesting Tools"
echo "============================================================"
echo

# Prevent interactive package configuration.
export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Preconfigure package installation answers.
# ------------------------------------------------------------

echo "Configuring package installation defaults..."

if ! command -v debconf-set-selections >/dev/null 2>&1; then
    apt-get update
    apt-get install -y debconf-utils
fi

# Wireshark:
# Allow non-root users in the wireshark group to capture packets.
echo "wireshark-common wireshark-common/install-setuid boolean true" \
    | debconf-set-selections

# iptables-persistent:
# Automatically save existing IPv4 and IPv6 rules.
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" \
    | debconf-set-selections

echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" \
    | debconf-set-selections

# ------------------------------------------------------------
# Update package lists.
# ------------------------------------------------------------

echo
echo "Updating APT package lists..."

apt-get update

# ------------------------------------------------------------
# Install HTB / pentesting packages.
# ------------------------------------------------------------

PACKAGES=(
    nmap
    gobuster
    socat
    sqlmap
    hashcat
    john
    hydra
    wireshark
    masscan
    nikto
    aircrack-ng
    tree
    net-tools
    curl
    ca-certificates
    whois
    tmux
    ffuf
    libreoffice
    openvpn
    iptables
    iptables-persistent
    python3-venv
    python3-pip
    proxychains4
    bzip2
    smbclient
    htop
    weevely
    wireguard
    wireguard-tools
    tcpdump
    pipx
    python3-full
    python3-dev
    python3-pip
    build-essential
    rustc
    cargo
    libkrb5-dev
    ruby
    ruby-dev
    build-essential
    libreadline-dev
    make
    jq
    python3-netifaces
    golang-go
    postgresql
)

echo
echo "Installing the following packages:"
printf '  - %s\n' "${PACKAGES[@]}"

echo

apt-get install -y "${PACKAGES[@]}"


# ------------------------------------------------------------
# Install Docker CE
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Docker CE"
echo "============================================================"

# Remember the original user who launched the installer.
DOCKER_USER="${SUDO_USER:-}"

# Install Docker repository prerequisites.
apt-get install -y curl ca-certificates gnupg

# Remove conflicting Docker packages from Ubuntu.
apt-get remove -y docker.io docker-doc docker-compose \
    podman-docker containerd runc || true

# Create the APT keyring directory.
install -m 0755 -d /etc/apt/keyrings

# Import Docker's official GPG key.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

# Determine Ubuntu architecture and release.
ARCH="$(dpkg --print-architecture)"
. /etc/os-release
UBUNTU_CODENAME="${VERSION_CODENAME}"

# Add Docker's official Ubuntu repository.
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

# Update package lists.
apt-get update

# Install Docker CE and required plugins.
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    libseccomp2

# Enable and start Docker.
systemctl enable docker --now

# Add the original invoking user to the Docker group.
if [[ -n "${DOCKER_USER}" && "${DOCKER_USER}" != "root" ]]; then
    usermod -aG docker "${DOCKER_USER}"
    echo "Added ${DOCKER_USER} to the docker group."
else
    echo "WARNING: Could not determine the original user."
    echo "Add your user manually with: sudo usermod -aG docker USERNAME"
fi

# Restart Docker.
systemctl restart docker

# Verify Docker installation.
echo
echo "Docker version:"
docker --version

echo
echo "Docker Compose version:"
docker compose version

echo
echo "Docker service status:"
systemctl is-active docker

echo
echo "Docker CE installation complete."
echo "A logout/login is required for new Docker group membership."


# ------------------------------------------------------------
# Configure Wireshark group access
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Configuring Wireshark permissions"
echo "============================================================"

WIRESHARK_USER="${SUDO_USER:-}"

if [[ -n "${WIRESHARK_USER}" && "${WIRESHARK_USER}" != "root" ]]; then
    # Ensure the Wireshark group exists.
    if getent group wireshark >/dev/null 2>&1; then
        usermod -aG wireshark "${WIRESHARK_USER}"
        echo "Added ${WIRESHARK_USER} to the wireshark group."
    else
        echo "WARNING: wireshark group does not exist."
    fi
else
    echo "WARNING: Could not determine the original user."
fi

# Reconfigure Wireshark for non-root capture.
dpkg-reconfigure -f noninteractive wireshark-common

echo
echo "Wireshark permissions configured."
echo "Log out and back in for group membership to take effect."


# ------------------------------------------------------------
# Create /opt/tools workspace
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Configuring /opt/tools workspace"
echo "============================================================"

TOOLS_USER="${SUDO_USER:-}"

if [[ -z "${TOOLS_USER}" || "${TOOLS_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

TOOLS_GROUP="$(id -gn "${TOOLS_USER}")"

# Create the tools directory.
mkdir -p /opt/tools

# Assign ownership to the invoking user and their primary group.
chown -R "${TOOLS_USER}:${TOOLS_GROUP}" /opt/tools

# Give the owner full permissions.
chmod -R u+rwX /opt/tools

# Ensure newly created files and directories inherit the group.
chmod g+s /opt/tools

echo "/opt/tools is ready."
echo "Owner: ${TOOLS_USER}"
echo "Group: ${TOOLS_GROUP}"
echo "Permissions:"
ls -ld /opt/tools


# ------------------------------------------------------------
# Install RSSH, Kerbrute, Responder, and msldap
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Enumeration and Pivoting Tools"
echo "============================================================"

ENUM_DIR="/opt/tools/enum"
PIVOT_DIR="/opt/tools/pivot"

mkdir -p "${ENUM_DIR}" "${PIVOT_DIR}"

if [[ -z "${TOOLS_USER:-}" || "${TOOLS_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

# Detect architecture for release downloads.
case "$(dpkg --print-architecture)" in
    amd64)
        TOOL_ARCH="amd64"
        ;;
    arm64)
        TOOL_ARCH="arm64"
        ;;
    *)
        echo "ERROR: Unsupported architecture."
        exit 1
        ;;
esac


# ------------------------------------------------------------
# RSSH - Reverse SSH
# Location: /opt/tools/pivot/reverse_ssh
# ------------------------------------------------------------

echo
echo "[*] Installing RSSH..."

RSSH_DIR="${PIVOT_DIR}/reverse_ssh"

RSSH_TAG="$(
    curl -fsSL \
        https://api.github.com/repos/NHAS/reverse_ssh/releases/latest \
        | jq -er '.tag_name'
)"

if [[ -d "${RSSH_DIR}/.git" ]]; then
    if [[ -n "$(git -C "${RSSH_DIR}" status --porcelain)" ]]; then
        echo "ERROR: RSSH repository has local changes."
        echo "Please commit or back up those changes before updating."
        exit 1
    fi

    git -C "${RSSH_DIR}" fetch --tags
    git -C "${RSSH_DIR}" checkout "${RSSH_TAG}"
else
    git clone --depth 1 --branch "${RSSH_TAG}" \
        https://github.com/NHAS/reverse_ssh.git \
        "${RSSH_DIR}"
fi

# Build the RSSH server and client.
# Go automatically downloads the required toolchain if needed.
GOTOOLCHAIN=auto make -C "${RSSH_DIR}" server client

ln -sfn "${RSSH_DIR}/bin/server" /usr/local/bin/rssh-server
ln -sfn "${RSSH_DIR}/bin/client" /usr/local/bin/rssh-client

echo "[OK] RSSH installed (${RSSH_TAG})."


# ------------------------------------------------------------
# Kerbrute
# Location: /opt/tools/enum/kerbrute
# ------------------------------------------------------------

echo
echo "[*] Installing Kerbrute..."

KERBRUTE_DIR="${ENUM_DIR}/kerbrute"

mkdir -p "${KERBRUTE_DIR}"

KERBRUTE_RELEASE="$(
    curl -fsSL \
        https://api.github.com/repos/ropnop/kerbrute/releases/latest
)"

KERBRUTE_TAG="$(jq -er '.tag_name' <<< "${KERBRUTE_RELEASE}")"

KERBRUTE_URL="$(
    jq -r --arg arch "${TOOL_ARCH}" '
        .assets[]
        | select(.name == ("kerbrute_linux_" + $arch))
        | .browser_download_url
    ' <<< "${KERBRUTE_RELEASE}" | head -n 1
)"

if [[ -n "${KERBRUTE_URL}" ]]; then
    curl -fL --retry 3 "${KERBRUTE_URL}" \
        -o "${KERBRUTE_DIR}/kerbrute"
else
    echo "[--] No prebuilt Linux ${TOOL_ARCH} asset found."
    echo "[*] Building Kerbrute from its latest release source..."

    KERBRUTE_SOURCE="${KERBRUTE_DIR}/source"

    if [[ -d "${KERBRUTE_SOURCE}/.git" ]]; then
        git -C "${KERBRUTE_SOURCE}" fetch --tags
        git -C "${KERBRUTE_SOURCE}" checkout "${KERBRUTE_TAG}"
    else
        git clone --depth 1 --branch "${KERBRUTE_TAG}" \
            https://github.com/ropnop/kerbrute.git \
            "${KERBRUTE_SOURCE}"
    fi

    GOTOOLCHAIN=auto go build \
        -o "${KERBRUTE_DIR}/kerbrute" \
        "${KERBRUTE_SOURCE}"
fi

chmod 0755 "${KERBRUTE_DIR}/kerbrute"
ln -sfn "${KERBRUTE_DIR}/kerbrute" /usr/local/bin/kerbrute

echo "[OK] Kerbrute installed (${KERBRUTE_TAG})."


# ------------------------------------------------------------
# Responder
# Location: /opt/tools/enum/Responder
# ------------------------------------------------------------

echo
echo "[*] Installing Responder..."

RESPONDER_DIR="${ENUM_DIR}/Responder"

if [[ -d "${RESPONDER_DIR}/.git" ]]; then
    git -C "${RESPONDER_DIR}" pull --ff-only
else
    git clone https://github.com/lgandx/Responder.git \
        "${RESPONDER_DIR}"
fi

# Use an isolated Python environment.
python3 -m venv --system-site-packages \
    "${RESPONDER_DIR}/venv"

"${RESPONDER_DIR}/venv/bin/pip" install --upgrade pip
"${RESPONDER_DIR}/venv/bin/pip" install \
    -r "${RESPONDER_DIR}/requirements.txt"

# Provide a convenient command.
cat > /usr/local/bin/responder <<EOF
#!/usr/bin/env bash
exec "${RESPONDER_DIR}/venv/bin/python" \
    "${RESPONDER_DIR}/Responder.py" "\$@"
EOF

chmod 0755 /usr/local/bin/responder

echo "[OK] Responder installed."


# ------------------------------------------------------------
# msldap
# Location: /opt/tools/enum/msldap
# ------------------------------------------------------------

echo
echo "[*] Installing msldap..."

MSLDAP_DIR="${ENUM_DIR}/msldap"

if [[ -d "${MSLDAP_DIR}/.git" ]]; then
    git -C "${MSLDAP_DIR}" pull --ff-only
else
    git clone https://github.com/skelsec/msldap.git \
        "${MSLDAP_DIR}"
fi

# Install into its own Python environment.
python3 -m venv "${MSLDAP_DIR}/venv"

"${MSLDAP_DIR}/venv/bin/pip" install --upgrade pip
"${MSLDAP_DIR}/venv/bin/pip" install "${MSLDAP_DIR}"

ln -sfn "${MSLDAP_DIR}/venv/bin/msldap" \
    /usr/local/bin/msldap

ln -sfn "${MSLDAP_DIR}/venv/bin/msldap-bloodhound" \
    /usr/local/bin/msldap-bloodhound

echo "[OK] msldap installed."


# ------------------------------------------------------------
# Set ownership of the new tool directories
# ------------------------------------------------------------

chown -R "${TOOLS_USER}:${TOOLS_GROUP}" \
    "${ENUM_DIR}" \
    "${PIVOT_DIR}"

echo
echo "[OK] Enumeration and pivoting tools installed."


# ------------------------------------------------------------
# Install SearchSploit / Exploit-DB
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing SearchSploit"
echo "============================================================"

EXPLOITDB_DIR="/opt/tools/exploitdb"
EXPLOITDB_USER="${TOOLS_USER:-}"

if [[ -z "${EXPLOITDB_USER}" || "${EXPLOITDB_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

# Clone or update the official Exploit-DB repository.
if [[ -d "${EXPLOITDB_DIR}/.git" ]]; then
    echo "Exploit-DB already exists. Updating..."
    runuser -u "${EXPLOITDB_USER}" -- \
        git -C "${EXPLOITDB_DIR}" pull --ff-only
else
    echo "Cloning Exploit-DB..."
    runuser -u "${EXPLOITDB_USER}" -- \
        git clone https://gitlab.com/exploit-database/exploitdb.git \
        "${EXPLOITDB_DIR}"
fi

# Provide the standard Exploit-DB path expected by SearchSploit.
ln -sfn "${EXPLOITDB_DIR}" /opt/exploit-database

# Make SearchSploit available system-wide.
ln -sfn "${EXPLOITDB_DIR}/searchsploit" /usr/local/bin/searchsploit

# Install the SearchSploit configuration for the invoking user.
if [[ ! -f "/home/${EXPLOITDB_USER}/.searchsploit_rc" ]]; then
    runuser -u "${EXPLOITDB_USER}" -- \
        cp "${EXPLOITDB_DIR}/.searchsploit_rc" \
        "/home/${EXPLOITDB_USER}/.searchsploit_rc"
fi

chown "${EXPLOITDB_USER}:$(id -gn "${EXPLOITDB_USER}")" \
    "/home/${EXPLOITDB_USER}/.searchsploit_rc"

echo "SearchSploit installation complete."


# ------------------------------------------------------------
# Install VSCodium
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing VSCodium"
echo "============================================================"

# Import the official VSCodium signing key.
install -d -m 0755 /usr/share/keyrings

curl -fsSL https://repo.vscodium.dev/vscodium.gpg \
    | gpg --dearmor --yes \
        -o /usr/share/keyrings/vscodium.gpg

chmod a+r /usr/share/keyrings/vscodium.gpg

# Add the official repository.
curl -fsSL \
    -o /etc/apt/sources.list.d/vscodium.sources \
    https://repo.vscodium.dev/vscodium.sources

# Install VSCodium.
apt-get update
apt-get install -y codium

echo "VSCodium installation complete."
echo "Command: codium"


# ------------------------------------------------------------
# Install Impacket using pipx
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Impacket"
echo "============================================================"

IMPACKET_USER="${SUDO_USER:-}"

if [[ -z "${IMPACKET_USER}" || "${IMPACKET_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

# Configure pipx for the invoking user.
runuser -u "${IMPACKET_USER}" -- pipx ensurepath

# Install Impacket in an isolated Python environment.
runuser -u "${IMPACKET_USER}" -- pipx install impacket

echo "Impacket installation complete."
echo "Installed using pipx for ${IMPACKET_USER}."


# ------------------------------------------------------------
# Install NetExec
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing NetExec"
echo "============================================================"

NETEXEC_USER="${SUDO_USER:-}"

if [[ -z "${NETEXEC_USER}" || "${NETEXEC_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

# Install NetExec using pipx.
# --force allows the installer to replace an existing installation.
runuser -u "${NETEXEC_USER}" -- \
    pipx install --force \
    git+https://github.com/Pennyw0rth/NetExec

echo "NetExec installation complete."
echo "Commands available: nxc, NetExec, netexec, nxcdb"

# ------------------------------------------------------------
# Install Certipy (AD CS)
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Certipy"
echo "============================================================"

CERTIPY_USER="${SUDO_USER:-}"

if [[ -z "${CERTIPY_USER}" || "${CERTIPY_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

# Install Certipy in an isolated Python environment.
runuser -u "${CERTIPY_USER}" -- \
    pipx install --force certipy-ad

echo "Certipy installation complete."
echo "Command: certipy"


# ------------------------------------------------------------
# Install Coercer
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Coercer"
echo "============================================================"

COERCER_USER="${SUDO_USER:-}"

if [[ -z "${COERCER_USER}" || "${COERCER_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

# Install Coercer in an isolated Python environment.
runuser -u "${COERCER_USER}" -- \
    pipx install --force coercer

echo "Coercer installation complete."
echo "Command: coercer"

# ------------------------------------------------------------
# Install Evil-WinRM
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Evil-WinRM"
echo "============================================================"

EVILWINRM_USER="${SUDO_USER:-}"

if [[ -z "${EVILWINRM_USER}" || "${EVILWINRM_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

# Install Evil-WinRM for the invoking user.
runuser -u "${EVILWINRM_USER}" -- \
    gem install --user-install evil-winrm

echo "Evil-WinRM installation complete."
echo "Command: evil-winrm"
echo "A new login shell may be required for PATH changes."


# ------------------------------------------------------------
# Configure RubyGems user executable PATH
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Configuring RubyGems PATH"
echo "============================================================"

RUBY_USER="${SUDO_USER:-}"

if [[ -z "${RUBY_USER}" || "${RUBY_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

RUBY_GEM_BIN="$(runuser -u "${RUBY_USER}" -- \
    ruby -e 'print Gem.user_dir')/bin"

RUBY_BASHRC="/home/${RUBY_USER}/.bashrc"

if ! grep -Fq "${RUBY_GEM_BIN}" "${RUBY_BASHRC}"; then
    cat >> "${RUBY_BASHRC}" <<EOF

# >>> Niri RubyGems PATH >>>
export PATH="${RUBY_GEM_BIN}:\$PATH"
# <<< Niri RubyGems PATH <<<
EOF
fi

echo "RubyGems executable directory added to ${RUBY_BASHRC}"
echo "${RUBY_GEM_BIN}"


# ------------------------------------------------------------
# Install Sliver, Ligolo-ng, and Chisel from GitHub Releases
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing C2 and Pivoting Tools"
echo "============================================================"

GITHUB_USER="${SUDO_USER:-}"

if [[ -z "${GITHUB_USER}" || "${GITHUB_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

GITHUB_GROUP="$(id -gn "${GITHUB_USER}")"

# Determine system architecture.
case "$(dpkg --print-architecture)" in
    amd64)
        TOOL_ARCH="amd64"
        ;;
    arm64)
        TOOL_ARCH="arm64"
        ;;
    *)
        echo "ERROR: Unsupported architecture."
        exit 1
        ;;
esac

# Create the tools directory structure.
for dir in \
    /opt/tools/enum \
    /opt/tools/c2/sliver \
    /opt/tools/pivot/ligolo-ng \
    /opt/tools/pivot/chisel; do

    install -d -o "${GITHUB_USER}" -g "${GITHUB_GROUP}" "${dir}"
done

# Temporary download directory.
DOWNLOAD_DIR="$(mktemp -d)"
trap 'rm -rf "${DOWNLOAD_DIR}"' EXIT

# Retrieve the latest stable GitHub release.
get_github_release() {
    local repo="$1"

    curl -fsSL --retry 3 \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: Niri-Rice-Installer" \
        "https://api.github.com/repos/${repo}/releases/latest"
}

# Download a named release asset and verify its SHA-256 digest
# when GitHub provides one.
download_github_asset() {
    local release_json="$1"
    local asset_name="$2"
    local destination="$3"

    local asset_url
    local expected_digest
    local actual_digest

    asset_url="$(jq -er --arg name "${asset_name}" \
        '.assets[] | select(.name == $name) | .browser_download_url' \
        <<< "${release_json}")" || {
        echo "ERROR: Release asset not found: ${asset_name}"
        return 1
    }

    echo "Downloading ${asset_name}..."

    curl -fL --retry 3 \
        -o "${destination}" \
        "${asset_url}"

    expected_digest="$(jq -r --arg name "${asset_name}" \
        '.assets[] | select(.name == $name) | .digest // empty' \
        <<< "${release_json}")"

    if [[ "${expected_digest}" == sha256:* ]]; then
        expected_digest="${expected_digest#sha256:}"
        actual_digest="$(sha256sum "${destination}" | awk '{print $1}')"

        if [[ "${actual_digest}" != "${expected_digest}" ]]; then
            echo "ERROR: SHA-256 verification failed: ${asset_name}"
            return 1
        fi

        echo "SHA-256 verification passed."
    else
        echo "WARNING: No SHA-256 digest provided by GitHub."
    fi
}


# ------------------------------------------------------------
# Sliver - C2 Framework
# ------------------------------------------------------------

echo
echo "=== Installing Sliver ==="

SLIVER_RELEASE="$(get_github_release BishopFox/sliver)"

SLIVER_SERVER="sliver-server_linux-${TOOL_ARCH}"
SLIVER_CLIENT="sliver-client_linux-${TOOL_ARCH}"

download_github_asset \
    "${SLIVER_RELEASE}" \
    "${SLIVER_SERVER}" \
    "${DOWNLOAD_DIR}/sliver-server"

download_github_asset \
    "${SLIVER_RELEASE}" \
    "${SLIVER_CLIENT}" \
    "${DOWNLOAD_DIR}/sliver-client"

install -o "${GITHUB_USER}" -g "${GITHUB_GROUP}" \
    -m 0755 "${DOWNLOAD_DIR}/sliver-server" \
    /opt/tools/c2/sliver/sliver-server

install -o "${GITHUB_USER}" -g "${GITHUB_GROUP}" \
    -m 0755 "${DOWNLOAD_DIR}/sliver-client" \
    /opt/tools/c2/sliver/sliver-client

SLIVER_VERSION="$(jq -r '.tag_name' <<< "${SLIVER_RELEASE}")"

echo "Sliver ${SLIVER_VERSION} installed."


# ------------------------------------------------------------
# Ligolo-ng - Pivoting
# ------------------------------------------------------------

echo
echo "=== Installing Ligolo-ng ==="

LIGOLO_RELEASE="$(get_github_release nicocha30/ligolo-ng)"

LIGOLO_VERSION="$(jq -r '.tag_name' <<< "${LIGOLO_RELEASE}")"
LIGOLO_VERSION="${LIGOLO_VERSION#v}"

LIGOLO_AGENT="ligolo-ng_agent_${LIGOLO_VERSION}_linux_${TOOL_ARCH}.tar.gz"
LIGOLO_PROXY="ligolo-ng_proxy_${LIGOLO_VERSION}_linux_${TOOL_ARCH}.tar.gz"

download_github_asset \
    "${LIGOLO_RELEASE}" \
    "${LIGOLO_AGENT}" \
    "${DOWNLOAD_DIR}/ligolo-agent.tar.gz"

download_github_asset \
    "${LIGOLO_RELEASE}" \
    "${LIGOLO_PROXY}" \
    "${DOWNLOAD_DIR}/ligolo-proxy.tar.gz"

mkdir -p "${DOWNLOAD_DIR}/ligolo-agent" \
         "${DOWNLOAD_DIR}/ligolo-proxy"

tar -xzf "${DOWNLOAD_DIR}/ligolo-agent.tar.gz" \
    -C "${DOWNLOAD_DIR}/ligolo-agent"

tar -xzf "${DOWNLOAD_DIR}/ligolo-proxy.tar.gz" \
    -C "${DOWNLOAD_DIR}/ligolo-proxy"

install -o "${GITHUB_USER}" -g "${GITHUB_GROUP}" \
    -m 0755 "${DOWNLOAD_DIR}/ligolo-agent/agent" \
    /opt/tools/pivot/ligolo-ng/agent

install -o "${GITHUB_USER}" -g "${GITHUB_GROUP}" \
    -m 0755 "${DOWNLOAD_DIR}/ligolo-proxy/proxy" \
    /opt/tools/pivot/ligolo-ng/proxy

echo "Ligolo-ng v${LIGOLO_VERSION} installed."


# ------------------------------------------------------------
# Chisel - Pivoting
# ------------------------------------------------------------

echo
echo "=== Installing Chisel ==="

CHISEL_RELEASE="$(get_github_release jpillora/chisel)"

CHISEL_VERSION="$(jq -r '.tag_name' <<< "${CHISEL_RELEASE}")"
CHISEL_VERSION="${CHISEL_VERSION#v}"

CHISEL_ASSET="chisel_${CHISEL_VERSION}_linux_${TOOL_ARCH}.gz"

download_github_asset \
    "${CHISEL_RELEASE}" \
    "${CHISEL_ASSET}" \
    "${DOWNLOAD_DIR}/chisel.gz"

gzip -dc "${DOWNLOAD_DIR}/chisel.gz" \
    > "${DOWNLOAD_DIR}/chisel"

install -o "${GITHUB_USER}" -g "${GITHUB_GROUP}" \
    -m 0755 "${DOWNLOAD_DIR}/chisel" \
    /opt/tools/pivot/chisel/chisel

echo "Chisel v${CHISEL_VERSION} installed."


# ------------------------------------------------------------
# Finalize tool directory permissions
# ------------------------------------------------------------

chown -R "${GITHUB_USER}:${GITHUB_GROUP}" \
    /opt/tools/enum \
    /opt/tools/c2 \
    /opt/tools/pivot

echo
echo "C2 and pivoting tools installed successfully."

echo
echo "Installed directories:"
find /opt/tools/{enum,c2,pivot} -maxdepth 2 -type f -printf '%p\n'


# ------------------------------------------------------------
# Install Burp Suite Community Edition
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Burp Suite Community Edition"
echo "============================================================"

BURP_USER="${SUDO_USER:-}"

if [[ -z "${BURP_USER}" || "${BURP_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

BURP_HOME="$(getent passwd "${BURP_USER}" | cut -d: -f6)"

if [[ -z "${BURP_HOME}" || ! -d "${BURP_HOME}" ]]; then
    echo "ERROR: Could not determine the user's home directory."
    exit 1
fi

# Pin to a stable release with a dedicated Community installer.
BURP_VERSION="2026.3.3"

BURP_INSTALL_DIR="${BURP_HOME}/BurpSuiteCommunity"

BURP_INSTALLER="${DOWNLOAD_DIR}/burpsuite_community_linux_v2026_3_3.sh"

BURP_URL="https://portswigger.net/burp/releases/startdownload?product=community&type=linux&version=${BURP_VERSION}"

BURP_SHA256="48b1e3010b0d3a5c7fa22a3dacac4b7052c60191619f924b597b0ba9c02b091b"

# Download the official Community Edition installer.
echo "Downloading Burp Suite Community ${BURP_VERSION}..."

curl -fL --retry 3 \
    "${BURP_URL}" \
    -o "${BURP_INSTALLER}"

# Verify the installer checksum.
echo "${BURP_SHA256}  ${BURP_INSTALLER}" | sha256sum -c -

# Stage the installer in the original user's home directory.
BURP_INSTALLER_USER="${BURP_HOME}/burpsuite_community_linux_v${BURP_VERSION//./_}.sh"

install \
    -o "${BURP_USER}" \
    -g "$(id -gn "${BURP_USER}")" \
    -m 0700 \
    "${BURP_INSTALLER}" \
    "${BURP_INSTALLER_USER}"

# Create the installation directory.
install -d \
    -o "${BURP_USER}" \
    -g "$(id -gn "${BURP_USER}")" \
    "${BURP_INSTALL_DIR}"

# Run the installer unattended as the original user.
echo
echo "Installing Burp Suite Community Edition..."
echo "Installation directory: ${BURP_INSTALL_DIR}"

runuser -u "${BURP_USER}" -- \
    bash "${BURP_INSTALLER_USER}" \
    -q \
    -dir "${BURP_INSTALL_DIR}"

rm -f "${BURP_INSTALLER_USER}"

# Verify installation.
if [[ -d "${BURP_INSTALL_DIR}" ]]; then
    echo
    echo "Burp Suite Community Edition ${BURP_VERSION} installed."
    echo "Location: ${BURP_INSTALL_DIR}"
else
    echo "ERROR: Burp Suite installation directory not found."
    exit 1
fi

# ------------------------------------------------------------
# Install PowerShell 7 (Official Microsoft Repository)
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing PowerShell 7"
echo "============================================================"

# Verify Ubuntu.
source /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    echo "ERROR: PowerShell installer currently expects Ubuntu."
    exit 1
fi

# Download Microsoft's repository package.
POWERSHELL_REPO_DEB="${DOWNLOAD_DIR}/packages-microsoft-prod.deb"

curl -fL --retry 3 \
    "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" \
    -o "${POWERSHELL_REPO_DEB}"

# Register Microsoft's package repository.
dpkg -i "${POWERSHELL_REPO_DEB}"

# Refresh package lists and install PowerShell.
apt-get update
apt-get install -y powershell

# Verify installation.
if command -v pwsh >/dev/null 2>&1; then
    echo
    echo "PowerShell installed successfully:"
    pwsh --version
else
    echo "ERROR: PowerShell installation failed."
    exit 1
fi


# ------------------------------------------------------------
# Install Obsidian (Official Debian Package)
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Obsidian"
echo "============================================================"

OBSIDIAN_USER="${SUDO_USER:-}"

if [[ -z "${OBSIDIAN_USER}" || "${OBSIDIAN_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

OBSIDIAN_ARCH="$(dpkg --print-architecture)"

if [[ "${OBSIDIAN_ARCH}" != "amd64" ]]; then
    echo "ERROR: Official Obsidian DEB installer requires amd64."
    exit 1
fi

# Retrieve the latest official Obsidian release.
OBSIDIAN_RELEASE="$(curl -fsSL \
    https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest)"

OBSIDIAN_DEB_URL="$(jq -r \
    '.assets[] | select(.name | test("^obsidian_.*_amd64\\.deb$")) | .browser_download_url' \
    <<< "${OBSIDIAN_RELEASE}" | head -n1)"

if [[ -z "${OBSIDIAN_DEB_URL}" || "${OBSIDIAN_DEB_URL}" == "null" ]]; then
    echo "ERROR: Could not find the official Obsidian DEB package."
    exit 1
fi

OBSIDIAN_DEB="${DOWNLOAD_DIR}/obsidian.deb"

echo "Downloading latest Obsidian release..."

curl -fL --retry 3 \
    "${OBSIDIAN_DEB_URL}" \
    -o "${OBSIDIAN_DEB}"

# Install Obsidian.
apt-get install -y "${OBSIDIAN_DEB}"

# Verify installation.
if command -v obsidian >/dev/null 2>&1; then
    echo
    echo "Obsidian installed successfully."
    obsidian --version 2>/dev/null || true
else
    echo "ERROR: Obsidian installation failed."
    exit 1
fi


# ------------------------------------------------------------
# Configure Firefox Extensions (All Profiles)
# Firefox Snap / System-Wide Policies
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Configuring Firefox Extensions"
echo "============================================================"

FIREFOX_POLICY_DIR="/etc/firefox/policies"
FIREFOX_POLICY_FILE="${FIREFOX_POLICY_DIR}/policies.json"

install -d -m 0755 "${FIREFOX_POLICY_DIR}"

# Preserve existing policies if present.
if [[ -f "${FIREFOX_POLICY_FILE}" ]]; then
    echo "Existing Firefox policies detected."

    FIREFOX_POLICY_TMP="${DOWNLOAD_DIR}/firefox-policies.json"

    jq '
        .policies.ExtensionSettings = (
            (.policies.ExtensionSettings // {}) + {
                "noscript@noscript.net": {
                    "installation_mode": "normal_installed"
                },
                "uBlock0@raymondhill.net": {
                    "installation_mode": "normal_installed"
                },
                "foxyproxy@eric.h.jung": {
                    "installation_mode": "normal_installed"
                }
            }
        )
    ' "${FIREFOX_POLICY_FILE}" > "${FIREFOX_POLICY_TMP}"

    install -m 0644 "${FIREFOX_POLICY_TMP}" "${FIREFOX_POLICY_FILE}"
else
    cat > "${FIREFOX_POLICY_FILE}" <<'EOF'
{
    "policies": {
        "ExtensionSettings": {
            "noscript@noscript.net": {
                "installation_mode": "normal_installed"
            },
            "uBlock0@raymondhill.net": {
                "installation_mode": "normal_installed"
            },
            "foxyproxy@eric.h.jung": {
                "installation_mode": "normal_installed"
            }
        }
    }
}
EOF

    chmod 0644 "${FIREFOX_POLICY_FILE}"
fi

# Validate policy JSON.
jq empty "${FIREFOX_POLICY_FILE}"

echo
echo "Firefox extensions configured:"
echo "  [OK] NoScript"
echo "  [OK] uBlock Origin"
echo "  [OK] FoxyProxy Standard"
echo
echo "Restart Firefox to apply the policies."

# ------------------------------------------------------------
# Install Metasploit Framework (Official Rapid7)
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installing Metasploit Framework"
echo "============================================================"

METASPLOIT_USER="${SUDO_USER:-}"

if [[ -z "${METASPLOIT_USER}" || "${METASPLOIT_USER}" == "root" ]]; then
    echo "ERROR: Could not determine the original user."
    exit 1
fi

# Download the official Rapid7 installer.
METASPLOIT_INSTALLER="${DOWNLOAD_DIR}/msfinstall"

curl -fsSL --retry 3 \
    https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
    -o "${METASPLOIT_INSTALLER}"

chmod 0755 "${METASPLOIT_INSTALLER}"

# Install Metasploit Framework.
"${METASPLOIT_INSTALLER}"

# Enable PostgreSQL for the Metasploit database.
systemctl enable postgresql --now

echo
echo "Metasploit Framework installation complete."
echo "Launch with: msfconsole"

# ------------------------------------------------------------
# Installation summary.
# ------------------------------------------------------------

echo
echo "============================================================"
echo " HTB / Pentesting Tools Installation Complete"
echo "============================================================"
echo

echo "Installed tool versions (where available):"

echo "Installed tool verification:"

# Resolve the original user's pipx executable directory.
PIPX_BIN="/home/${SUDO_USER}/.local/bin"

# Resolve the original user's RubyGems executable directory.
RUBY_GEM_BIN="$(runuser -u "${SUDO_USER}" -- \
    ruby -e 'print Gem.user_dir')/bin"

# Verify commands using their actual installation locations.
declare -A TOOL_PATHS=(
    [searchsploit]="/usr/local/bin/searchsploit"
    [codium]="/usr/bin/codium"
    [impacket-secretsdump]="${PIPX_BIN}/secretsdump.py"
    [nxc]="${PIPX_BIN}/nxc"
    [nxcdb]="${PIPX_BIN}/nxcdb"
    [certipy]="${PIPX_BIN}/certipy"
    [coercer]="${PIPX_BIN}/coercer"
    [evil-winrm]="${RUBY_GEM_BIN}/evil-winrm"
    [rssh-server]="/usr/local/bin/rssh-server"
    [rssh-client]="/usr/local/bin/rssh-client"
    [kerbrute]="/usr/local/bin/kerbrute"
    [responder]="/usr/local/bin/responder"
    [msldap]="/usr/local/bin/msldap"
    [pwsh]="/usr/bin/pwsh"
    [obsidian]="/usr/bin/obsidian"
)

for tool in "${!TOOL_PATHS[@]}"; do
    if [[ -x "${TOOL_PATHS[$tool]}" ]]; then
        printf "  [OK] %s\n" "$tool"
    else
        printf "  [--] %s (not found)\n" "$tool"
    fi
done

echo
echo "Wireshark capture policy: non-root capture enabled for wireshark group."
echo "iptables-persistent: automatic IPv4/IPv6 rule saving enabled."
echo
echo "Installation finished successfully."
