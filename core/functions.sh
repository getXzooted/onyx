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