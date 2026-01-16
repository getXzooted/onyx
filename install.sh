#!/bin/bash
# ONYX INSTALLER - The entry point. Sets up the environment and triggers the CLI.

# 1. Detect Path
USER_ID=${SUDO_USER:-$USER}
INSTALL_DIR="/opt/onyx"
CURRENT_DIR=$(pwd)

# 2. Check Root
if [[ $EUID -ne 0 ]]; then
    echo "Error: Onyx must be installed as root. Try: sudo ./install.sh"
    exit 1
fi

# 3. Move/Clone to /opt/onyx (The Standard Location) - If we are not already in /opt/onyx, we copy ourselves there.
if [[ "$CURRENT_DIR" != "$INSTALL_DIR" ]]; then
    
    # Backup existing config if it exists before copying
    if [ -d "$INSTALL_DIR/config/" ]; then
        mv "$INSTALL_DIR/config/" /tmp/onyx/config/
    fi

    # Remove existing installation
    if [ -d "$INSTALL_DIR" ]; then
        echo "Removing existing Onyx installation at $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
    fi

    # Install Onyx
    echo "Installing Onyx to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
    cp -r . "$INSTALL_DIR"
    
    # Restore the backup config if it existed
    if [ -d /tmp/onyx/config/ ]; then
        mv /tmp/onyx/config/ "$INSTALL_DIR/config/"
        rm -rf /tmp/onyx/config/
    fi

    # Fix permissions
    chmod +x "$INSTALL_DIR/bin/onyx"
    chmod +x "$INSTALL_DIR/install.sh"
    find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
fi

# 4. Symlink the CLI - This allows you to type 'sudo onyx' from anywhere.
if [ ! -L "/usr/local/bin/onyx" ]; then
    echo "Creating 'onyx' command link..."
    ln -s "$INSTALL_DIR/bin/onyx" /usr/local/bin/onyx
fi

# 5. If missing or incorrect, install the Go binary:
if yq --version &>/dev/null && [ "$(yq --version | cut -d' ' -f4 | cut -d'.' -f1)" -lt 4 ]; then
    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm -O /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
fi

# 6. Handover to the CLI Controller
echo "Handing over to Onyx Controller..."
/usr/local/bin/onyx install