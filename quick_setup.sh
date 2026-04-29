#!/bin/bash
# Quick setup script for Steam dynamic compatdata bind mounts.
# Run with sudo: sudo bash ./quick_setup.sh

set -e # Exit on first error

# --- Configuration ---
CONF_URL="https://raw.githubusercontent.com/thojo0/steam-multiuser-compatdata-fix/main/steamlibrary.conf"
INIT_SCRIPT_URL="https://raw.githubusercontent.com/thojo0/steam-multiuser-compatdata-fix/main/steamlibrary.init"

NAMESPACE_D_DIR="/etc/security/namespace.d"
CONF_TARGET="$NAMESPACE_D_DIR/99-steamlibrary.conf"
INIT_SCRIPT_TARGET="$NAMESPACE_D_DIR/99-steamlibrary.init"
TRIGGER_DIR="/opt/pam_namespace_steamlibrarytrigger"

PAM_CONFIG_LINE="session    optional    pam_namespace.so"
PAM_FILES=(
    # Comment / uncomment paths as appropriate for your system.
    # Debian
    "/etc/pam.d/common-session"
    "/etc/pam.d/common-session-noninteractive"
    # Arch
    #"/etc/pam.d/system-login"
)

# --- Execution ---

echo "[1/4] Creating required directories..."
mkdir -p "$TRIGGER_DIR"
chmod 755 "$TRIGGER_DIR"

echo "[2/4] Setup steamlibrary.conf..."
wget -q --show-progress -O "$CONF_TARGET" "$CONF_URL"

echo "[3/4] Setup steamlibrary.init..."
wget -q --show-progress -O "$INIT_SCRIPT_TARGET" "$INIT_SCRIPT_URL"
chmod 755 "$INIT_SCRIPT_TARGET"

echo "[4/4] Appending PAM configuration (using 'optional')..."
for pam_file in "${PAM_FILES[@]}"; do
    echo "$PAM_CONFIG_LINE" | tee -a "$pam_file" >/dev/null
done

# --- Completion ---
echo
echo ">>> Setup Complete <<<"
echo "IMPORTANT:"
echo "1. Review the appended lines in PAM file(s):"
printf '   %s\n' "${PAM_FILES[@]}"
echo "2. If login fails or mounts don't work after relogin, you might need"
echo "   to change 'optional' to 'required' in the PAM file(s)."
echo "3. A full **logout and login** (or reboot) is required for changes to take effect."
echo "4. This setup was tested on Debian-based systems. Check logs if issues occur:"
echo "   sudo journalctl -t steamlibrary.init"
echo

exit 0