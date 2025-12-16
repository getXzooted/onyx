#!/bin/bash
# MODULE: Core > Update Manager
# Handles surgical updates of configuration without full reprovisioning.

function core_update() {
    local USER_PATH="$1"
    local UPDATE_SOURCE=""
    local RESTART_WIFI=false
    local RESTART_VPN=false

    log_header "ONYX UPDATE MANAGER"

    # --- 1. SOURCE DETECTION ---
    if [ -n "$USER_PATH" ]; then
        # Case A: User provided a specific path (Desktop Mode)
        if [ -f "$USER_PATH" ]; then
            UPDATE_SOURCE="$USER_PATH"
        else
            log_error "File not found: $USER_PATH"
            return 1
        fi
    else
        # Case B: Auto-detect in boot (Headless Mode)
        # We check firmware first (Pi 5 standard), then root boot
        if [ -f "/boot/firmware/onyx_update.yml" ]; then
            UPDATE_SOURCE="/boot/firmware/onyx_update.yml"
        elif [ -f "/boot/onyx_update.yml" ]; then
            UPDATE_SOURCE="/boot/onyx_update.yml"
        else
            log_info "No update file found. Usage: sudo onyx update [path/to/file.yml]"
            return 0
        fi
    fi

    log_step "Reading update from: $UPDATE_SOURCE"

    # --- 2. PARSING (The Surgical Extraction) ---
    # We grep the values. If the key isn't in the file, the var stays empty.
    # We use 'cut' to strip quotes and whitespace.
    
    NEW_SSID=$(grep "^wifi_ssid:" "$UPDATE_SOURCE" | cut -d ':' -f 2 | tr -d ' "' | tr -d "'")
    NEW_PASS=$(grep "^wifi_password:" "$UPDATE_SOURCE" | cut -d ':' -f 2 | tr -d ' "' | tr -d "'")
    
    # (Future: Add parsing for VPN keys or DNS here)

    # --- 3. EXECUTION (The Patch) ---
    
    # --- WiFi Patching ---
    if [ -n "$NEW_SSID" ]; then
        log_action "Updating SSID to: $NEW_SSID"
        
        # 1. Update Master Record (onyx.yml)
        # We look for the line starting with "wifi_ssid:" and replace the whole line
        sed -i "s/^wifi_ssid:.*/wifi_ssid: \"$NEW_SSID\"/" /etc/onyx/onyx.yml
        
        # 2. Update Live Config (hostapd.conf)
        # We look for "ssid=" and replace it.
        sed -i "s/^ssid=.*/ssid=$NEW_SSID/" /etc/hostapd/hostapd.conf
        
        RESTART_WIFI=true
    fi

    if [ -n "$NEW_PASS" ]; then
        log_action "Updating WiFi Password"
        
        # 1. Update Master Record
        sed -i "s/^wifi_password:.*/wifi_password: \"$NEW_PASS\"/" /etc/onyx/onyx.yml
        
        # 2. Update Live Config
        sed -i "s/^wpa_passphrase=.*/wpa_passphrase=$NEW_PASS/" /etc/hostapd/hostapd.conf
        
        RESTART_WIFI=true
    fi

    # --- 4. APPLY CHANGES ---
    
    if [ "$RESTART_WIFI" = true ]; then
        log_step "Applying WiFi changes..."
        systemctl restart hostapd
        if systemctl is-active hostapd &>/dev/null; then
            log_success "WiFi settings updated successfully."
        else
            log_error "WiFi failed to restart. Check password length (min 8 chars)."
        fi
    else
        log_info "No WiFi changes detected."
    fi

    # --- 5. CLEANUP ---
    # If this was a boot file, we rename it to prevent loops on next boot.
    if [[ "$UPDATE_SOURCE" == "/boot"* ]]; then
        mv "$UPDATE_SOURCE" "$UPDATE_SOURCE.applied"
        log_info "Update file renamed to .applied"
    fi
}