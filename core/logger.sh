#!/bin/bash
# CORE: Logger Functions
# Purpose: Standardized logging output with colors and formatting.

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