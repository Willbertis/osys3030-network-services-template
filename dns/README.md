# BIND9 Domain Name System (DNS) Guide

## 1. Overview
This guide documents the BIND9 DNS configuration on my Ubuntu Server 24.04 network appliance. The server provides DNS resolution for the internal network and forwards external DNS requests to upstream DNS servers.
1. **Authoritative Nameserver:** Hosts the forward lookup zone innovate.lab, allowing hostnames to resolve to IP addresses. A reverse lookup zone was not configured in the previous networking challenges.
2. **Caching / Recursive Resolver:** Uses Google DNS (8.8.8.8) and Cloudflare DNS (1.1.1.1) as upstream forwarders.

## 2. Configuration Files Included
* `named.conf.local`: Declares the innovate.lab forward lookup zone.
* `named.conf.options`: Contains the DNS forwarder configuration.
* `db.innovate.lab`: Contains the forward DNS records, including the nameserver and internal hosts.

The current configuration does not include a reverse zone file or PTR records.

## 3. Recovery & Deployment Steps
```bash
# 1. Install BIND9 and utility packages
sudo apt update
sudo apt install bind9 bind9-utils bind9-doc dnsutils -y

# 2. Deploy configuration files
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.orig
sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.orig

sudo cp named.conf.options /etc/bind/named.conf.options
sudo cp named.conf.local /etc/bind/named.conf.local
sudo cp db.innovate.lab /etc/bind/db.innovate.lab

# 3. Set proper ownership and permissions
sudo chown root:bind /etc/bind/db.innovate.lab
sudo chmod 644 /etc/bind/db.innovate.lab

# 4. Check configuration syntax
sudo named-checkconf
sudo named-checkzone innovate.lab /etc/bind/db.innovate.lab

# 5. Restart BIND9 service
sudo systemctl restart named
sudo systemctl enable named
```

## 4. Verification & Troubleshooting
* Check service status: `sudo systemctl status named`
* Test local resolution:
  ```bash
  dig @127.0.0.1 ns1.innovate.lab +short
  dig @127.0.0.1 web.innovate.lab +short
  dig @10.101.0.250 www.innovate.lab +short
  ```
* Check query logs: `sudo journalctl -u named -n 50 --no-pager`
