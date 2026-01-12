#!/bin/bash
# CORE: Environment Loader
# Purpose: Establishes paths and loads foundational libraries.

# 1. Establish Root Context
 CURRENT_SCRIPT_PATH="$(readlink -f "$0")"
 export ONYX_ROOT="$(dirname "$(dirname "$CURRENT_SCRIPT_PATH")")"

#CURRENT_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
#export ONYX_ROOT="$(dirname "$(dirname "$CURRENT_SCRIPT_PATH")")"

# 2. Fallback for standard installation
[[ -z "$ONYX_ROOT" || "$ONYX_ROOT" == "/" ]] && export ONYX_ROOT="/opt/onyx"

# 3. Load Global Foundation
source "$ONYX_ROOT/core/functions.sh"
source "$ONYX_ROOT/core/logger.sh"

# 4. Discover Hardware and Enroll
source "$ONYX_ROOT/modules/network/discovery.sh"
discover_hardware # Finds WAN and populates interfaces in hardening.yml
enroll_hardware # Enrolls the Hardware with default 'off'

# 5. Initialize Variables
source "$ONYX_ROOT/vars.sh"