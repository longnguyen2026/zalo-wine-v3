#!/usr/bin/env bash
#
# ==========================================================
# Zalo Wine Installer Bootstrap
# Version : 3.0
# Author  : Long Nguyen
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

banner() {

cat << "EOF"

======================================================
          Zalo Wine Installer v3.0
======================================================

Author : Long Nguyen

Supported Linux:

  ✔ Linux Mint
  ✔ Ubuntu
  ✔ Kubuntu
  ✔ Deepin OS
  ✔ Zorin OS
  ✔ Pop!_OS
  ✔ KDE Neon

======================================================

EOF

}

banner

##########################################
# Check Internet
##########################################

log "Checking Internet..."

if ! ping -c1 github.com >/dev/null 2>&1; then
    error "No Internet connection."
    exit 1
fi

##########################################
# Check curl
##########################################

if ! command -v curl >/dev/null; then

    warn "Installing curl..."

    sudo apt update

    sudo apt install -y curl

fi

##########################################
# Download setup.sh
##########################################

log "Downloading installer..."

curl -fsSL \
"$REPO/setup.sh" \
-o "$TMP_DIR/setup.sh"

chmod +x "$TMP_DIR/setup.sh"

##########################################
# Launch setup
##########################################

exec "$TMP_DIR/setup.sh"
