#!/usr/bin/env bash
# OSYS3030 - Ubuntu 24.04 network appliance disaster recovery
# AI-generated starting point; review and test in a disposable VM first.
# Usage: sudo ./scripts/deploy_appliance.sh [--allow-ssh-change]
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="/var/backups/osys3030-appliance/$(date +%Y%m%d-%H%M%S)-$$"
ALLOW_SSH_CHANGE=0
DNS_CHANGED=0
DHCP_CHANGED=0
FW_CHANGED=0
SSH_CHANGED=0
SSH_CONTENT_CHANGED=0
SYSCTL_CHANGED=0
dns_touched=()

log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
trap 'warn "Deployment stopped at line $LINENO. Check /var/backups/osys3030-appliance/ for backups."' ERR

[[ "$EUID" -eq 0 ]] || die 'Run this script with sudo.'
(( $# <= 1 )) || die 'Usage: deploy_appliance.sh [--allow-ssh-change]'
[[ "${1:-}" == '' || "${1:-}" == '--allow-ssh-change' ]] || die 'Usage: deploy_appliance.sh [--allow-ssh-change]'
[[ "${1:-}" != '--allow-ssh-change' ]] || ALLOW_SSH_CHANGE=1

# Do not overwrite unrelated systems or alter the school's Netplan settings.
. /etc/os-release
[[ "${ID:-}" == 'ubuntu' && "${VERSION_ID:-}" == '24.04' ]] || die 'Ubuntu Server 24.04 is required.'
for file in \
    hardening/sshd_config \
    dns/named.conf.local dns/named.conf.options dns/db.innovate.lab \
    dhcp/kea-dhcp4.conf fw/before.rules; do
    [[ -f "$REPO_DIR/$file" ]] || die "Missing repository file: $file"
done

for iface in ens18 ens19; do
    ip link show "$iface" >/dev/null 2>&1 || die "Missing interface: $iface"
done
ip -o -4 addr show dev ens18 | grep -Fq '10.20.1.120/23' || die 'Set ens18 to 10.20.1.120/23 first (see root README).'
ip -o -4 addr show dev ens19 | grep -Fq '10.101.0.250/24' || die 'Set ens19 to 10.101.0.250/24 first (see root README).'

# Require explicit approval before changing live SSH port/authentication.
if [[ ! -f /etc/ssh/sshd_config ]] || ! cmp -s "$REPO_DIR/hardening/sshd_config" /etc/ssh/sshd_config; then
    SSH_CONTENT_CHANGED=1
    [[ "$ALLOW_SSH_CHANGE" -eq 1 ]] || die 'SSH config differs. Re-run from console/test VM with --allow-ssh-change after confirming a working admin SSH key.'
fi

# Only install missing packages; avoid an unnecessary apt upgrade on reruns.
packages=(openssh-server bind9 bind9-utils bind9-doc dnsutils kea-dhcp4-server ufw iptables git)
missing=()
for package in "${packages[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fqx 'install ok installed'; then
        missing+=("$package")
    fi
done
if ((${#missing[@]})); then
    log "Installing missing packages: ${missing[*]}"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
else
    log 'All required packages are installed.'
fi
getent passwd _kea >/dev/null || die 'Kea service account _kea is missing.'
getent group bind >/dev/null || die 'BIND group bind is missing.'

# Save the original only when a file must change. Backups are outside Git.
backup_file() {
    local target="$1" backup="$BACKUP_DIR$1"
    if [[ -e "$target" ]]; then
        install -d -m 0700 "$(dirname -- "$backup")"
        cp -a -- "$target" "$backup"
        log "Backed up $target"
    fi
}

# Return success when content, owner, group or mode was changed.
deploy_file() {
    local src="$1" dest="$2" owner="$3" group="$4" mode="$5"
    local existing=''
    if [[ -f "$dest" ]]; then
        existing="$(stat -c '%U:%G:%a' -- "$dest")"
        if cmp -s -- "$src" "$dest" && [[ "$existing" == "$owner:$group:$mode" ]]; then
            log "Unchanged: $dest"
            return 1
        fi
    fi
    backup_file "$dest"
    install -D -o "$owner" -g "$group" -m "$mode" -- "$src" "$dest"
    log "Installed: $dest"
    return 0
}

restore_file() {
    local dest="$1" backup="$BACKUP_DIR$1"
    if [[ -e "$backup" ]]; then cp -a -- "$backup" "$dest";
    else rm -f -- "$dest"; fi
}

# Validate the saved SSH file before installing it. Never copy host private keys.
install -d -m 0755 /run/sshd
/usr/sbin/sshd -t -f "$REPO_DIR/hardening/sshd_config" || die 'Saved SSH configuration is invalid.'
saved_ssh_settings="$(/usr/sbin/sshd -T -f "$REPO_DIR/hardening/sshd_config")"
for required in 'port 2222' 'permitrootlogin no' 'passwordauthentication no' 'pubkeyauthentication yes'; do
    grep -Fqx "$required" <<< "$saved_ssh_settings" || die "Saved SSH config must have: $required"
done
if deploy_file "$REPO_DIR/hardening/sshd_config" /etc/ssh/sshd_config root root 600; then SSH_CHANGED=1; fi
if ! /usr/sbin/sshd -t; then
    ((SSH_CHANGED)) && restore_file /etc/ssh/sshd_config
    die 'SSH validation failed; restored previous SSH config where available.'
fi

# BIND9 zone filename matches the absolute path in named.conf.local.
named-checkzone innovate.lab "$REPO_DIR/dns/db.innovate.lab" >/dev/null || die 'Saved DNS zone is invalid.'
grep -Fq 'file "/etc/bind/db.innovate.lab";' "$REPO_DIR/dns/named.conf.local" || die 'DNS zone declaration uses an unexpected file path.'
for entry in \
    'named.conf.local' 'named.conf.options' 'db.innovate.lab'; do
    if deploy_file "$REPO_DIR/dns/$entry" "/etc/bind/$entry" root bind 644; then
        DNS_CHANGED=1
        dns_touched+=("/etc/bind/$entry")
    fi
done
if ! named-checkconf || ! named-checkzone innovate.lab /etc/bind/db.innovate.lab; then
    for entry in "${dns_touched[@]}"; do restore_file "$entry"; done
    die 'DNS validation failed; review backed-up configurations.'
fi

# Kea's /etc/kea directory and service use _kea, not the invoking root user.
if deploy_file "$REPO_DIR/dhcp/kea-dhcp4.conf" /etc/kea/kea-dhcp4.conf root _kea 640; then DHCP_CHANGED=1; fi
if ! runuser -u _kea -- /usr/sbin/kea-dhcp4 -t /etc/kea/kea-dhcp4.conf; then
    ((DHCP_CHANGED)) && restore_file /etc/kea/kea-dhcp4.conf
    die 'Kea validation failed; previous configuration restored if present.'
fi

# Enable IPv4 forwarding persistently without editing Netplan or /etc/sysctl.conf.
forwarding_temp="$(mktemp)"
printf 'net.ipv4.ip_forward=1\n' > "$forwarding_temp"
if deploy_file "$forwarding_temp" /etc/sysctl.d/99-osys3030-ip-forward.conf root root 644; then SYSCTL_CHANGED=1; fi
rm -f -- "$forwarding_temp"
sysctl -q -w net.ipv4.ip_forward=1

# UFW loads this NAT block ahead of its *filter rules.
grep -Fq -- '-A POSTROUTING -s 10.101.0.0/24 -o ens18 -j MASQUERADE' "$REPO_DIR/fw/before.rules" || die 'Saved NAT masquerading rule not found.'
if deploy_file "$REPO_DIR/fw/before.rules" /etc/ufw/before.rules root root 640; then FW_CHANGED=1; fi

# Allow the real SSH port BEFORE applying/reloading firewall rules.
# Back up existing UFW rules before making changes.
for ufw_file in /etc/ufw/user.rules /etc/ufw/user6.rules /etc/default/ufw; do
    [[ -f "$ufw_file" ]] && backup_file "$ufw_file"
done
current_policies="$(LC_ALL=C ufw status verbose)"
if ! grep -Fq 'Default: deny (incoming), allow (outgoing), allow (routed)' <<< "$current_policies"; then
    ufw default deny incoming
    ufw default allow outgoing
    ufw default allow routed
    FW_CHANGED=1
fi
before_rules="$(ufw show added)"
ufw allow in on ens18 to any port 2222 proto tcp
ufw allow in on ens19 to any port 53
ufw allow in on ens19 to any port 67 proto udp
ufw allow in on ens19 to any port 68 proto udp
ufw route allow in on ens19 out on ens18 from 10.101.0.0/24
[[ "$(ufw show added)" == "$before_rules" ]] || FW_CHANGED=1

# Start DNS and DHCP, restarting only if configuration changed while active.
start_service() {
    local name="$1" changed="$2" was_active=0
    if systemctl is-active --quiet "$name"; then was_active=1; fi
    systemctl enable --now "$name"
    if ((changed && was_active)); then systemctl restart "$name"; fi
    systemctl is-active --quiet "$name" || die "Service failed: $name"
}
start_service named "$DNS_CHANGED"
start_service kea-dhcp4-server "$DHCP_CHANGED"

if ! LC_ALL=C ufw status | grep -Fqx 'Status: active'; then
    ufw --force enable
elif ((FW_CHANGED)); then
    ufw reload
fi
iptables -t nat -C POSTROUTING -s 10.101.0.0/24 -o ens18 -j MASQUERADE || die 'NAT rule is not active.'

# Ubuntu 24.04 commonly uses ssh.socket; its generator needs daemon-reload
# after an sshd_config port change. No SSH restart if content is unchanged.
if systemctl is-active --quiet ssh.socket || systemctl is-enabled --quiet ssh.socket; then
    if ((SSH_CONTENT_CHANGED)); then systemctl daemon-reload; fi
    systemctl enable --now ssh.socket
    if ((SSH_CONTENT_CHANGED)); then systemctl restart ssh.socket; fi
else
    start_service ssh "$SSH_CONTENT_CHANGED"
fi
effective_ssh_settings="$(/usr/sbin/sshd -T)"
for required in 'port 2222' 'permitrootlogin no' 'passwordauthentication no' 'pubkeyauthentication yes'; do
    grep -Fqx "$required" <<< "$effective_ssh_settings" || die "Active SSH config does not meet: $required"
done
ss -ltn | grep -Eq '(:|\])2222[[:space:]]' || warn 'Confirm that SSH is actually listening on port 2222.'

log 'Deployment finished. Run scripts/verify_appliance.sh after it is created.'
if [[ -d "$BACKUP_DIR" ]]; then log "Backups: $BACKUP_DIR"; fi
warn 'This does not restore original Netplan, OpenSSH authorized_keys, or unrelated UFW rules (e.g. 80/3000/8080).'
