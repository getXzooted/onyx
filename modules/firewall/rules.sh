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

# SYSTEM
source $MODULES_DIR/firewall/system/bluetooth_lockdown.sh
source $MODULES_DIR/firewall/system/physical_stealth.sh

# KERNEL
source $MODULES_DIR/firewall/kernel/log_martians.sh
source $MODULES_DIR/firewall/kernel/ip_forwarding.sh
source $MODULES_DIR/firewall/kernel/disable_ipv6.sh
source $MODULES_DIR/firewall/kernel/ignore_redirects.sh
source $MODULES_DIR/firewall/kernel/no_send_redirects.sh
source $MODULES_DIR/firewall/kernel/tcp_timestamps.sh
source $MODULES_DIR/firewall/kernel/qname_minimization.sh
source $MODULES_DIR/firewall/kernel/icmp_ratelimit.sh
source $MODULES_DIR/firewall/kernel/arp_guard.sh
source $MODULES_DIR/firewall/kernel/rp_filter.sh
source $MODULES_DIR/firewall/kernel/tcp_syncookies.sh
source $MODULES_DIR/firewall/kernel/kernel_sysrq.sh
source $MODULES_DIR/firewall/kernel/icmp_echo_ignore.sh

# NETWORK
source $MODULES_DIR/firewall/network/honeypot_trap.sh
source $MODULES_DIR/firewall/network/tarpit_trap.sh
#source $MODULES_DIR/firewall/network/geo_blocking.sh
#source $MODULES_DIR/firewall/network/unbound_filtered.sh
source $MODULES_DIR/firewall/network/string_telemetry_filter.sh
source $MODULES_DIR/firewall/network/mss_clamping.sh
source $MODULES_DIR/firewall/network/webrtc_stun_block.sh
source $MODULES_DIR/firewall/network/source_port_randomization.sh
source $MODULES_DIR/firewall/network/discovery_stealth.sh
source $MODULES_DIR/firewall/network/syn_proxy.sh
source $MODULES_DIR/firewall/network/tcp_flag_filter.sh
source $MODULES_DIR/firewall/network/vlan_isolation.sh









