#!/bin/bash

# install.sh - Installer for Raspberry Pi MOTD
# Based on instructions from README.md

set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./install.sh)"
  exit 1
fi

echo "--- Installing Raspberry Pi MOTD ---"

# 1. Remove Default MOTD
echo "[1/4] Removing default MOTD..."
[ -f /etc/motd ] && mv /etc/motd /etc/motd.bak && echo "  - Backed up /etc/motd to /etc/motd.bak"
[ -f /etc/update-motd.d/10-uname ] && rm /etc/update-motd.d/10-uname && echo "  - Removed /etc/update-motd.d/10-uname"

# Modify sshd_config to disable PrintLastLog (since new MOTD handles it)
if [ -f /etc/ssh/sshd_config ]; then
    if grep -q "^PrintLastLog yes" /etc/ssh/sshd_config; then
        sed -i 's/^PrintLastLog yes/PrintLastLog no/' /etc/ssh/sshd_config
        echo "  - Set PrintLastLog to no in /etc/ssh/sshd_config"
        systemctl restart sshd
    elif ! grep -q "^PrintLastLog no" /etc/ssh/sshd_config; then
        echo "PrintLastLog no" >> /etc/ssh/sshd_config
        echo "  - Added PrintLastLog no to /etc/ssh/sshd_config"
        systemctl restart sshd
    fi
fi

# 2. Implement New MOTD
echo "[2/4] Implementing new MOTD scripts..."
mkdir -p /etc/update-motd.d
cp update-motd.d/10-welcome /etc/update-motd.d/
cp update-motd.d/15-system /etc/update-motd.d/
cp update-motd.d/20-update /etc/update-motd.d/

chown root:root /etc/update-motd.d/10-welcome /etc/update-motd.d/15-system /etc/update-motd.d/20-update
chmod +x /etc/update-motd.d/10-welcome /etc/update-motd.d/15-system /etc/update-motd.d/20-update

# 3. Setup Static MOTD Update Script
echo "[3/4] Setting up static MOTD update script..."
mkdir -p /etc/update-motd-static.d
cp update-motd-static.d/20-update /etc/update-motd-static.d/
chown root:root /etc/update-motd-static.d/20-update
chmod +x /etc/update-motd-static.d/20-update

# Run it once to initialize the static content
echo "  - Running initial update-motd-static..."
run-parts /etc/update-motd-static.d || echo "  - Warning: initial run-parts failed (this is expected if not on Raspberry Pi)"

# 4. Automation with Systemd Timer
echo "[4/4] Setting up systemd timer for updates..."
cp systemd-timer/motd-update.service /etc/systemd/system/
cp systemd-timer/motd-update.timer /etc/systemd/system/

chown root:root /etc/systemd/system/motd-update.service /etc/systemd/system/motd-update.timer

systemctl daemon-reload
systemctl enable motd-update.timer
systemctl start motd-update.timer

echo "--- Installation Complete! ---"
echo "Reconnect your SSH session to see the new MOTD."
