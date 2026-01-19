#!/bin/bash
# CORE: ONYX INSTALLER
# Purpose: The entry point. Sets up the environment and triggers the CLI.

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
DEPLOY_MODULE="./modules/install/deploy.sh"
if [ -f "$DEPLOY_MODULE" ]; then
    echo "Deploying Onyx to $INSTALL_DIR..."
    source "$DEPLOY_MODULE"
    onyx_deploy
else
    echo "CRITICAL ERROR: Deployment module not found at $DEPLOY_MODULE"
    exit 1
fi

# 4. Symlink the CLI - This allows you to type 'sudo onyx' from anywhere.
if [ ! -L "/usr/local/bin/onyx" ]; then
    echo "Creating 'onyx' command link..."
    ln -s "$INSTALL_DIR/bin/onyx" /usr/local/bin/onyx
fi

# 5. If missing or incorrect, install the Go binary: potential to be step 3
if ! command -v yq &>/dev/null || [ "$(yq --version | cut -d' ' -f4 | cut -d'.' -f1)" -lt 4 ]; then
    echo "Installing yq YAML processor..."
    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm -O /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
fi

# 6. Handover to the CLI Controller
echo "Handing over to Onyx Controller..."
# /usr/local/bin/onyx install