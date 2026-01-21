#!/bin/bash
# CORE: ONYX FOUNDATIONAL FIREWALL RULES
# Purpose: Establish baseline firewall rules for system integrity and VPN operation.

source $MODULES_DIR/firewall/foundation/established_related.sh
source $MODULES_DIR/firewall/foundation/localhost_access.sh
source $MODULES_DIR/firewall/foundation/dhcp_access.sh
source $MODULES_DIR/firewall/foundation/rfc1918_access.sh
source $MODULES_DIR/firewall/foundation/vpn_transport.sh
source $MODULES_DIR/firewall/foundation/tunnel_integrity.sh