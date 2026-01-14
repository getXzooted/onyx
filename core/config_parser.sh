#!/bin/bash
# CORE: Config Parser (Agnostic yq Engine)
# Reads config/onyx.yml and dynamically builds variables from any YAML path.

function load_config() {
    local CONFIG_FILE="$ONYX_ROOT/config/onyx.yml"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_warning "Configuration file not found at $CONFIG_FILE"
        return 1
    fi

    log_step "Engaging Agnostic Config Engine..."

    # 1. Use yq to extract every scalar (value) and its full path
    # This flattens the YAML: "networks.segments[0].name" becomes "NETWORKS_SEGMENTS_0_NAME"
    local FLAT_CONFIG
    FLAT_CONFIG=$(yq e '.. | select(tag == "!!scalar") | (path | join("_") | upcase) + "=" + .' "$CONFIG_FILE" 2>/dev/null)

    # 2. Iterate through the flattened results
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue

        # 3. Clean and Prefix the Variable Name
        # Replaces any non-alphanumeric characters with underscores just in case
        local clean_key=$(echo "$key" | tr -c '[:alnum:]' '_')
        local var_name="ONYX_${clean_key^^}"

        # 4. Strip surrounding quotes from the value
        value="${value#\"}"; value="${value%\"}"
        value="${value#\'}"; value="${value%\'}"

        # 5. REPAIR TRUNCATED KEYS (WireGuard Base64 check)
        # Preserving your custom logic for the VPN keys
        if [[ "$var_name" == "ONYX_VPN_PRIVATE_KEY" || "$var_name" == "ONYX_VPN_PUBKEY" ]]; then
             local clean_val=$(echo "$value" | tr -d '[:space:]')
             if [ ${#clean_val} -eq 43 ]; then
                 value="${clean_val}="
             fi
        fi

        # 6. EXPORT: Agnostically inject into the environment
        export "$var_name"="$value"
        
        # log_info "Mapped: $var_name" # Useful for debugging the sync
    done <<< "$FLAT_CONFIG"

    log_success "Configuration Engine: Variable Mapping Synchronized."
}