#!/bin/bash
# CORE: Global Onyx Functions
# Purpose: Foundational functions used across the Onyx system.

# --- GLOBAL UTILITIES ---

function check_root() {
    [[ $EUID -ne 0 ]] && echo -e "${RED}[ERR]${NC} Must run as root." && exit 1
}

function check_env() {
    # Verify the environment loader was successful
    if [[ -z "$ONYX_ROOT" ]]; then
        echo "CRITICAL: Environment not loaded. Source core/env.sh first."
        exit 1
    fi
}

function load_user_config() {
    # Hand off to the parser to turn YAML into ONYX_ variables
    if [[ -f "$CORE_DIR/config_parser.sh" ]]; then
        source "$CORE_DIR/config_parser.sh"
        load_config
    fi
}

function repair_key() {
    local k=$(echo "$1" | tr -d ' \n\r')
    # We don't care what the last letters are.
    # We ONLY care if the '=' is missing.
    if [[ -n "$k" && "$k" != *"=" ]]; then
        echo "${k}="
    else
        echo "$k"
    fi
}

function old_parse_wg_file() {
    local source_file="$1"
    log_info "Parsing WireGuard config from $source_file..."

    # 1. Extract values using grep/awk (Robust against spaces)
    local address=$(grep -m1 "^Address" "$source_file" | cut -d '=' -f2 | xargs)
    local full_endpoint=$(grep -m1 "^Endpoint" "$source_file" | cut -d '=' -f2 | xargs)
    local endpoint_ip=$(echo "$full_endpoint" | cut -d ':' -f1)
    local endpoint_port=$(echo "$full_endpoint" | cut -d ':' -f2)
    local priv_key=$(grep -m1 "^PrivateKey" "$source_file" | cut -d '=' -f2 | xargs)
    local pub_key=$(grep -m1 "^PublicKey" "$source_file" | cut -d '=' -f2 | xargs)
    
    # 2. Repair Keys (add '=' back if missing)
    local priv_key=$(repair_key "$priv_key")
    local pub_key=$(repair_key "$pub_key")
    
    # 3. Validate extracted values

    if [[ -z "$priv_key" || -z "$full_endpoint" ]]; then
        log_error "Failed to parse required fields from wg0.conf"
        return 1
    fi

    # 4. Extract every OTHER key-value pair from the existing yml
    local preserved_settings=""
    if [ -f "$TARGET_CONFIG" ]; then
        # This keeps your Android Auto, VLAN, and system settings intact
        preserved_settings=$(grep -v "^vpn_" "$TARGET_CONFIG")
    fi

    # 5. Use CAT to write the merged file in one shot
    # This prevents any shell mangling of the trailing "=" characters
    log_step "Rebuilding onyx.yml with cat merge..."
    cat <<EOF > "$TARGET_CONFIG"
# --- VPN SETTINGS (Repaired & Merged) ---
vpn_private_key: "$priv_key"
vpn_pubkey: "$pub_key"
vpn_endpoint: "$endpoint_ip"
vpn_port: "$endpoint_port"
vpn_address: "$address"

# --- PRESERVED CONFIGURATION ---
$preserved_settings
EOF

    return 0
}


function parse_wg_file() {
    local source_file="$1"
    log_info "Parsing WireGuard config from $source_file..."

    # 1. Extract values using your existing robust grep logic
    local address=$(grep -m1 "^Address" "$source_file" | cut -d '=' -f2 | xargs)
    local full_endpoint=$(grep -m1 "^Endpoint" "$source_file" | cut -d '=' -f2 | xargs)
    local endpoint_ip=$(echo "$full_endpoint" | cut -d ':' -f1)
    local endpoint_port=$(echo "$full_endpoint" | cut -d ':' -f2)
    local priv_key=$(grep -m1 "^PrivateKey" "$source_file" | cut -d '=' -f2 | xargs)
    local pub_key=$(grep -m1 "^PublicKey" "$source_file" | cut -d '=' -f2 | xargs)
    
    # 2. Repair Keys (Base64 padding)
    priv_key=$(repair_key "$priv_key")
    pub_key=$(repair_key "$pub_key")
    
    # 3. Validate extracted values
    if [[ -z "$priv_key" || -z "$full_endpoint" ]]; then
        log_error "Failed to parse required fields from wg0.conf"
        return 1
    fi

    # 4. Use YQ for In-Place Injection
    # This preserves comments, structure, and all other non-vpn keys (AA, VLANs, etc.)
    log_step "Injecting VPN state into onyx.yml..."
    
    # Ensure TARGET_CONFIG exists before editing
    if [ ! -f "$TARGET_CONFIG" ]; then
        log_error "Target config $TARGET_CONFIG missing. Creating from template..."
        cp "$ONYX_ROOT/config/onyx.yml" "$TARGET_CONFIG"
    fi

    # The pipe '|' in yq allows us to update all fields in a single pass
    yq -i ".vpn_private_key = \"$priv_key\" | 
           .vpn_pubkey = \"$pub_key\" | 
           .vpn_endpoint = \"$endpoint_ip\" | 
           .vpn_port = \"$endpoint_port\" | 
           .vpn_address = \"$address\"" "$TARGET_CONFIG"

    echo "$priv_key $pub_key $endpoint_ip $endpoint_port $address"

    if [ $? -eq 0 ]; then
        log_success "VPN credentials synchronized successfully."
        return 0
    else
        log_error "yq failed to write to $TARGET_CONFIG"
        return 1
    fi
}


function show_usage() {
    echo -e "\n${BOLD}Onyx Gateway${NC} - Privacy Focused Router"
    echo -e "Usage: sudo onyx [COMMAND]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}install${NC}    bootstrap  -> Installs all dependencies and software."
    echo -e "  ${GREEN}provision${NC}  configure  -> Ingests keys and locks down the system."
    echo -e "  ${GREEN}config${NC}     update     -> Re-applies settings from onyx.yml."
    echo -e "  ${GREEN}status${NC}     check      -> Shows VPN connection and security status."
    echo -e "  ${GREEN}network${NC}    [cmd]      -> Managed Desired State Security (audit, repair, panic)."
    echo -e "  ${GREEN}firmware${NC}   update     -> Pulls latest code while preserving .yml configs."
    echo ""
}