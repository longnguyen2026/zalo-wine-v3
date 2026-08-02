#!/usr/bin/env bash
#
# ==========================================================
# Zalo Wine Installer
# Version : 3.0
# Author  : Long Nguyen
# ==========================================================

set -euo pipefail
###########################################################################
# Script Directory
###########################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_VERSION="3.0"

PREFIX="$HOME/.wine-zalo"

WORKDIR="$HOME/.local/share/zalo"

DESKTOP_FILE="$HOME/.local/share/applications/zalo.desktop"

ICON_DIR="$HOME/.local/share/icons"

ICON_FILE="$ICON_DIR/zalo.png"

TMP_DIR="$(mktemp -d)"

ZALO_URL="https://res-download-pc-te-vnso-pt-2.zadn.vn/win/ZaloSetup.exe"

ZALO_SETUP="$TMP_DIR/ZaloSetup.exe"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

###########################################################################
# Functions
###########################################################################

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

title() {

echo

echo -e "${BLUE}====================================================${NC}"
echo -e "${CYAN}$1${NC}"
echo -e "${BLUE}====================================================${NC}"

}

success() {

echo -e "${GREEN}✔ $1${NC}"

}

###########################################################################
# Banner
###########################################################################

clear

cat << "EOF"

=========================================================
              ZALO WINE INSTALLER
                    Version 3.0
=========================================================

Author : Long Nguyen

Supported Distributions

  ✔ Linux Mint
  ✔ Ubuntu
  ✔ Kubuntu
  ✔ Deepin OS
  ✔ Zorin OS
  ✔ Pop!_OS
  ✔ KDE Neon

Wine Prefix :

  ~/.wine-zalo

=========================================================

EOF

###########################################################################
# Detect Distro Again (for information)
###########################################################################

source /etc/os-release

DISTRO="$ID"
VERSION="$VERSION_ID"

log "Detected Linux : ${PRETTY_NAME}"

###########################################################################
# Detect Desktop
###########################################################################

DESKTOP="${XDG_CURRENT_DESKTOP:-Unknown}"

log "Desktop : $DESKTOP"

###########################################################################
# Detect CPU
###########################################################################

ARCH=$(uname -m)

log "Architecture : $ARCH"

###########################################################################
# Check Existing Prefix
###########################################################################

if [[ -d "$PREFIX" ]]; then

    warn "Existing Wine prefix found."

fi

###########################################################################
# Create Working Directory
###########################################################################

mkdir -p "$WORKDIR"

mkdir -p "$ICON_DIR"

###########################################################################
# Ready
###########################################################################

success "Environment initialized."

echo

###########################################################################
#
# P3.2 - Install Dependencies
###########################################################################
#
# Purpose :
#   Install required packages and dependencies.
#
###########################################################################

echo

title "Installing Dependencies"

###########################################################################
# Update Package Database
###########################################################################

log "Updating package database..."

if ! sudo apt update; then
    error "APT repository error."
    error "Please fix your APT sources before continuing."
    exit 1
fi

###########################################################################
# Detect FUSE Package
###########################################################################

if apt-cache show libfuse2t64 >/dev/null 2>&1; then
    FUSE_PACKAGE="libfuse2t64"
else
    FUSE_PACKAGE="libfuse2"
fi

###########################################################################
# Required Packages
###########################################################################

PACKAGES=(
    curl
    wget
    unzip
    cabextract
    winbind
    zenity
    p7zip-full
    xdg-utils
    desktop-file-utils
    "$FUSE_PACKAGE"
)

###########################################################################
# Install Packages
###########################################################################

for PKG in "${PACKAGES[@]}"; do

    if dpkg -s "$PKG" >/dev/null 2>&1; then

        success "$PKG already installed."

    else

        log "Installing $PKG..."

        sudo apt install -y "$PKG"

    fi

done

###########################################################################
# Install Fonts
###########################################################################

echo

title "Installing Fonts"

FONTS=(
    fonts-liberation
    fonts-wqy-zenhei
    fonts-wqy-microhei
    ttf-mscorefonts-installer
)

for FONT in "${FONTS[@]}"; do

    if dpkg -s "$FONT" >/dev/null 2>&1; then

        success "$FONT already installed."

    else

        log "Installing $FONT..."

        sudo apt install -y "$FONT" || \
        warn "$FONT is unavailable on this distribution."

    fi

done

###########################################################################
# Install Winetricks
###########################################################################

echo

title "Installing Winetricks"

if command -v winetricks >/dev/null 2>&1; then

    success "Winetricks already installed."

else

    log "Installing Winetricks from APT..."

    if sudo apt install -y winetricks; then

        success "Winetricks installed from APT."

    else

        warn "APT package unavailable."

        log "Downloading Winetricks from official GitHub..."

        mkdir -p "$HOME/.local/bin"

        curl -fsSL \
            https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
            -o "$HOME/.local/bin/winetricks"

        chmod +x "$HOME/.local/bin/winetricks"

        export PATH="$HOME/.local/bin:$PATH"

        success "Winetricks installed from GitHub."

    fi

fi

###########################################################################
# Verify Commands
###########################################################################

echo

title "Verifying Dependencies"

COMMANDS=(
    curl
    wget
    unzip
    cabextract
    winetricks
)

FAILED=0

for CMD in "${COMMANDS[@]}"; do

    if command -v "$CMD" >/dev/null 2>&1; then

        success "$CMD OK"

    else

        error "$CMD Missing"

        FAILED=1

    fi

done

###########################################################################
# Finish
###########################################################################

if [[ $FAILED -eq 0 ]]; then

    echo

    success "All dependencies installed successfully."

else

    echo

    error "Some dependencies could not be installed."

    exit 1

fi

sleep 2


###########################################################################
# P3.3 Install Wine
###########################################################################

echo

title "Installing Wine"

###########################################################################
# Check Existing Wine
###########################################################################




###########################################################################
# Install Wine
###########################################################################

if [[ "${SKIP_WINE_INSTALL:-0}" != "1" ]]; then

    log "Preparing Wine installation..."

    #######################################################################
    # Enable 32-bit Architecture
    #######################################################################

    if ! dpkg --print-foreign-architectures | grep -qx "i386"; then

        log "Adding i386 architecture..."

        sudo dpkg --add-architecture i386

    else

        success "i386 architecture already enabled."

    fi

    #######################################################################
    # Update
    #######################################################################

    if ! sudo apt update; then
        error "APT repository error."
        error "Please fix your APT sources before continuing."
        exit 1
    fi
    #######################################################################
    # Install Wine
    #######################################################################
    log "Installing Wine..."
    
    if [[ "$ID" == "deepin" ]]; then
    
        sudo apt install -y deepin-wine11-stable
    
    else
    
        if ! sudo apt install -y \
            wine \
            wine64 \
            wine32 \
   #         wine64-preloader \
   #         wine32-preloader
            
        then
            error "Wine installation failed."
            exit 1
        fi

    #######################################################################
    # Verify
    #######################################################################
        if command -v wine >/dev/null 2>&1 &&
           command -v wineboot >/dev/null 2>&1 &&
           command -v winecfg >/dev/null 2>&1 &&
           command -v wineserver >/dev/null 2>&1; then
        
            success "Wine installation completed."
            wine --version
        
        else
        
            error "Wine installation is incomplete."
            error "Missing: wine / wineboot / winecfg / wineserver"
            exit 1
        
        fi

    
    fi


    #######################################################################
    # Winetricks
    #######################################################################

    if ! command -v winetricks >/dev/null 2>&1; then
        error "Winetricks not found."
        exit 1
    fi

fi

###########################################################################
# Finish
###########################################################################

echo

success "Wine is ready."

sleep 1

###########################################################################
# P3.4 Create Wine Prefix
###########################################################################

echo

title "Creating Wine Prefix"

export WINEPREFIX="$PREFIX"
export WINEARCH=win64

###########################################################################
# Existing Prefix
###########################################################################

if [[ -d "$WINEPREFIX" ]]; then

    warn "Existing Wine Prefix found."

    read -rp "Recreate Wine Prefix? (y/N): " ANSWER

    case "$ANSWER" in
        y|Y|yes|YES)

            log "Removing existing Wine Prefix..."

            rm -rf "$WINEPREFIX"

            ;;

        *)

            success "Using existing Wine Prefix."

            SKIP_PREFIX=1

            ;;

    esac

fi

###########################################################################
# Create Prefix
###########################################################################

if [[ "${SKIP_PREFIX:-0}" != "1" ]]; then

    log "Initializing Wine..."

    for cmd in wine wineboot winecfg wineserver
    do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "$cmd not found."
            exit 1
        fi
    done

    wineboot --init

    wineserver -w

    sleep 3

    #######################################################################
    # Windows Version
    #######################################################################

    log "Configuring Windows Version..."

    winecfg -v win10

    wineserver -w

    #######################################################################
    # Winetricks Packages
    #######################################################################

    title "Installing Wine Components"

    COMPONENTS=(

        corefonts
        tahoma

        vcrun2015
        vcrun2017
        vcrun2019
        vcrun2022

        gdiplus
        riched20
        riched30

        msxml3
        msxml6

        ole32
        oleaut32

        wininet
        urlmon

        quartz

    )

    for component in "${COMPONENTS[@]}"; do

        log "Installing ${component}..."

        if winetricks -q "$component"; then
            success "${component} installed."
        else
            warn "${component} skipped."
        fi

        wineserver -w

    done

    #######################################################################
    # Registry Tweaks
    #######################################################################

    title "Optimizing Wine"

    reg add \
        "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" \
        /v VideoMemorySize \
        /t REG_SZ \
        /d 2048 \
        /f >/dev/null 2>&1 || true

    reg add \
        "HKEY_CURRENT_USER\\Software\\Wine\\Direct3D" \
        /v MaxVersionGL \
        /t REG_DWORD \
        /d 196610 \
        /f >/dev/null 2>&1 || true

    reg add \
        "HKEY_CURRENT_USER\\Software\\Wine\\Debug" \
        /v WINEDEBUG \
        /t REG_SZ \
        /d -all \
        /f >/dev/null 2>&1 || true

    #######################################################################
    # Finish
    #######################################################################

    wineserver -w

    success "Wine Prefix created successfully."

fi

###########################################################################
# Verify
###########################################################################

echo

if [[ -d "$WINEPREFIX" ]]; then
    success "Wine Prefix Ready"
else
    error "Wine Prefix creation failed."
    exit 1
fi

sleep 1

###########################################################################
# P3.5 Find Zalo Installer
###########################################################################

echo

title "Searching for Zalo Installer"

SEARCH_PATHS=(
    "$HOME/Downloads"
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Downloads/Software"
    "$WORKDIR"
)

FOUND_FILES=()

###########################################################################
# Search Installer
###########################################################################

for DIR in "${SEARCH_PATHS[@]}"; do

    [[ -d "$DIR" ]] || continue

    while IFS= read -r FILE; do
        FOUND_FILES+=("$FILE")
    done < <(
        find "$DIR" -maxdepth 2 -type f \
        \( \
            -iname "ZaloSetup.exe" \
            -o -iname "zalosetup.exe" \
        \) 2>/dev/null
    )

done

###########################################################################
# No Installer Found
###########################################################################

if [[ ${#FOUND_FILES[@]} -eq 0 ]]; then

    error "ZaloSetup.exe not found."

    echo
    echo "Please download the latest Zalo installer"
    echo "and place it in one of these folders:"
    echo
    echo "  $HOME/Downloads"
    echo "  $HOME/Desktop"
    echo "  $HOME/Documents"
    echo
    exit 1

fi

###########################################################################
# One Installer Found
###########################################################################

if [[ ${#FOUND_FILES[@]} -eq 1 ]]; then

    ZALO_SETUP="${FOUND_FILES[0]}"

    success "Installer found."

    log "$ZALO_SETUP"

else

###########################################################################
# Multiple Installers
###########################################################################

    echo

    warn "Multiple installers found."

    echo

    for i in "${!FOUND_FILES[@]}"; do
        printf "%2d) %s\n" $((i+1)) "${FOUND_FILES[$i]}"
    done

    echo

    while true; do

        read -rp "Select installer [1-${#FOUND_FILES[@]}]: " CHOICE

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] &&
           (( CHOICE >= 1 && CHOICE <= ${#FOUND_FILES[@]} )); then

            ZALO_SETUP="${FOUND_FILES[$((CHOICE-1))]}"

            break

        fi

    done

fi

###########################################################################
# Verify Installer
###########################################################################

FILE_SIZE=$(stat -c%s "$ZALO_SETUP" 2>/dev/null || echo 0)

if (( FILE_SIZE < 1000000 )); then

    error "Installer file is too small."

    exit 1

fi

###########################################################################
# Verify PE Executable
###########################################################################

if command -v file >/dev/null 2>&1; then

    if ! file "$ZALO_SETUP" | grep -Eq "PE32|MS-DOS executable"; then

        error "This is not a valid Windows installer."

        exit 1

    fi

fi

###########################################################################
# Finish
###########################################################################

echo

success "Using installer:"

echo "$ZALO_SETUP"

echo

success "Installer verification completed."

sleep 1

###########################################################################
# P3.6 Install Zalo
###########################################################################

echo

title "Installing Zalo"

export WINEPREFIX="$PREFIX"
export WINEARCH=win64

###########################################################################
# Verify Installer
###########################################################################

if [[ ! -f "$ZALO_SETUP" ]]; then

    error "Zalo installer not found."

    exit 1

fi

###########################################################################
# Launch Installer
###########################################################################

log "Launching Zalo installer..."

wine "$ZALO_SETUP"

while pgrep -f ZaloSetup.exe >/dev/null
do
    sleep 1
done

if command -v wineserver >/dev/null 2>&1; then
    wineserver -w
fi

sleep 3

###########################################################################
# Search Zalo.exe
###########################################################################

title "Searching Installed Zalo"

ZALO_EXE=$(find "$PREFIX/drive_c" \
    -type f \
    -iname "Zalo.exe" \
    2>/dev/null \
    | head -n1)

###########################################################################
# Verify Installation
###########################################################################

if [[ -z "$ZALO_EXE" ]]; then

    error "Unable to locate Zalo.exe"

    echo

    echo "Installation may have failed or was cancelled."

    exit 1

fi

###########################################################################
# Search Uninstaller
###########################################################################

UNINSTALL_EXE=$(find "$PREFIX/drive_c" \
    -type f \
    \( \
        -iname "unins*.exe" \
        -o -iname "uninstall.exe" \
    \) \
    2>/dev/null \
    | head -n1)

###########################################################################
# Save Information
###########################################################################

mkdir -p "$WORKDIR"

echo "$ZALO_EXE" > "$WORKDIR/zalo.path"

if [[ -n "$UNINSTALL_EXE" ]]; then
    echo "$UNINSTALL_EXE" > "$WORKDIR/uninstall.path"
fi

echo "$SCRIPT_VERSION" > "$WORKDIR/version"

echo "$PREFIX" > "$WORKDIR/prefix.path"

wine --version > "$WORKDIR/wine.version"

###########################################################################
# Install Log
###########################################################################

cat > "$WORKDIR/install.log" <<EOF
=========================================
Zalo Wine Installation
=========================================

Date       : $(date)

User       : $USER

Linux      : ${PRETTY_NAME:-Unknown}

Desktop    : ${XDG_CURRENT_DESKTOP:-Unknown}

Wine       : $(wine --version)

Prefix     : $PREFIX

Executable : $ZALO_EXE

Version    : $SCRIPT_VERSION

Status     : SUCCESS

=========================================
EOF

###########################################################################
# Display Summary
###########################################################################

echo

success "Installation completed successfully."

echo

echo "========================================="
echo "Installation Summary"
echo "========================================="
echo
echo "Wine Prefix :"
echo "  $PREFIX"
echo
echo "Zalo :"
echo "  $ZALO_EXE"

if [[ -n "$UNINSTALL_EXE" ]]; then
echo
echo "Uninstaller :"
echo "  $UNINSTALL_EXE"
fi

echo
echo "Installer Data :"
echo "  $WORKDIR"
echo
echo "========================================="

sleep 2

###########################################################################
# P3.7 Create Launchers
###########################################################################

echo

title "Creating Application Launchers"

APP_DIR="$HOME/.local/share/applications"

mkdir -p "$APP_DIR"
mkdir -p "$HOME/.local/share/icons"

###########################################################################
# Install Icon
###########################################################################

ICON_SOURCE="$SCRIPT_DIR/zalo.png"

if [[ -f "$ICON_SOURCE" ]]; then

    cp -f "$ICON_SOURCE" "$ICON_FILE"

    success "Application icon installed."

else

    warn "Icon file not found."

fi

###########################################################################
# Launcher : Zalo
###########################################################################

cat > "$APP_DIR/zalo.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Zalo
Comment=Zalo Messenger
Exec=env WINEPREFIX=$PREFIX WINEDEBUG=-all wine "$ZALO_EXE"
Icon=$ICON_FILE
Terminal=false
StartupNotify=true
Categories=Network;InstantMessaging;
StartupWMClass=Zalo.exe
EOF

###########################################################################
# Launcher : Safe Mode
###########################################################################

cat > "$APP_DIR/zalo-safe.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Zalo (Safe Mode)
Comment=Launch Zalo in Safe Mode
Exec=env WINEPREFIX=$PREFIX wine "$ZALO_EXE"
Icon=$ICON_FILE
Terminal=false
Categories=Utility;
EOF

###########################################################################
# Launcher : Wine Configuration
###########################################################################

cat > "$APP_DIR/zalo-winecfg.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Zalo Wine Configuration
Comment=Configure Wine Prefix
Exec=env WINEPREFIX=$PREFIX winecfg
Icon=wine
Terminal=false
Categories=Settings;
EOF

###########################################################################
# Launcher : Wine Uninstaller
###########################################################################

cat > "$APP_DIR/zalo-uninstall.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Uninstall Zalo
Comment=Wine Uninstaller
Exec=env WINEPREFIX=$PREFIX wine uninstaller
Icon=wine
Terminal=false
Categories=Utility;
EOF

###########################################################################
# Permissions
###########################################################################

chmod +x "$APP_DIR"/*.desktop

###########################################################################
# Desktop Shortcut
###########################################################################

DESKTOP_DIR="$HOME/Desktop"

if [[ -d "$DESKTOP_DIR" ]]; then

    cp "$APP_DIR/zalo.desktop" "$DESKTOP_DIR/"

    chmod +x "$DESKTOP_DIR/zalo.desktop"

fi

###########################################################################
# Trust Desktop Shortcut (Deepin / GNOME)
###########################################################################

if command -v gio >/dev/null 2>&1; then

    gio set \
        "$DESKTOP_DIR/zalo.desktop" \
        metadata::trusted true \
        >/dev/null 2>&1 || true

fi

###########################################################################
# Refresh Desktop Database
###########################################################################

if command -v update-desktop-database >/dev/null 2>&1; then

    update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

fi

###########################################################################
# KDE Plasma
###########################################################################

if command -v kbuildsycoca6 >/dev/null 2>&1; then

    kbuildsycoca6 >/dev/null 2>&1 || true

elif command -v kbuildsycoca5 >/dev/null 2>&1; then

    kbuildsycoca5 >/dev/null 2>&1 || true

fi

###########################################################################
# Refresh Icon Cache
###########################################################################

if command -v gtk-update-icon-cache >/dev/null 2>&1; then

    gtk-update-icon-cache "$HOME/.local/share/icons" >/dev/null 2>&1 || true

fi

###########################################################################
# Save Launcher Information
###########################################################################

cat > "$WORKDIR/launchers.list" <<EOF
$APP_DIR/zalo.desktop
$APP_DIR/zalo-safe.desktop
$APP_DIR/zalo-winecfg.desktop
$APP_DIR/zalo-uninstall.desktop
EOF

###########################################################################
# Summary
###########################################################################

echo

success "Launchers created successfully."

echo

echo "Installed Launchers"

echo "  ✔ Zalo"
echo "  ✔ Zalo (Safe Mode)"
echo "  ✔ Zalo Wine Configuration"
echo "  ✔ Uninstall Zalo"

sleep 2

###########################################################################
# P3.8 Post Installation
###########################################################################

echo

title "Finalizing Installation"

###########################################################################
# Verify Installation
###########################################################################

[[ -f "$ZALO_EXE" ]] || {
    error "Zalo executable not found."
    exit 1
}

[[ -f "$DESKTOP_FILE" ]] || {
    warn "Desktop launcher missing."
}

###########################################################################
# Create User Command Directory
###########################################################################

mkdir -p "$HOME/.local/bin"

###########################################################################
# Command : zalo
###########################################################################

cat > "$HOME/.local/bin/zalo" <<EOF
#!/usr/bin/env bash

export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export WINEDEBUG=-all

exec wine "$ZALO_EXE" "\$@"
EOF

chmod +x "$HOME/.local/bin/zalo"

###########################################################################
# Command : zalo-winecfg
###########################################################################

cat > "$HOME/.local/bin/zalo-winecfg" <<EOF
#!/usr/bin/env bash

export WINEPREFIX="$PREFIX"

exec winecfg
EOF

chmod +x "$HOME/.local/bin/zalo-winecfg"

###########################################################################
# Command : zalo-uninstaller
###########################################################################

cat > "$HOME/.local/bin/zalo-uninstaller" <<EOF
#!/usr/bin/env bash

export WINEPREFIX="$PREFIX"

exec wine uninstaller
EOF

chmod +x "$HOME/.local/bin/zalo-uninstaller"

###########################################################################
# Command Placeholders
###########################################################################

for CMD in \
    zalo-repair \
    zalo-backup \
    zalo-restore \
    zalo-diagnostic
do

cat > "$HOME/.local/bin/$CMD" <<EOF
#!/usr/bin/env bash

echo
echo "$CMD is not installed yet."
echo "Please install the Zalo Tools package."
echo
EOF

chmod +x "$HOME/.local/bin/$CMD"

done

###########################################################################
# PATH Check
###########################################################################

case ":$PATH:" in
    *":$HOME/.local/bin:"*)
        ;;
    *)
        warn "~/.local/bin is not in PATH."
        warn "You may need to log out and log back in."
        ;;
esac

###########################################################################
# Status File
###########################################################################

cat > "$WORKDIR/status" <<EOF
STATUS=SUCCESS
DATE=$(date +"%F %T")
PREFIX=$PREFIX
EXECUTABLE=$ZALO_EXE
LAUNCHER=$DESKTOP_FILE
EOF

###########################################################################
# Launch Question
###########################################################################

if command -v zenity >/dev/null 2>&1; then

    if zenity \
        --question \
        --width=420 \
        --title="Zalo Wine Installer" \
        --text="Zalo has been installed successfully.\n\nLaunch Zalo now?"; then

        zalo &

    fi

fi

###########################################################################
# Summary
###########################################################################

echo
echo "================================================="
echo "          Zalo Wine Installer"
echo "================================================="
echo
echo "Installation completed successfully."
echo
echo "Available Commands"
echo
echo "  zalo"
echo "  zalo-winecfg"
echo "  zalo-uninstaller"
echo "  zalo-repair"
echo "  zalo-backup"
echo "  zalo-restore"
echo "  zalo-diagnostic"
echo
echo "Installer Data"
echo
echo "  $WORKDIR"
echo
echo "================================================="

success "Done."

sleep 2


