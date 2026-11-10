# OSYS3030 - Linux Network Appliance Documentation

> **Student Name:** William Gilbert
> **Student ID:** W0453411
> **VMID:** 101
> **Repository:** https://github.com/Willbertis/osys3030-network-services-template
> **Instructor:** Matt Redmond
> **Course:** OSYS3030 - Network Services Using Linux

---

## 1. Appliance Overview
This Ubuntu Server 24.04 appliance provides network services for an isolated internal network. It uses two network interfaces to connect the school network to a private LAN. The server provides DNS, DHCP, SSH remote access, and firewall services with NAT masquerading to allow internal clients to access external networks.

* **Operating System:** Ubuntu Server 24.04 LTS (Noble Numbat)
* **Hostname:** `bertis`
* **Primary Roles:**
  * Router & Firewall (UFW + iptables NAT masquerading)
  * Recursive & Authoritative DNS (BIND9)
  * Dynamic Host Configuration Protocol (Kea DHCPv4)
  * Secure Remote Administration (OpenSSH)

---

## 2. Network Topology & Interfaces

```text
              +------------------------------------------+
              |           WAN / NSCC Network             |
              |             10.20.0.0/23                 |
              +---------------------+--------------------+
                                    |
                                    | (10.20.1.120/23)
                                 [ens18]
                       +------------+------------+
                       |   OSYS3030 Linux Server |
                       |          bertis         |
                       +------------+------------+
                                 [ens19]
                                    | (10.101.0.250/24)
                                    |
              +---------------------+--------------------+
              |        Isolated Private VLAN (vmbr5)      |
              |             10.101.0.0/24               |
              +---------------------+--------------------+
                                    |
                                    | (DHCP: 10.101.0.10 - .200)
                                 [eth0]
                       +------------+------------+
                       |    Alpine Client VM     |
                       |       (VM 9101)         |
                       +-------------------------+
```

| Interface | Network Zone | IP Address / Subnet | Purpose |
| :--- | :--- | :--- | :--- |
| `ens18` | WAN / External | `10.20.1.120/23` | Upstream internet & SSH management |
| `ens19` | LAN / Internal | `10.101.0.250/24` | Default gateway & service binding for clients |

---

## 3. Implemented Services

| Directory | Service | Daemon | Listening Ports | Description |
| :--- | :--- | :--- | :--- | :--- |
| [`hardening/`](./hardening/) | SSH / Host Security | `sshd` | TCP 2222 | Hardened SSH configuration, root restrictions |
| [`dns/`](./dns/) | BIND9 DNS | `named` | UDP/TCP 53 | Authoritative for `innovate.lab` & recursive forwarder |
| [`dhcp/`](./dhcp/) | Kea DHCPv4 | `kea-dhcp4` | UDP 67 | Scoped dynamic IP lease allocation for LAN |
| [`fw/`](./fw/) | UFW Firewall & NAT | `ufw` / `iptables` | N/A | State-tracking firewall & packet masquerading |
| [`scripts/`](./scripts/) | Automation | Bash | N/A | Automated deployment and verification scripts |

---

## 4. Base OS & Netplan Prerequisites
This appliance runs Ubuntu Server 24.04 LTS and uses Netplan with the networkd renderer to configure both network interfaces. Both interfaces use static IP addresses to keep the network services accessible at consistent addresses.

The WAN interface (ens18) connects to the school network, while the LAN interface (ens19) connects to the isolated internal network.

### Network Configuration

The main Netplan configuration file is /etc/netplan/01-netcfg.yaml.

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:
      addresses:
        - 10.20.1.120/23
      nameservers:
        addresses:
          - 10.20.0.1
      dhcp4: false
      routes:
        - to: default
          via: 10.20.0.1
    ens19:
      addresses:
        - 10.101.0.250/24
      dhcp4: false
      mtu: 9000
```

### Base OS Prerequisites

Before deploying the appliance services, Ubuntu Server 24.04 LTS must be installed with two network interfaces.

The following packages are required:

openssh-server — SSH remote administration

bind9, bind9-utils, dnsutils — DNS services and testing

kea-dhcp4-server — DHCPv4 service

ufw, iptables — Firewall and NAT masquerading

git — Repository management

Install the packages using:

```bash
sudo apt update
sudo apt install openssh-server bind9 bind9-utils dnsutils kea-dhcp4-server ufw iptables git -y
```

### Network Verification

After configuring Netplan, verify the network interfaces using:

```bash
ip -br addr
ip route
sudo netplan get
```

Confirm that ens18 and ens19 have their assigned IP addresses and that the default route uses 10.20.0.1.

---

## 5. Automated Recovery & Verification

This appliance includes automated deployment and verification scripts located in [`scripts/`](./scripts/):

* **Deployment / Disaster Recovery:**
  ```bash
  sudo ./scripts/deploy_appliance.sh
  ```
* **Automated Health Check & Verification:**
  ```bash
  sudo ./scripts/verify_appliance.sh
  ```

See [`AI_AUDIT.md`](./AI_AUDIT.md) for documentation on how these scripts were generated using AI and audited for accuracy.

The verification script was tested against my existing Ubuntu appliance, with all 24 checks passing. The deployment script passed Bash syntax validation but has not undergone a full recovery test on a fresh installation. The deployment script should be reviewed and tested in a controlled environment before being used on a production system.

---

## 6. Peer Review Audit

* **Audited Classmate:** [Classmate Name] ([GitHub Profile URL / Repo URL])
* **Classmate Appliance Subnet:** `10.<PartnerID>.0.0/24`
* **Audit Summary:** [2–3 sentences summarizing your review of your peer's repository, configs, and recovery documentation].
