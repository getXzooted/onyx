#!/bin/bash
# CORE: INSTALL DEPLOYMENT MODULE
# Purpose: Backs up existing config, installs Onyx to /opt/onyx, and restores config.

function onyx_deploy() {
    
    local MODE="${1:-backup}"
    local BACKUP_PATH="/tmp/onyx/config"

    # Only proceed if we aren't already running from the target directory
    if [[ "$CURRENT_DIR" != "$INSTALL_DIR" ]]; then 

        # 1. Backup existing config if it exists before copying
        if [[ "$MODE" == "backup" ]] && [ -d "$INSTALL_DIR/config" ]; then
            if [ ! -d $BACKUP_PATH ]; then
            #    echo "Backing up existing Onyx configuration..."
            #    mkdir -p $BACKUP_PATH
            else
                echo "Removing old backup at $BACKUP_PATH..."
                rm -rf $BACKUP_PATH
            fi
            echo "Backing up config from $INSTALL_DIR/config/ to $BACKUP_PATH..."
            mv "$INSTALL_DIR/config" $BACKUP_PATH
        fi

        # 2. Remove existing installation
        if [ -d "$INSTALL_DIR" ]; then
            echo "Removing existing Onyx installation at $INSTALL_DIR..."
            rm -rf "$INSTALL_DIR"
        fi

        # 3. Install Onyx
        echo "Installing Onyx to $INSTALL_DIR..."
        mkdir -p "$INSTALL_DIR"
        cp -r . "$INSTALL_DIR"
        
        # 4. Restore the backup config if it existed
        if [ -d $BACKUP_PATH ]; then
            echo "Restoring configuration from backup..."
            rm -rf "$INSTALL_DIR/config"
            mv $BACKUP_PATH "$INSTALL_DIR/config"
            rm -rf $BACKUP_PATH
        fi

        # 5. Fix permissions
        chmod +x "$INSTALL_DIR/bin/onyx"
        chmod +x "$INSTALL_DIR/install.sh"
        find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
    fi
}