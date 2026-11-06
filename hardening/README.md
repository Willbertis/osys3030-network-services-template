# System & SSH Hardening Guide

## 1. Overview
This guide documents the SSH configuration used on my Ubuntu Server 24.04 network appliance. SSH allows me to remotely manage the server while using security settings to reduce unauthorized access. The server uses port 2222, disables root login and password authentication, and uses SSH public key authentication.

## 2. Configuration Files Included
* `sshd_config`: Hardened configuration for `/etc/ssh/sshd_config`.

## 3. Key Security Settings Explained
* **Root Login Policy:** PermitRootLogin no prevents users from logging in directly as root through SSH.
* **Authentication:**  PasswordAuthentication no disables password-based SSH login. Public key authentication is enabled, requiring users to authenticate using an authorized SSH key.
* **Port / Protocol:** SSH runs on TCP port 2222 instead of the default port 22. SSH uses protocol version 2.
* **Keyboard-Interactive Authentication:** KbdInteractiveAuthentication no disables keyboard-interactive authentication.
* **Address Family:** AddressFamily inet limits SSH to IPv4.
* **Additional Settings:** PrintMotd no disables printing the message of the day through SSH, while UsePAM yes enables PAM account and session management.

## 4. Recovery & Deployment Steps
These steps can be used to restore SSH on a newly installed Ubuntu Server 24.04 system.


### 1. Install OpenSSH

```bash
sudo apt update
sudo apt install openssh-server -y
```

### 2. Back up the existing configuration

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
```

### 3. Deploy the saved configuration

```bash
sudo cp sshd_config /etc/ssh/sshd_config
sudo chown root:root /etc/ssh/sshd_config
sudo chmod 600 /etc/ssh/sshd_config
```

### 4. Test configuration syntax

```bash
sudo sshd -t
```

### 5. Enable and restart SSH

```bash
sudo systemctl enable ssh
sudo systemctl restart ssh
```

These commands assume they are run from the repository's hardening/ directory.

Before restarting SSH, make sure the administrator's public key is installed in the appropriate user's ~/.ssh/authorized_keys file and that TCP port 2222 is permitted through the firewall. Otherwise, remote access could be lost.

## 5. Verification & Troubleshooting
Check whether SSH is active:

```bash
sudo systemctl status ssh
```

Check the active listening port:

```bash
sudo ss -tulpn | grep sshd
```

Verify the SSH configuration:

```bash
sudo sshd -t
```

Display effective SSH authentication and port settings:

```bash
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication)'
```

Test remote access from another system:

```bash
ssh -p 2222 student@10.20.1.120
```

Check SSH logs if problems occur:

```bash
sudo journalctl -u ssh -n 50 --no-pager
```

The expected results are an active SSH service listening on TCP port 2222, with root and password authentication disabled.
