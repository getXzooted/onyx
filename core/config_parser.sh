#!/bin/bash
# CORE: Config Parser (SDN Agnostic Engine)
# Purpose: Dynamically maps any YAML key to ONYX_ environment variables.
# Version: Optimized for yq v4.5 (Properties Mode)

function load_config() {
    local CONFIG_FILE="$ONYX_ROOT/config/onyx.yml"
    local YQ_BIN="/usr/local/bin/yq"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_warning "Configuration file not found at $CONFIG_FILE"
        return 1
    fi

    log_step "Engaging SDN Config Engine..."

    # 1. Use 'properties' output format to flatten YAML (Compatible with yq 4.5)
    # This automatically handles booleans (true) and integers (20) correctly.
    # Output is produced as 'path.to.key = value'
    local FLAT_CONFIG
    FLAT_CONFIG=$($YQ_BIN e '.' -o=props "$CONFIG_FILE" 2>/dev/null)

    if [[ -z "$FLAT_CONFIG" ]]; then
        log_error "Config Engine: No data produced. Check yq binary or YAML syntax."
        return 1
    fi

    # 2. Iterate through the results
    # yq properties output uses '=', so we read accordingly
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue

        # 3. Clean Key: Replace dots with underscores and force Uppercase
        # 'networks.parent' -> 'ONYX_NETWORKS_PARENT'
        local clean_key=$(echo "$key" | tr '.' '_' | xargs)
        local var_name="ONYX_${clean_key^^}"

        # 4. Clean Value: Strip quotes and Windows carriage returns (\r)
        value=$(echo "$value" | tr -d '\r' | xargs)
        value="${value%\"}"; value="${value#\"}"
        value="${value%\'}"; value="${value#\'}"

        # 5. REPAIR TRUNCATED KEYS (WireGuard Fix)
        if [[ "$var_name" == "ONYX_VPN_PRIVATE_KEY" || "$var_name" == "ONYX_VPN_PUBKEY" ]]; then
             local clean_val=$(echo "$value" | tr -d '[:space:]')
             if [ ${#clean_val} -eq 43 ]; then value="${clean_val}="; fi
        fi

        # 6. EXPORT: Agnostically inject into environment
        # Now your log_info and debug sleep will trigger
        export "$var_name"="$value"
        log_info "Config Engine: Set $var_name to $value"
        sleep 1
    done <<< "$FLAT_CONFIG"

    log_success "Configuration variables (DNS, VPN, SDN) synchronized."
}