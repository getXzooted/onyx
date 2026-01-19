#!/bin/bash
# CORE: ONYX GRAPH SCRIPT
# Purpose: Displays live ASCII graphs of the WireGuard tunnel.

# Check for dependencies
if ! command -v nload &>/dev/null; then
    apt-get install -y nload bmon &>/dev/null
fi

# The "Live" View: ASCII Graphs of the WireGuard Tunnel
# This flexes on the commercial GUIs by being 100% SSH-native.
nload -u M -i 1024 -o 1024 wg0