#!/bin/bash
# CORE: ONYX FOUNDATIONAL FIREWALL RULES
# Purpose: Establish baseline firewall rules for system integrity and VPN operation.

# FOUNDATION
source $MODULES_DIR/firewall/foundation/established_related.sh
source $MODULES_DIR/firewall/foundation/localhost_access.sh
source $MODULES_DIR/firewall/foundation/dhcp_access.sh
source $MODULES_DIR/firewall/foundation/rfc1918_access.sh
source $MODULES_DIR/firewall/foundation/vpn_transport.sh
source $MODULES_DIR/firewall/foundation/tunnel_integrity.sh



# KERNEL

source $MODULES_DIR/firewall/kernal/log_martians.sh
source $MODULES_DIR/firewall/kernal/ip_forwarding.sh
source $MODULES_DIR/firewall/kernal/disable_ipv6.sh
source $MODULES_DIR/firewall/kernal/ignore_redirects.sh
source $MODULES_DIR/firewall/kernal/no_send_redirects.sh
source $MODULES_DIR/firewall/kernal/tcp_timestamps.sh
source $MODULES_DIR/firewall/kernal/qname_minimization.sh
source $MODULES_DIR/firewall/kernal/icmp_ratelimit.sh
source $MODULES_DIR/firewall/kernal/arp_guard.sh
source $MODULES_DIR/firewall/kernal/rp_filter.sh
source $MODULES_DIR/firewall/kernal/tcp_syncookies.sh
source $MODULES_DIR/firewall/kernal/kernal_sysrq.sh
source $MODULES_DIR/firewall/kernal/icmp_echo_ignore.sh








