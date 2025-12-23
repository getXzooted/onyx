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

# 3. Initialize Variables
source "$ONYX_ROOT/vars.sh"

# 4. Load Global Foundation
source "$ONYX_ROOT/core/functions.sh"
source "$ONYX_ROOT/core/logger.sh"