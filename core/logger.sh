#!/bin/bash

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- LOGGING FUNCTIONS ---

function log_header() {
    echo -e "\n${BLUE}${BOLD}=== $1 ===${NC}"
}

function log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

function log_success() {
    echo -e "${GREEN}[OK]${NC}   $1"
}

function log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERR]${NC}  $1"
}

function log_step() {
    echo -e "${BLUE} > ${NC} $1"
}

# --- GLOBAL UTILITIES ---

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