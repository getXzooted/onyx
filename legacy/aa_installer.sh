#!/bin/bash
# MODULE: System > AA Installer (Script 2 Library)

function system_install_aa_binary() {
    local BIN_PATH="/usr/local/bin/android-proxy-rs"
    # This URL should point to your specific architecture's binary
    local REPO_URL="https://github.com/nimayer/android-proxy-rs/releases/latest/download/android-proxy-rs"

    log_header "DEPLOYING PROXY ENGINE"

    if [ -f "$BIN_PATH" ]; then
        log_info "Proxy binary already exists at $BIN_PATH."
        return 0
    fi

    log_step "Fetching proxy binary..."
    curl -sL "$REPO_URL" -o "$BIN_PATH"

    if [ $? -eq 0 ]; then
        chmod +x "$BIN_PATH"
        chown root:root "$BIN_PATH"
        log_success "Proxy engine deployed to $BIN_PATH."
    else
        log_error "Failed to download proxy binary. Check internet connection."
        return 1
    fi
}