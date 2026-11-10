#!/usr/bin/env bash
# OSYS3030 - Network Appliance Read-Only Verification Suite
# Ubuntu 24.04 | SSH 2222 | BIND9 | Kea DHCPv4 | UFW + NAT
# Usage: sudo ./scripts/verify_appliance.sh

set -u
export LC_ALL=C

if (( EUID != 0 )); then
    printf 'Error: run with sudo so UFW, iptables and service checks can be read.\n' >&2
    exit 2
fi

PASS_COUNT=0
FAIL_COUNT=0
if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'
    RED=$'\033[0;31m'
    NC=$'\033[0m'
else
    GREEN=''
    RED=''
    NC=''
fi

check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '  %-58s [ %sPASS%s ]\n' "$description" "$GREEN" "$NC"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf '  %-58s [ %sFAIL%s ]\n' "$description" "$RED" "$NC"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Capture output before searching so grep -q cannot trigger SIGPIPE errors.
output_has_line() {
    local expected="$1" result
    shift
    result="$("$@" 2>/dev/null)" || return 1
    grep -Fqx -- "$expected" <<< "$result"
}

output_matches() {
    local expression="$1" result
    shift
    result="$("$@" 2>/dev/null)" || return 1
    grep -Eq -- "$expression" <<< "$result"
}

file_contains() {
    local file="$1" value="$2"
    [[ -f "$file" ]] && grep -Fq -- "$value" "$file"
}

printf '============================================================\n'
printf '  OSYS3030 Appliance Health & Verification Suite\n'
printf '============================================================\n'

printf '\n--- 1. Network prerequisites ---\n'
check 'WAN ens18 has 10.20.1.120/23' output_matches 'inet 10[.]20[.]1[.]120/23' ip -o -4 addr show dev ens18
check 'LAN ens19 has 10.101.0.250/24' output_matches 'inet 10[.]101[.]0[.]250/24' ip -o -4 addr show dev ens19

printf '\n--- 2. BIND9 DNS ---\n'
check 'BIND9 named service active' systemctl is-active --quiet named
check 'BIND9 syntax valid (named-checkconf)' named-checkconf
check 'innovate.lab zone valid' named-checkzone innovate.lab /etc/bind/db.innovate.lab
check 'DNS listening on UDP port 53' output_matches ':53[[:space:]]' ss -H -lun
check 'web.innovate.lab resolves to LAN address' output_has_line '10.101.0.250' dig @127.0.0.1 web.innovate.lab A +short +time=2 +tries=1

printf '\n--- 3. Kea DHCPv4 ---\n'
check 'Kea DHCPv4 service active' systemctl is-active --quiet kea-dhcp4-server
# The service runs as _kea; on this host a root-only -t check failed.
check 'Kea syntax valid (run as _kea)' runuser -u _kea -- /usr/sbin/kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
check 'DHCP listening on UDP port 67' output_matches ':67[[:space:]]' ss -H -lun

printf '\n--- 4. SSH hardening ---\n'
check 'SSH service or socket active' bash -c 'systemctl is-active --quiet ssh || systemctl is-active --quiet ssh.socket'
check 'OpenSSH configuration syntax valid' /usr/sbin/sshd -t
check 'SSH configured for TCP port 2222' output_has_line 'port 2222' /usr/sbin/sshd -T
check 'Root login disabled' output_has_line 'permitrootlogin no' /usr/sbin/sshd -T
check 'Password authentication disabled' output_has_line 'passwordauthentication no' /usr/sbin/sshd -T
check 'SSH listening on TCP port 2222' output_matches ':2222[[:space:]]' ss -H -ltn

printf '\n--- 5. UFW firewall and routing ---\n'
check 'UFW firewall active' output_has_line 'Status: active' ufw status
check 'IPv4 forwarding enabled' output_has_line '1' sysctl -n net.ipv4.ip_forward
check 'NAT rule stored in UFW before.rules' file_contains /etc/ufw/before.rules '-A POSTROUTING -s 10.101.0.0/24 -o ens18 -j MASQUERADE'
check 'Active NAT MASQUERADE rule correct' iptables -t nat -C POSTROUTING -s 10.101.0.0/24 -o ens18 -j MASQUERADE
check 'UFW permits SSH 2222 inbound' output_matches '^2222/tcp.*ALLOW' ufw status
check 'UFW permits DNS on LAN' output_matches '^53([[:space:]]|/).*on ens19[[:space:]]+ALLOW' ufw status
check 'UFW permits DHCP on LAN' output_matches '^67/udp on ens19[[:space:]]+ALLOW' ufw status
check 'UFW allows LAN-to-WAN forwarding' output_matches '^Anywhere on ens18[[:space:]]+ALLOW FWD[[:space:]]+10[.]101[.]0[.]0/24 on ens19' ufw status

printf '\n============================================================\n'
printf '  Results: %d PASS, %d FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
if (( FAIL_COUNT == 0 )); then
    printf '  %sAll appliance checks passed.%s\n' "$GREEN" "$NC"
    exit 0
else
    printf '  %sReview failed checks against the configuration guides.%s\n' "$RED" "$NC"
    exit 1
fi

