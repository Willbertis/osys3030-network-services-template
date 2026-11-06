# Kea DHCPv4 Server Guide

## 1. Overview
This guide documents the Kea DHCPv4 server running on my Ubuntu Server 24.04 network appliance. Kea automatically assigns IP addresses to clients connected to the isolated LAN through ens19.

The DHCP server also provides clients with the default gateway and DNS server information needed to access the network.

## 2. Configuration Files Included
* `kea-dhcp4.conf`: DHCP configuration copied from `/etc/kea/kea-dhcp4.conf`.

## 3. Scope & Option Architecture
* **Listening Interface:** `ens19` (bound exclusively to LAN).
* **Subnet:** `10.101.0.0/24`
* **Dynamic Pool:** `10.101.0.10 - 10.101.0.200`
* **Default Router (Option 3):** `10.101.0.250` (Server `ens19` IP)
* **Domain Name Server (Option 6):** `10.101.0.250` (Internal BIND9 IP)

## 4. Recovery & Deployment Steps
```bash
# 1. Install Kea DHCPv4 Server
sudo apt update
sudo apt install kea-dhcp4-server -y

# 2. Deploy sanitized configuration
sudo cp kea-dhcp4.conf /etc/kea/kea-dhcp4.conf

# 3. Test configuration syntax
sudo -u _kea kea-dhcp4 -t /etc/kea/kea-dhcp4.conf

# 4. Restart and enable Kea service
sudo systemctl restart kea-dhcp4-server
sudo systemctl enable kea-dhcp4-server
```

## 5. Client Verification & Alpine Linux Notes
On your **Alpine Linux Client VM** (`OSYS3030-<username>-client` / VM `9101`):

> [!NOTE]
> Alpine Linux uses BusyBox `udhcpc`. BusyBox requires `eth0` to be administratively `UP` before broadcasting!

```bash
# 1. Acquire DHCP lease on client
ip link set eth0 up
udhcpc -i eth0

# 2. Verify IP and default route
ip a show eth0
ip route

# 3. Verify pushed DNS nameserver
cat /etc/resolv.conf
```

## 6. Server Lease Inspection
Inspect active leases recorded by Kea:
```bash
sudo cat /var/lib/kea/kea-leases4.csv
```

### Troubleshooting

If the Kea configuration syntax check fails with "Unable to open file", run the check using the `_kea` service account:

```bash
sudo -u _kea kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
```

This was necessary on my Ubuntu server because of file access restrictions. The configuration passed validation when tested as the `_kea` user.
