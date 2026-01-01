#!/bin/bash
# MODULE: Provisioning > Ingest
# Checks boot partition for 'onyx.yml' OR 'wg0.conf'.
# Supports both Advanced (YAML) and Easy (WireGuard file) modes.

function provision_ingest() {

    # This logic sets the variables that the rest of the function uses.
    if [ -n "$1" ]; then
        if [[ "$1" == *".yml" ]]; then
            CONFIG_SOURCE="$1"
            WG_SOURCE="" 
        else
            WG_SOURCE="$1"
            CONFIG_SOURCE="" 
        fi
    fi

    local PROVISION_NEEDED=false

    # --- CONFIG SYNCHRONIZATION ---
    log_header "ONYX CONFIG SYNCHRONIZATION"
    
    # SCENARIO A: User dropped a full onyx.yml
    if [ -f "$CONFIG_SOURCE" ]; then
        log_header "NEW ONYX CONFIG DETECTED"
        mv "$CONFIG_SOURCE" "$TARGET_CONFIG"
        PROVISION_NEEDED=true
    fi

    # SCENARIO B: User dropped a raw wg0.conf (Proton/Mullvad style)
    if [ -f "$WG_SOURCE" ]; then
        log_header "NEW WIREGUARD FILE DETECTED"
        parse_wg_file "$WG_SOURCE"
        if [ $? -eq 0 ]; then
            mv "$WG_SOURCE" "$WG_SOURCE.bak" # Rename source so we don't loop
            PROVISION_NEEDED=true
        fi
    fi

    # SCENARIO C: User dropped an onyx_update.yml file (Partial Update)
    if [ -f "$BOOT_DIR/onyx_update.yml" ]; then
        log_header "NEW ONYX UPDATE CONFIG DETECTED"
        $ONYX_ROOT/core/update.sh "$BOOT_DIR/onyx_update.yml"
        delete "$BOOT_DIR/onyx_update.yml"
        PROVISION_NEEDED=true
    fi

    # If nothing new found, exit
    if [ "$PROVISION_NEEDED" = false ]; then
        return 0
    fi

    # --- LOAD NEW CONFIG ---
    load_config
}

provision_ingest