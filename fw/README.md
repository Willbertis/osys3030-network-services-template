# Firewall & NAT Masquerade Gateway Guide

## 1. Overview
This guide documents the firewall and NAT configuration on my Ubuntu Server 24.04 network appliance. The server uses UFW to control network traffic and iptables NAT masquerading to allow clients on the private LAN (ens19) to access external networks through the WAN interface (ens18).

## 2. Configuration Files Included
* `before.rules`: Contains the iptables NAT masquerading rules used by UFW.
* `sysctl.conf` setting: Enables IPv4 packet forwarding.
* `ufw.conf` UFW rules: Control access to SSH, DNS, DHCP, and other configured services.

## 3. Kernel Forwarding Configuration
In `/etc/sysctl.conf`:
```ini
net.ipv4.ip_forward=1
```
Apply without rebooting:
```bash
sudo sysctl -p
```

## 4. NAT Masquerading Rules (`/etc/ufw/before.rules`)
The following NAT rules are placed before the `*filter` section in `/etc/ufw/before.rules`.
```ini
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Forward and masquerade traffic from LAN to WAN
-A POSTROUTING -s 10.101.0.0/24 -o ens18 -j MASQUERADE

COMMIT
```
These rules allow traffic from the private 10.101.0.0/24 network to be masqueraded through the WAN interface.

To restore the saved firewall configuration, back up the existing file and copy the repository version:
```bash
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.orig
sudo cp before.rules /etc/ufw/before.rules
```
These recovery commands assume they are run from the repository's fw/ directory.

## 5. UFW Policy & Port Allowlist
The firewall uses the following default policies:
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default allow routed
```
The following commands configure the main SSH, DNS, DHCP, and LAN forwarding rules used by the appliance.
```bash
# SSH remote administration
sudo ufw allow in on ens18 to any port 2222 proto tcp

# DNS for LAN clients
sudo ufw allow in on ens19 to any port 53

# DHCP for LAN clients
sudo ufw allow in on ens19 to any port 67 proto udp
sudo ufw allow in on ens19 to any port 68 proto udp

# Forward LAN traffic to WAN
sudo ufw route allow in on ens19 out on ens18 from 10.101.0.0/24

# Enable UFW
sudo ufw enable
```
The existing firewall also contains rules for ports 3000, 80, and 8080, which were configured for other services.

Warning: Before enabling or reloading UFW on a newly installed server, confirm SSH access on TCP port 2222 is allowed to avoid losing remote access.


## 6. Verification & Troubleshooting
Check UFW status and rules:

```bash
sudo ufw status verbose
```

Check active NAT masquerading rules:

```bash
sudo iptables -t nat -L POSTROUTING -n -v
```

Check whether IPv4 forwarding is enabled:

```bash
sysctl net.ipv4.ip_forward
```

From the Alpine Client VM (9101), test external connectivity:

```bash
ping -c 3 8.8.8.8
ping -c 3 google.com
```

If the IP address ping succeeds but the domain name ping fails, check the DNS configuration.

If neither succeeds, check the default gateway, IPv4 forwarding, UFW rules, and NAT configuration.

Check firewall logs:

```bash
sudo journalctl -k -n 50 --no-pager
```
