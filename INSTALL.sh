#!/usr/bin/env bash

# Installation script for spmt
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="spmt"

# Create installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Create the script file
cat >"$INSTALL_DIR/$SCRIPT_NAME" <<'EOL'
#!/usr/bin/env bash

# System Package Manager Toolkit (spmt)
# Version: 3.0
# Author: d4rkb4sh8
# Description: Comprehensive system configuration management tool

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="${SPMT_BACKUP_DIR:-$HOME/.spmt_backups}"
CONFIG_FILE="$BACKUP_DIR/last_backup.conf"
TMP_FILE="/tmp/spmt_temp.$$"

# Error handling
trap 'rm -f $TMP_FILE; exit 1' SIGINT SIGTERM ERR

# --- Function Definitions ---

show_help() {
    echo -e "${GREEN}System Package Manager Toolkit (spmt) - Version 3.0${NC}"
    echo "A complete system configuration backup/restore solution"
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo "  spmt [OPTION]... [PATH]..."
    echo
    echo -e "${YELLOW}Main Options:${NC}"
    echo "  -d, --detect              Detect system configuration"
    echo "  -b, --backup [PATH]       Create system backup (default: $BACKUP_DIR)"
    echo "  -r, --restore [PATH]      Restore system from backup"
    echo "  -l, --list-backups        List available backups"
    echo "  -c, --clean-backups [DAYS] Remove backups older than X days (default: 30)"
    echo "  -h, --help                Show this help"
    echo "  -v, --version             Display version"
    echo
    echo -e "${YELLOW}Backup/Restore Options:${NC}"
    echo "  -P, --packages-only       Only manage packages"
    echo "  -D, --desktop-only        Only manage desktop settings"
    echo "  -N, --no-third-party      Exclude third-party packages"
    echo "  --skip-fonts              Skip font files"
    echo "  --skip-themes             Skip theme files"
    echo "  --skip-extensions         Skip desktop extensions"
    echo
    echo -e "${YELLOW}Information Options:${NC}"
    echo "  --show-pkg                Show detected package managers"
    echo "  --show-de                 Show desktop environment info"
    echo "  --show-distro             Show distribution info"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo "  spmt --backup ~/backups"
    echo "  spmt --restore /backups/system_backup_20231030 -P"
    echo "  spmt --detect --show-pkg --show-de"
    exit 0
}

show_version() {
    echo -e "${GREEN}System Package Manager Toolkit${NC}"
    echo "Version: 3.0"
    echo "License: MIT"
    exit 0
}

detect_system() {
    # Reset detection variables
    unset DISTRO DISTRO_VERSION DEFAULT_PKG_MGR THIRD_PARTY_MGRS DESKTOP_ENV DESKTOP_VERSION

    # Detect distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID:-unknown}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
    else
        DISTRO=$(uname -s)
        DISTRO_VERSION=$(uname -r)
    fi

    # Detect package managers
    declare -A PKG_MGRS=(
        ["ubuntu"]="apt" ["debian"]="apt" ["fedora"]="dnf" ["centos"]="yum"
        ["rhel"]="yum" ["arch"]="pacman" ["opensuse"]="zypper" ["alpine"]="apk"
    )
    DEFAULT_PKG_MGR=${PKG_MGRS[$DISTRO]}

    # Detect third-party managers
    THIRD_PARTY_MGRS=()
    for cmd in snap flatpak pip pipx npm cargo conda brew yarn; do
        command -v $cmd >/dev/null 2>&1 && THIRD_PARTY_MGRS+=("$cmd")
    done

    # Detect desktop environment
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        DESKTOP_ENV=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')
    elif [ -n "$GDMSESSION" ]; then
        DESKTOP_ENV=$(echo "$GDMSESSION" | tr '[:upper:]' '[:lower:]')
    else
        DESKTOP_ENV="unknown"
    fi

    # Detect DE version
    case $DESKTOP_ENV in
        *gnome*) DESKTOP_VERSION=$(gnome-shell --version 2>/dev/null | awk '{print $3}') ;;
        *kde*|*plasma*) DESKTOP_VERSION=$(plasmashell --version 2>/dev/null | awk '/^KDE/{print $2}') ;;
        *xfce*) DESKTOP_VERSION=$(xfce4-panel --version 2>/dev/null | head -n1 | awk '{print $2}') ;;
        *hyprland*) DESKTOP_VERSION=$(hyprctl version 2>/dev/null | grep 'tag:' | awk '{print $2}') ;;
        *) DESKTOP_VERSION="unknown" ;;
    esac
}

backup_packages() {
    local backup_dir="$1/packages"
    mkdir -p "$backup_dir"

    echo -e "${BLUE}Backing up system packages...${NC}"

    # Native packages
    case $DEFAULT_PKG_MGR in
        apt) dpkg --get-selections > "$backup_dir/pkglist.txt" ;;
        dnf|yum) rpm -qa > "$backup_dir/pkglist.txt" ;;
        pacman) pacman -Qqe > "$backup_dir/pkglist.txt" ;;
        zypper) zypper -q packages --installed-only > "$backup_dir/pkglist.txt" ;;
        apk) apk -q info -v > "$backup_dir/pkglist.txt" ;;
    esac 2>/dev/null

    # Third-party packages
    for mgr in "${THIRD_PARTY_MGRS[@]}"; do
        case $mgr in
            snap) snap list | awk 'NR>1 {print $1}' > "$backup_dir/snap.txt" ;;
            flatpak) flatpak list --app --columns=application > "$backup_dir/flatpak.txt" ;;
            pip) pip freeze > "$backup_dir/pip.txt" ;;
            pipx) pipx list --short | awk '{print $1}' > "$backup_dir/pipx.txt" ;;
            npm) npm list -g --depth=0 | awk -F@ '{print $1}' | tail -n +2 > "$backup_dir/npm.txt" ;;
            cargo) cargo install --list | grep -v ':' | awk '{print $1}' > "$backup_dir/cargo.txt" ;;
            conda) conda env export --from-history > "$backup_dir/conda.yml" ;;
            brew) brew leaves > "$backup_dir/brew.txt" ;;
            yarn) yarn global list --depth=0 | awk '{print $2}' | awk -F@ '{print $1}' > "$backup_dir/yarn.txt" ;;
        esac 2>/dev/null
    done
}

backup_desktop() {
    local backup_dir="$1/desktop"
    mkdir -p "$backup_dir"

    echo -e "${BLUE}Backing up desktop environment...${NC}"

    # Desktop-specific configs
    case $DESKTOP_ENV in
        *gnome*)
            dconf dump / > "$backup_dir/gnome.dconf"
            cp -r "$HOME/.local/share/gnome-shell/extensions" "$backup_dir/" ;;
        *kde*|*plasma*)
            cp -r "$HOME/.config/plasma*" "$HOME/.config/kde*" "$backup_dir/" ;;
        *xfce*)
            cp -r "$HOME/.config/xfce4" "$backup_dir/" ;;
        *hyprland*)
            cp -r "$HOME/.config/hypr" "$backup_dir/" ;;
    esac 2>/dev/null

    # Common assets
    [ -z "$SKIP_FONTS" ] && cp -r "$HOME/.fonts" "$HOME/.local/share/fonts" "$backup_dir/" 2>/dev/null
    [ -z "$SKIP_THEMES" ] && cp -r "$HOME/.themes" "$HOME/.icons" "$backup_dir/" 2>/dev/null
    [ -z "$SKIP_EXTENSIONS" ] && cp -r "$HOME/.local/share/gnome-shell/extensions" "$backup_dir/" 2>/dev/null
}

restore_packages() {
    local restore_dir="$1/packages"

    echo -e "${BLUE}Restoring packages...${NC}"

    # Native packages
    case $DEFAULT_PKG_MGR in
        apt) sudo apt update && sudo dpkg --set-selections < "$restore_dir/pkglist.txt" && sudo apt-get -y dselect-upgrade ;;
        dnf) sudo dnf -y install $(cat "$restore_dir/pkglist.txt") ;;
        yum) sudo yum -y install $(cat "$restore_dir/pkglist.txt") ;;
        pacman) sudo pacman -S --needed $(cat "$restore_dir/pkglist.txt") ;;
        zypper) sudo zypper -n install $(cat "$restore_dir/pkglist.txt") ;;
        apk) sudo apk add $(cat "$restore_dir/pkglist.txt") ;;
    esac

    # Third-party packages
    for mgr in "${THIRD_PARTY_MGRS[@]}"; do
        case $mgr in
            snap) xargs -a "$restore_dir/snap.txt" -n1 sudo snap install ;;
            flatpak) xargs -a "$restore_dir/flatpak.txt" -n1 flatpak install -y ;;
            pip) pip install -r "$restore_dir/pip.txt" ;;
            pipx) xargs -a "$restore_dir/pipx.txt" -n1 pipx install ;;
            npm) xargs -a "$restore_dir/npm.txt" -n1 sudo npm install -g ;;
            cargo) xargs -a "$restore_dir/cargo.txt" -n1 cargo install ;;
            conda) conda env create -f "$restore_dir/conda.yml" ;;
            brew) xargs -a "$restore_dir/brew.txt" -n1 brew install ;;
            yarn) xargs -a "$restore_dir/yarn.txt" -n1 yarn global add ;;
        esac
    done
}

restore_desktop() {
    local restore_dir="$1/desktop"

    echo -e "${BLUE}Restoring desktop environment...${NC}"

    # Desktop-specific configs
    case $DESKTOP_ENV in
        *gnome*)
            dconf load / < "$restore_dir/gnome.dconf"
            cp -r "$restore_dir/extensions" "$HOME/.local/share/gnome-shell/" ;;
        *kde*|*plasma*)
            cp -r "$restore_dir/plasma*" "$restore_dir/kde*" "$HOME/.config/" ;;
        *xfce*)
            cp -r "$restore_dir/xfce4" "$HOME/.config/" ;;
        *hyprland*)
            cp -r "$restore_dir/hypr" "$HOME/.config/" ;;
    esac 2>/dev/null

    # Common assets
    [ -z "$SKIP_FONTS" ] && cp -r "$restore_dir/.fonts" "$restore_dir/fonts" "$HOME/" 2>/dev/null
    [ -z "$SKIP_THEMES" ] && cp -r "$restore_dir/.themes" "$restore_dir/.icons" "$HOME/" 2>/dev/null
}

backup_system() {
    local backup_path="${1:-$BACKUP_DIR}"
    local human_date=$(date "+%Y%m%d_%H%M%S")
    local backup_dir="$backup_path/system_backup_$human_date"
    local epoch_timestamp=$(date +%s)

    mkdir -p "$backup_dir" || {
        echo -e "${RED}Failed to create backup directory${NC}"
        exit 1
    }

    detect_system
    echo -e "${GREEN}Starting system backup...${NC}"

    [ -z "$SCOPE" ] && SCOPE="full"
    case $SCOPE in
        "packages") backup_packages "$backup_dir" ;;
        "desktop") backup_desktop "$backup_dir" ;;
        "full")
            backup_packages "$backup_dir"
            backup_desktop "$backup_dir"
            ;;
    esac

    # Save metadata
    echo "DESKTOP_ENV=$DESKTOP_ENV" > "$backup_dir/meta.conf"
    echo "DISTRO=$DISTRO" >> "$backup_dir/meta.conf"
    echo "TIMESTAMP=$epoch_timestamp" >> "$backup_dir/meta.conf"

    echo -e "${GREEN}Backup created: $backup_dir${NC}"
}

restore_system() {
    local restore_path="$1"
    local backup_conf="$restore_path/meta.conf"

    [ ! -f "$backup_conf" ] && {
        echo -e "${RED}Invalid backup directory${NC}"
        exit 1
    }

    . "$backup_conf"
    detect_system

    echo -e "${GREEN}Starting system restore...${NC}"

    [ -z "$SCOPE" ] && SCOPE="full"
    case $SCOPE in
        "packages") restore_packages "$restore_path" ;;
        "desktop") restore_desktop "$restore_path" ;;
        "full")
            restore_packages "$restore_path"
            restore_desktop "$restore_path"
            ;;
    esac

    echo -e "${GREEN}Restore completed successfully${NC}"
}

list_backups() {
    echo -e "${YELLOW}Available backups:${NC}"
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "system_backup_*" | sort -r | while read dir; do
        echo -n "$(basename "$dir")"
        [ -f "$dir/meta.conf" ] && . "$dir/meta.conf"
        echo " - $DISTRO | $DESKTOP_ENV | $(date -d "@$TIMESTAMP" '+%Y-%m-%d %H:%M %Z')"
    done
}

clean_backups() {
    local days=${1:-30}
    echo -e "${YELLOW}Cleaning backups older than $days days...${NC}"
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "system_backup_*" -mtime "+$days" -exec rm -rf {} \;
    echo -e "${GREEN}Cleanup complete${NC}"
}

# --- Main Execution ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--detect)
            detect_system
            echo -e "System Detection:"
            echo -e "  Distro: ${BLUE}$DISTRO $DISTRO_VERSION${NC}"
            echo -e "  Package Manager: ${YELLOW}$DEFAULT_PKG_MGR${NC}"
            echo -e "  Third-party: ${YELLOW}${THIRD_PARTY_MGRS[*]}${NC}"
            echo -e "  Desktop: ${BLUE}$DESKTOP_ENV $DESKTOP_VERSION${NC}"
            exit 0 ;;
        -b|--backup)
            shift; backup_system "$1"
            exit 0 ;;
        -r|--restore)
            shift; restore_system "$1"
            exit 0 ;;
        -l|--list-backups)
            list_backups; exit 0 ;;
        -c|--clean-backups)
            shift; clean_backups "$1"
            exit 0 ;;
        -P|--packages-only)
            SCOPE="packages" ;;
        -D|--desktop-only)
            SCOPE="desktop" ;;
        -N|--no-third-party)
            THIRD_PARTY_MGRS=() ;;
        --skip-fonts)
            SKIP_FONTS=1 ;;
        --skip-themes)
            SKIP_THEMES=1 ;;
        --skip-extensions)
            SKIP_EXTENSIONS=1 ;;
        --show-pkg)
            detect_system
            echo -e "Package Managers:"
            echo -e "  System: ${YELLOW}$DEFAULT_PKG_MGR${NC}"
            echo -e "  Third-party: ${YELLOW}${THIRD_PARTY_MGRS[*]}${NC}"
            exit 0 ;;
        --show-de)
            detect_system
            echo -e "Desktop Environment:"
            echo -e "  Name: ${BLUE}$DESKTOP_ENV${NC}"
            echo -e "  Version: ${BLUE}$DESKTOP_VERSION${NC}"
            exit 0 ;;
        --show-distro)
            detect_system
            echo -e "Distribution:"
            echo -e "  ID: ${BLUE}$DISTRO${NC}"
            echo -e "  Version: ${BLUE}$DISTRO_VERSION${NC}"
            exit 0 ;;
        -h|--help)
            show_help ;;
        -v|--version)
            show_version ;;
        *)
            echo -e "${RED}Invalid option: $1${NC}"
            show_help
            exit 1 ;;
    esac
    shift
done

# Default action if no options provided
show_help
EOL

# Make executable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Verify installation
if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
  echo -e "\033[32mspmt installed successfully to $INSTALL_DIR/\033[0m"

  # Check if in PATH
  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "\033[33mWarning: $INSTALL_DIR is not in your PATH!\033[0m"
    echo "Add this to your shell config:"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
else
  echo -e "\033[31mInstallation failed!\033[0m"
  exit 1
fi
