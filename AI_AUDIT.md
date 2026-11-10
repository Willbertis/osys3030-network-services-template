# AI Automation & Code Audit Log

> **Student Name:** William Gilbert
> **Student ID:** W0453411
> **AI Tool Used:** ChatGPT

---

## 1. Executive Summary
I used ChatGPT to help create two Bash scripts for my Ubuntu network appliance project. The first script automates the installation and configuration of SSH, BIND9 DNS, Kea DHCP, and UFW with NAT. The second script checks that these services are configured and running correctly. I used my existing configuration files and documentation to guide the AI, then reviewed the scripts and tested them for errors. During testing, I found an issue with how the verification script checked UFW rules, which I corrected. After making that change, all 24 verification checks passed. The deployment script also passed its Bash syntax check, but a full deployment test has not been completed yet.

---

## 2. Prompt Log

### 2.1 Deployment Script Prompt
Paste the exact prompt you gave the AI to generate `deploy_appliance.sh`:

```text
Act as a Senior Linux DevOps Engineer. Using my attached Markdown guides and configuration files for SSH hardening, BIND9, Kea DHCPv4, and UFW with NAT masquerading on Ubuntu 24.04, generate a production-ready Bash script (scripts/deploy_appliance.sh). The script must install all packages, back up existing configs, deploy my custom config files into /etc/, set strict file permissions, and start/enable services in the correct dependency order.
```

### 2.2 Verification Script Prompt
Paste the exact prompt you gave the AI to generate `verify_appliance.sh`:

```text
I did not use a separate written prompt for this script. I provided ChatGPT with the complete contents of the instructor's `verify_appliance.sh.sample` file, and ChatGPT generated a customized verification script using our previous discussions about my server configuration. My original input was the sample script pasted from the terminal.
```

---

## 3. Human-in-the-Loop Audit & Hallucination Corrections

AI models frequently introduce errors when writing infrastructure automation. Document at least 2 specific errors, bugs, or omissions the AI made in the generated scripts and how you fixed them:

| # | Service / Component | The AI's Hallucination / Error | The Fix Implemented |
| :--- | :--- | :--- | :--- |
| **1** | UFW Verification | The verification script was looking for ALLOW IN in the UFW output, but my server displays ALLOW. This caused three checks to fail even though the firewall rules were correct. | I corrected the verification script to recognize ALLOW. After running it again, all 24 checks passed. |
| **2** | Deployment Script | The deployment script backed up before.rules but didn't back up the existing UFW user rules before potentially modifying them. | I added a backup loop for the existing UFW rule files to make recovery safer. |


---

## 4. Testing & Verification Results

* **Date Tested:** 2026-11-10
* **Target Environment:** Ubuntu Server 24.04 (bertis), OSYS3030 Network Appliance
* **Verification Script Output:** 24 Pass, 0 Fail

I ran the verification script against my existing Ubuntu network appliance. Initially, three UFW checks failed because the script was looking for the wrong output format. After correcting this issue, I ran the script again and all 24 checks passed.

I also tested the deployment script using bash -n to check for syntax errors. The script passed this check, but I have not yet performed a full deployment test on a fresh Ubuntu installation.

  ```text
============================================================
  OSYS3030 Appliance Health & Verification Suite
============================================================

--- 1. Network prerequisites ---
  WAN ens18 has 10.20.1.120/23                               [ PASS ]
  LAN ens19 has 10.101.0.250/24                              [ PASS ]

--- 2. BIND9 DNS ---
  BIND9 named service active                                 [ PASS ]
  BIND9 syntax valid (named-checkconf)                       [ PASS ]
  innovate.lab zone valid                                    [ PASS ]
  DNS listening on UDP port 53                               [ PASS ]
  web.innovate.lab resolves to LAN address                   [ PASS ]

--- 3. Kea DHCPv4 ---
  Kea DHCPv4 service active                                  [ PASS ]
  Kea syntax valid (run as _kea)                             [ PASS ]
  DHCP listening on UDP port 67                              [ PASS ]

--- 4. SSH hardening ---
  SSH service or socket active                               [ PASS ]
  OpenSSH configuration syntax valid                         [ PASS ]
  SSH configured for TCP port 2222                           [ PASS ]
  Root login disabled                                        [ PASS ]
  Password authentication disabled                           [ PASS ]
  SSH listening on TCP port 2222                             [ PASS ]

--- 5. UFW firewall and routing ---
  UFW firewall active                                        [ PASS ]
  IPv4 forwarding enabled                                    [ PASS ]
  NAT rule stored in UFW before.rules                        [ PASS ]
  Active NAT MASQUERADE rule correct                         [ PASS ]
  UFW permits SSH 2222 inbound                               [ PASS ]
  UFW permits DNS on LAN                                     [ PASS ]
  UFW permits DHCP on LAN                                    [ PASS ]
  UFW allows LAN-to-WAN forwarding                           [ PASS ]

============================================================
  Results: 24 PASS, 0 FAIL
  All appliance checks passed.
  ```

---

## 5. Attestation

I confirm that I have reviewed the AI-generated scripts and made corrections where needed. I tested the verification script against my existing Ubuntu server, and all 24 checks passed. I also checked the deployment script for syntax errors, but I have not completed a full deployment test. I understand the purpose of both scripts, how they work with my network configuration, and the changes they make to the system. I am prepared to explain my work and the corrections I made during an evaluation.
