#!/bin/bash
# CORE: Environment Loader
# Purpose: Establishes paths and loads foundational libraries.

# 1. Fallback for standard installation
[[ -z "$ONYX_ROOT" || "$ONYX_ROOT" == "/" ]] && export ONYX_ROOT="/opt/onyx"

# 2. Initialize Variables
source "$ONYX_ROOT/vars.sh"

# 3. Load Global Foundation
source "$ONYX_ROOT/core/functions.sh"
source "$ONYX_ROOT/core/logger.sh"

# 4. Load Source Dependencies 

# Load Functions Library
if [ -f "$CORE_DIR/functions.sh" ]; then
    source "$CORE_DIR/functions.sh"
else
    echo "CRITICAL ERROR: Functions library not found at $CORE_DIR/functions.sh"
    exit 1
fi

# Logger is required for all scripts
if [ -f "$CORE_DIR/logger.sh" ]; then
    source "$CORE_DIR/logger.sh"
else
    echo "CRITICAL ERROR: Logger not found at $CORE_DIR/logger.sh"
    exit 1
fi

# Load Config Parser to read onyx.yml
if [ -f "$CORE_DIR/config_parser.sh" ]; then
    source "$CORE_DIR/config_parser.sh"
    # Run the load function immediately
    load_config
else
    log_warning "Config parser not found. Running with defaults."
fi

# 5. Discover Hardware and Enroll
# source "$ONYX_ROOT/modules/network/discovery.sh"
# discover_hardware # Finds WAN and populates interfaces in hardening.yml
# enroll_hardware # Enrolls the Hardware with default 'off'