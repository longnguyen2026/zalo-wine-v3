#!/usr/bin/env bash
#
# ==========================================================
# Zalo Wine Installer Engine
# Version : 3.0
# ==========================================================

set -euo pipefail

REPO="https://raw.githubusercontent.com/longnguyen2026/zalo-wine-v3/main"

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

error() {
    echo -e "${RED}$1${NC}"
}

##########################################
# Check sudo
##########################################

if [[ $EUID -eq 0 ]]; then
    error "Please do NOT run this installer as root."
    exit 1
fi

if ! sudo -v; then
    error "Sudo authentication failed."
    exit 1
fi

##########################################
# Detect Linux Distribution
##########################################

if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect Linux distribution."
    exit 1
fi

source /etc/os-release

DISTRO="$ID"
VERSION="$VERSION_ID"

case "$DISTRO" in

linuxmint)
    DISTRO_NAME="Linux Mint"
    ;;

ubuntu)
    DISTRO_NAME="Ubuntu"
    ;;

deepin)
    DISTRO_NAME="Deepin OS"
    ;;

pop)
    DISTRO_NAME="Pop!_OS"
    ;;

neon)
    DISTRO_NAME="KDE Neon"
    ;;

zorin)
    DISTRO_NAME="Zorin OS"
    ;;

*)
    error "Unsupported Linux Distribution."
    echo
    echo "Detected:"
    echo "ID=$ID"
    echo "VERSION_ID=$VERSION_ID"
    exit 1
    ;;

esac

log "Detected: $DISTRO_NAME $VERSION"

##########################################
# Detect Desktop Environment
##########################################

DESKTOP="${XDG_CURRENT_DESKTOP:-Unknown}"

log "Desktop: $DESKTOP"

##########################################
# Detect CPU
##########################################

ARCH=$(uname -m)

case "$ARCH" in

x86_64)
    ARCH_NAME="64-bit"
    ;;

aarch64)
    ARCH_NAME="ARM64"
    ;;

*)
    error "Unsupported CPU Architecture: $ARCH"
    exit 1
    ;;

esac

log "Architecture: $ARCH_NAME"

##########################################
# Check RAM
##########################################

RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')

if (( RAM_MB < 4096 )); then
    warn "Only ${RAM_MB} MB RAM detected."
fi

##########################################
# Check Internet
##########################################

if ! ping -c1 github.com >/dev/null 2>&1; then
    error "Internet connection required."
    exit 1
fi

##########################################
# Update package cache
##########################################

log "Updating package index..."

sudo apt update

##########################################
# Download main installer
##########################################

log "Downloading installer..."

mkdir -p "$TMP_DIR/assets"

log "Downloading bundled Winetricks..."

curl -fsSL \
"$REPO/assets/winetricks" \
-o "$TMP_DIR/assets/winetricks"

chmod +x "$TMP_DIR/assets/winetricks"

log "Downloading application icon..."

curl -fsSL \
"$REPO/assets/zalo.png" \
-o "$TMP_DIR/assets/zalo.png"

curl -fsSL \
"$REPO/install-zalo-v3.sh" \
-o "$TMP_DIR/install-zalo-v3.sh"

chmod +x "$TMP_DIR/install-zalo-v3.sh"

##########################################
# Start installer
##########################################

exec "$TMP_DIR/install-zalo-v3.sh"
