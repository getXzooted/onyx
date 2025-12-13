#!/bin/bash
# CORE: Config Parser
# Reads config/onyx.yml and converts YAML keys to Bash variables.
# Example: "vpn_endpoint: 1.2.3.4" -> export ONYX_VPN_ENDPOINT="1.2.3.4"

function load_config() {
    local CONFIG_FILE="$ONYX_ROOT/config/onyx.yml"

    if [ ! -f "$CONFIG_FILE" ]; then
        log_warning "Configuration file not found at $CONFIG_FILE"
        return 1
    fi

    log_step "Loading configuration..."

    # Read the file line by line
    while IFS=':' read -r key value; do
        # 1. Ignore comments (#) and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        # 2. Extract Key (Trim spaces, remove \r)
        key=$(echo "$key" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 3. Extract Value (The Heavy Lifting)
        # - Remove inline comments (#...)
        # - Remove Windows \r
        # - Trim leading/trailing whitespace
        # - Remove surrounding quotes ("" or '')
        value=$(echo "$value" | sed 's/#.*//' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//")
        
        # 4. Convert to Upper Case Variable (e.g., vpn_port -> ONYX_VPN_PORT)
        # We prefix with ONYX_ to avoid conflicts with system variables
        local var_name="ONYX_${key^^}"

        # 5. Export the variable so other scripts can see it
        export "$var_name"="$value"
        
        # Debug line (Uncomment to see what is being loaded)
        # echo "Loaded: $var_name = $value"

    done < "$CONFIG_FILE"

    log_success "Configuration loaded."
}