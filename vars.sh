#!/bin/bash
# CORE: System Variables
# Purpose: Static constants and system-wide defaults.

# --- Project Metadata ---
export ONYX_VERSION="2.1.0-refactor"
export ONYX_USER="root"

# --- Networking Defaults ---
export ONYX_DEFAULT_HOTSPOT_IP="10.3.141.1"
export ONYX_DEFAULT_VLAN_ID=20

# --- System Paths ---
export CORE_DIR="$ONYX_ROOT/core"
export MODULES_DIR="$ONYX_ROOT/modules"
export CONFIG_DIR="$ONYX_ROOT/config"
export ONYX_YAML="$CONFIG_DIR/onyx.yml"
export HARDENING_YAML="$CONFIG_DIR/hardening.yml"
export ONYX_LOG_RAM="/var/log/onyx"
export ONYX_RESUME_MARKER="/var/opt/onyx_resume_pending"


# --- COLORS ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color