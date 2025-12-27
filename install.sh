#!/bin/bash
# ONYX INSTALLER
# The entry point. Sets up the environment and triggers the CLI.

# 1. Detect Path
USER_ID=${SUDO_USER:-$USER}
INSTALL_DIR="/opt/onyx"
CURRENT_DIR=$(pwd)

echo "=== ONYX INSTALLER ==="

# 2. Check Root
if [[ $EUID -ne 0 ]]; then
    echo "Error: Onyx must be installed as root. Try: sudo ./install.sh"
    exit 1
fi

# 3. Move/Clone to /opt/onyx (The Standard Location)
# If we are not already in /opt/onyx, we copy ourselves there.
if [[ "$CURRENT_DIR" != "$INSTALL_DIR" ]]; then
    echo "Installing Onyx to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
    cp -r . "$INSTALL_DIR"

    # Backup existing config if it exists before copying
    if [ -f "$INSTALL_DIR/config/onyx.yml" ]; then
        cp "$INSTALL_DIR/config/onyx.yml" /tmp/onyx.yml.bak
    fi

    mkdir -p "$INSTALL_DIR"
    cp -r . "$INSTALL_DIR"
    
    # Restore the backup
    if [ -f /tmp/onyx.yml.bak ]; then
        mv /tmp/onyx.yml.bak "$INSTALL_DIR/config/onyx.yml"
        log_success "Preserved existing onyx.yml configuration."
    fi

    # Fix permissions
    chmod +x "$INSTALL_DIR/bin/onyx"
    chmod +x "$INSTALL_DIR/install.sh"
    find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
fi

# 4. Symlink the CLI
# This allows you to type 'sudo onyx' from anywhere.
if [ ! -L "/usr/local/bin/onyx" ]; then
    echo "Creating 'onyx' command link..."
    ln -s "$INSTALL_DIR/bin/onyx" /usr/local/bin/onyx
fi

# 5. Handover to the CLI Controller
echo "Handing over to Onyx Controller..."
/usr/local/bin/onyx install