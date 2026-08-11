#!/usr/bin/env bash
#
# ==========================================================
# Zalo Wine Installer
# Version : 4.0
# Author  : Long Nguyen
# ==========================================================

set -euo pipefail

PREFIX="$HOME/.wine-zalo"
WORKDIR="$HOME/.local/share/zalo"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
ICON_FILE="$ICON_DIR/zalo.png"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="4.0"
TMP_DIR="$(mktemp -d)"

WINEHQ_KEY_URL="https://dl.winehq.org/wine-builds/winehq.key"
WINEHQ_KEY_FILE="/etc/apt/keyrings/winehq-archive.gpg"
WINEHQ_PKG_NAME="winehq-stable"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
NC='\033[0m'

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}✔ $1${NC}"; }
title() {
    echo
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${BLUE}====================================================${NC}"
}

clear 2>/dev/null || true
cat <<'BANNER'
=========================================================
              ZALO WINE INSTALLER
                    Version 4.0
=========================================================

Author : Long Nguyen

Supported:
  Linux Mint / Ubuntu / Kubuntu / Zorin OS / Deepin / Pop!_OS / KDE Neon

Wine Prefix:
  ~/.wine-zalo

=========================================================
BANNER

source /etc/os-release
DISTRO="${ID:-unknown}"
VERSION="${VERSION_ID:-}"
UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

log "Detected Linux : ${PRETTY_NAME:-Unknown}"
log "Architecture   : $(uname -m)"
log "Ubuntu base    : ${UBUNTU_CODENAME:-unknown}"

mkdir -p "$WORKDIR" "$ICON_DIR" "$APP_DIR"

########################################################################
# Dependencies
########################################################################

title "Installing Dependencies"

sudo apt update

# Enable i386 for Wine packages where supported.
if ! dpkg --print-foreign-architectures | grep -qx i386; then
    sudo dpkg --add-architecture i386
    sudo apt update
fi

sudo apt install -y \
    ca-certificates \
    curl \
    wget \
    gnupg \
    file \
    unzip \
    cabextract \
    winbind \
    zenity \
    p7zip-full \
    xdg-utils \
    desktop-file-utils

########################################################################
# Fonts
########################################################################

title "Installing Fonts"

for pkg in fonts-liberation fonts-wqy-zenhei fonts-wqy-microhei ttf-mscorefonts-installer; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        success "$pkg already installed."
    else
        sudo apt install -y "$pkg" || warn "$pkg unavailable; continuing."
    fi
done

########################################################################
# Clean old WineHQ configuration
########################################################################

title "Preparing WineHQ Repository"

# Remove old WineHQ source files that may still point to .key or an old suite.
sudo rm -f /etc/apt/sources.list.d/winehq-*.sources
sudo rm -f /etc/apt/sources.list.d/winehq-*.list

# Remove old WineHQ key files that caused unsupported-filetype / NO_PUBKEY errors.
sudo rm -f /etc/apt/keyrings/winehq-archive.key
sudo rm -f /etc/apt/keyrings/winehq-archive.gpg
sudo rm -f /usr/share/keyrings/winehq-archive.gpg
sudo rm -f /usr/share/keyrings/winehq.gpg

sudo mkdir -pm755 /etc/apt/keyrings

# WineHQ changed to a binary GPG keyring for newer APT setups.
curl -fsSL "$WINEHQ_KEY_URL" \
    | gpg --dearmor \
    | sudo tee "$WINEHQ_KEY_FILE" >/dev/null

sudo chmod 644 "$WINEHQ_KEY_FILE"

if [[ -z "$UBUNTU_CODENAME" ]]; then
    error "Unable to determine Ubuntu base codename."
    exit 1
fi

SOURCES_URL="https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_CODENAME}/winehq-${UBUNTU_CODENAME}.sources"
SOURCES_FILE="/etc/apt/sources.list.d/winehq-${UBUNTU_CODENAME}.sources"

log "WineHQ suite: $UBUNTU_CODENAME"

if curl -fsI "$SOURCES_URL" >/dev/null 2>&1; then
    curl -fsSL "$SOURCES_URL" -o "$TMP_DIR/winehq.sources"

    # WineHQ's supplied file may reference the old .key name.
    sed -i \
        "s|/etc/apt/keyrings/winehq-archive.key|$WINEHQ_KEY_FILE|g" \
        "$TMP_DIR/winehq.sources"

    sudo install -m 644 "$TMP_DIR/winehq.sources" "$SOURCES_FILE"
    success "WineHQ repository configured."
else
    warn "WineHQ repository not available for '$UBUNTU_CODENAME'."
    warn "Falling back to the distribution Wine packages."
    SOURCES_FILE=""
fi

sudo apt update

########################################################################
# Install Wine
########################################################################

title "Installing Wine"

if [[ -n "$SOURCES_FILE" ]] && apt-cache policy "$WINEHQ_PKG_NAME" 2>/dev/null | grep -q 'Candidate:'; then
    if sudo apt install -y --install-recommends "$WINEHQ_PKG_NAME"; then
        success "WineHQ Stable installed."
    else
        warn "WineHQ Stable installation failed; using distribution Wine."
        sudo apt install -y --install-recommends wine wine64 wine32
    fi
else
    log "Installing distribution Wine..."
    sudo apt install -y --install-recommends wine wine64 wine32
fi

hash -r 2>/dev/null || true

if ! command -v wine >/dev/null 2>&1; then
    # WineHQ binaries are normally in /opt/wine-stable/bin.
    if [[ -x /opt/wine-stable/bin/wine ]]; then
        export PATH="/opt/wine-stable/bin:$PATH"
    elif [[ -x /opt/wine-devel/bin/wine ]]; then
        export PATH="/opt/wine-devel/bin:$PATH"
    fi
fi

if ! command -v wine >/dev/null 2>&1; then
    error "Wine installation failed: wine command not found."
    exit 1
fi

success "Wine: $(wine --version)"

########################################################################
# Winetricks
########################################################################

title "Installing Winetricks"

if ! command -v winetricks >/dev/null 2>&1; then
    if ! sudo apt install -y winetricks; then
        mkdir -p "$HOME/.local/bin"
        curl -fsSL \
            https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
            -o "$HOME/.local/bin/winetricks"
        chmod +x "$HOME/.local/bin/winetricks"
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

command -v winetricks >/dev/null 2>&1 || { error "Winetricks installation failed."; exit 1; }
success "Winetricks ready."

########################################################################
# Wine Prefix
########################################################################

title "Creating Wine Prefix"

export WINEPREFIX="$PREFIX"
export WINEARCH=win64

if [[ -d "$PREFIX" ]]; then
    warn "Existing Wine Prefix found: $PREFIX"
    read -rp "Use existing prefix? [Y/n]: " ANSWER
    ANSWER="${ANSWER:-Y}"
    if [[ ! "$ANSWER" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        log "Removing existing Wine Prefix..."
        rm -rf "$PREFIX"
    fi
fi

if [[ ! -d "$PREFIX/drive_c" ]]; then
    log "Initializing Wine Prefix..."
    wineboot -u
    wineserver -w
fi

winecfg -v win10
wineserver -w

########################################################################
# Wine components
########################################################################

title "Installing Wine Components"

COMPONENTS=(
    corefonts
    tahoma
    vcrun2019
    gdiplus
    riched20
)

for component in "${COMPONENTS[@]}"; do
    log "Installing $component..."
    if winetricks -q "$component"; then
        success "$component installed."
    else
        warn "$component could not be installed; continuing."
    fi
    wineserver -w || true
done

########################################################################
# Find Zalo installer
########################################################################

title "Searching for ZaloSetup.exe"

SEARCH_PATHS=(
    "$HOME/Downloads"
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Downloads/Software"
    "$WORKDIR"
)

# If the script is run through sudo/su, also search user Downloads folders.
if [[ -d /home ]]; then
    while IFS= read -r -d '' dir; do
        SEARCH_PATHS+=("$dir/Downloads")
    done < <(find /home -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
fi

FOUND_FILES=()
for DIR in "${SEARCH_PATHS[@]}"; do
    [[ -d "$DIR" ]] || continue
    while IFS= read -r FILE; do
        FOUND_FILES+=("$FILE")
    done < <(find "$DIR" -maxdepth 2 -type f \( -iname 'ZaloSetup.exe' -o -iname 'zalosetup.exe' \) 2>/dev/null)
done

# Remove duplicates while preserving order.
if (( ${#FOUND_FILES[@]} > 0 )); then
    UNIQUE_FILES=()
    declare -A SEEN=()
    for FILE in "${FOUND_FILES[@]}"; do
        if [[ -z "${SEEN[$FILE]+x}" ]]; then
            UNIQUE_FILES+=("$FILE")
            SEEN[$FILE]=1
        fi
    done
    FOUND_FILES=("${UNIQUE_FILES[@]}")
fi

if (( ${#FOUND_FILES[@]} == 0 )); then
    warn "ZaloSetup.exe was not found automatically."
    if [[ -t 0 ]] && command -v zenity >/dev/null 2>&1; then
        ZALO_SETUP=$(zenity --file-selection \
            --title="Chọn file ZaloSetup.exe" \
            --filename="$HOME/" \
            --file-filter="ZaloSetup.exe | *.exe" \
            2>/dev/null || true)
    else
        ZALO_SETUP=""
    fi

    if [[ -z "$ZALO_SETUP" ]]; then
        error "ZaloSetup.exe not found or not selected."
        exit 1
    fi
elif (( ${#FOUND_FILES[@]} == 1 )); then
    ZALO_SETUP="${FOUND_FILES[0]}"
else
    echo
    warn "Multiple Zalo installers found:"
    for i in "${!FOUND_FILES[@]}"; do
        printf '%2d) %s\n' "$((i+1))" "${FOUND_FILES[$i]}"
    done
    echo
    while true; do
        read -rp "Select installer [1-${#FOUND_FILES[@]}]: " CHOICE
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#FOUND_FILES[@]} )); then
            ZALO_SETUP="${FOUND_FILES[$((CHOICE-1))]}"
            break
        fi
        echo "Invalid selection."
    done
fi

if [[ ! -f "$ZALO_SETUP" ]]; then
    error "Selected installer does not exist."
    exit 1
fi

FILE_SIZE=$(stat -c%s "$ZALO_SETUP" 2>/dev/null || echo 0)
if (( FILE_SIZE < 1000000 )); then
    error "Installer file is too small or invalid."
    exit 1
fi

if command -v file >/dev/null 2>&1 && ! file "$ZALO_SETUP" | grep -Eq 'PE32|MS-DOS executable|PE32\+'; then
    error "Selected file does not look like a Windows executable."
    exit 1
fi

success "Using installer: $ZALO_SETUP"

########################################################################
# Install Zalo
########################################################################

title "Installing Zalo"

log "Launching Zalo installer..."
wine "$ZALO_SETUP"

# Wait for the Wine installer process to finish.
wineserver -w || true
sleep 3

########################################################################
# Locate Zalo executable
########################################################################

title "Locating Installed Zalo"

ZALO_ROOT="$PREFIX/drive_c/users/$USER/AppData/Local/Programs/Zalo"

# Prefer the stable launcher at Zalo/Zalo.exe.
if [[ -f "$ZALO_ROOT/Zalo.exe" ]]; then
    ZALO_EXE="$ZALO_ROOT/Zalo.exe"
else
    ZALO_EXE=$(find "$ZALO_ROOT" -type f -iname 'Zalo.exe' \
        -not -path '*/plugins/*' 2>/dev/null | sort -V | tail -n1 || true)
fi

if [[ -z "${ZALO_EXE:-}" || ! -f "$ZALO_EXE" ]]; then
    error "Unable to locate installed Zalo.exe."
    exit 1
fi

success "Zalo executable: $ZALO_EXE"

echo "$ZALO_EXE" > "$WORKDIR/zalo.path"
echo "$PREFIX" > "$WORKDIR/prefix.path"
echo "$SCRIPT_VERSION" > "$WORKDIR/version"
wine --version > "$WORKDIR/wine.version"

########################################################################
# Dynamic launcher
########################################################################

title "Creating Zalo Launcher"

mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/run-zalo.sh" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

PREFIX="$HOME/.wine-zalo"
ZALO_ROOT="$PREFIX/drive_c/users/$USER/AppData/Local/Programs/Zalo"

if ! command -v wine >/dev/null 2>&1; then
    zenity --error --title="Zalo" --text="Wine chưa được cài hoặc không có trong PATH."
    exit 1
fi

if [[ -f "$ZALO_ROOT/Zalo.exe" ]]; then
    ZALO_EXE="$ZALO_ROOT/Zalo.exe"
else
    ZALO_EXE=$(find "$ZALO_ROOT" -type f -iname 'Zalo.exe' \
        -not -path '*/plugins/*' 2>/dev/null | sort -V | tail -n1 || true)
fi

if [[ -z "${ZALO_EXE:-}" || ! -f "$ZALO_EXE" ]]; then
    zenity --error --title="Zalo" --text="Không tìm thấy Zalo.exe trong Wine Prefix."
    exit 1
fi

export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export WINEDEBUG=-all

exec wine "$ZALO_EXE" "$@"
LAUNCHER

chmod +x "$HOME/.local/bin/run-zalo.sh"

# Convenience command.
ln -sf "$HOME/.local/bin/run-zalo.sh" "$HOME/.local/bin/zalo"

########################################################################
# Desktop / Menu launchers
########################################################################

title "Creating Application Shortcuts"

ICON_SOURCE="$SCRIPT_DIR/zalo.png"
if [[ -f "$ICON_SOURCE" ]]; then
    cp -f "$ICON_SOURCE" "$ICON_FILE"
else
    warn "zalo.png not found beside installer; using Wine icon."
    ICON_FILE="wine"
fi

cat > "$APP_DIR/zalo.desktop" <<EOF2
[Desktop Entry]
Version=1.0
Type=Application
Name=Zalo
Comment=Zalo Messenger
Exec=$HOME/.local/bin/run-zalo.sh
Icon=$ICON_FILE
Terminal=false
StartupNotify=true
Categories=Network;InstantMessaging;
StartupWMClass=Zalo.exe
EOF2

cat > "$APP_DIR/zalo-safe.desktop" <<EOF2
[Desktop Entry]
Version=1.0
Type=Application
Name=Zalo (Safe Mode)
Comment=Launch Zalo using Wine
Exec=$HOME/.local/bin/run-zalo.sh
Icon=$ICON_FILE
Terminal=false
Categories=Utility;
EOF2

cat > "$APP_DIR/zalo-winecfg.desktop" <<EOF2
[Desktop Entry]
Version=1.0
Type=Application
Name=Zalo Wine Configuration
Comment=Configure Zalo Wine Prefix
Exec=env WINEPREFIX=$PREFIX winecfg
Icon=wine
Terminal=false
Categories=Settings;
EOF2

cat > "$APP_DIR/zalo-uninstall.desktop" <<EOF2
[Desktop Entry]
Version=1.0
Type=Application
Name=Uninstall Zalo
Comment=Wine Uninstaller
Exec=env WINEPREFIX=$PREFIX wine uninstaller
Icon=wine
Terminal=false
Categories=Utility;
EOF2

chmod +x "$APP_DIR"/*.desktop

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
mkdir -p "$DESKTOP_DIR"
cp -f "$APP_DIR/zalo.desktop" "$DESKTOP_DIR/Zalo.desktop"
chmod +x "$DESKTOP_DIR/Zalo.desktop"

if command -v gio >/dev/null 2>&1; then
    gio set "$DESKTOP_DIR/Zalo.desktop" metadata::trusted true >/dev/null 2>&1 || true
fi

update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 >/dev/null 2>&1 || true
fi

echo "$HOME/.local/bin/run-zalo.sh" > "$WORKDIR/launcher.path"
echo "$APP_DIR/zalo.desktop" > "$WORKDIR/desktop.path"

########################################################################
# Final verification
########################################################################

title "Final Verification"

if ! command -v wine >/dev/null 2>&1; then
    error "Wine is not available after installation."
    exit 1
fi

if [[ ! -d "$PREFIX/drive_c" ]]; then
    error "Wine Prefix is missing."
    exit 1
fi

if [[ ! -f "$HOME/.local/bin/run-zalo.sh" ]]; then
    error "Zalo launcher was not created."
    exit 1
fi

cat > "$WORKDIR/install.log" <<EOF2
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
EOF2

success "Installation completed successfully."

echo
echo "Zalo command : zalo"
echo "Launcher     : $HOME/.local/bin/run-zalo.sh"
echo "Wine Prefix  : $PREFIX"
echo "Menu         : $APP_DIR/zalo.desktop"
echo "Desktop      : $DESKTOP_DIR/Zalo.desktop"
echo

if command -v zenity >/dev/null 2>&1; then
    if zenity --question --width=420 --title="Zalo Wine Installer" \
        --text="Zalo đã được cài đặt thành công.\n\nMở Zalo ngay?"; then
        "$HOME/.local/bin/run-zalo.sh" >/dev/null 2>&1 &
    fi
fi

echo "================================================="
echo "          Zalo Wine Installer 4.0"
echo "================================================="
success "Done."
