# AI Automation & Code Audit Log

> **Student Name:** [Your Name]  
> **Student ID:** [Your ID]  
> **AI Tool Used:** [e.g., ChatGPT 4o / Claude 3.5 Sonnet / Gemini 1.5 Pro]  

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
I provided ChatGPT with the contents of the instructor's verify_appliance.sh.sample file and continued our discussion about adapting it to my existing Ubuntu appliance. The script needed to check SSH on port 2222, BIND9 DNS, Kea DHCPv4, UFW firewall rules, and NAT masquerading. After generating the script, I tested it and provided the results to ChatGPT to troubleshoot the failed checks.
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

* **Date Tested:** [YYYY-MM-DD]
* **Target Environment:** [e.g., OSYS3030 Baseline Server (VMID 106)]
* **Verification Script Output:**
  ```text
  [Paste the terminal output of running sudo ./scripts/verify_appliance.sh showing PASS]
  ```

---

## 5. Attestation
I attest that I have personally reviewed, tested, and understand every line of code in the generated scripts. I am prepared to explain any part of these scripts or configuration files during an evaluation.
