#!/bin/bash

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

# Prompt the user for API_TOKEN and ZONE_ID
read -p "Enter your Cloudflare API Token: " API_TOKEN
read -p "Enter your Cloudflare Zone ID: " ZONE_ID

# Retrieve the RULESET_ID for "http_request_firewall_custom"
echo "Fetching RULESET_ID for http_request_firewall_custom..."
RULESET_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/rulesets?phase=http_request_firewall_custom" \
-H "Authorization: Bearer ${API_TOKEN}" \
-H "Content-Type: application/json" | jq -r '.result[] | select(.phase=="http_request_firewall_custom" and .source=="firewall_custom") | .id')

if [ -z "$RULESET_ID" ]; then
    echo "Error: Could not retrieve RULESET_ID for http_request_firewall_custom."
    exit 1
fi
echo "RULESET_ID: ${RULESET_ID}"

# Retrieve the RATE_LIMIT_RULESET_ID for "http_ratelimit"
echo "Fetching RATE_LIMIT_RULESET_ID for http_ratelimit..."
RATE_LIMIT_RULESET_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/rulesets?phase=http_ratelimit" \
-H "Authorization: Bearer ${API_TOKEN}" \
-H "Content-Type: application/json" | jq -r '.result[] | select(.phase=="http_ratelimit" and .source=="rate_limit") | .id')

if [ -z "$RATE_LIMIT_RULESET_ID" ]; then
    echo "Error: Could not retrieve RATE_LIMIT_RULESET_ID for http_ratelimit."
    exit 1
fi
echo "RATE_LIMIT_RULESET_ID: ${RATE_LIMIT_RULESET_ID}"

# Function to create a firewall rule using jq to format JSON
create_rule() {
    local description="$1"
    local action="$2"
    local expression="$3"
    local ruleset_id="$4"

    echo "Creating rule: ${description}..."

    curl -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/rulesets/${ruleset_id}/rules" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -n \
        --arg desc "$description" \
        --arg act "$action" \
        --arg expr "$expression" \
        '{description: $desc, enabled: true, action: $act, expression: $expr}')"

    echo -e "\nDone.\n"
}

# Function to create a rate limiting rule using jq to format JSON
create_rate_limit_rule() {
    local description="$1"
    local expression="$2"

    echo "Creating rate limit rule: ${description}..."

    curl -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/rulesets/${RATE_LIMIT_RULESET_ID}/rules" \
    -H "Authorization: Bearer ${API_TOKEN}" \
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

    echo -e "\nDone.\n"
}

# Creating security rules
create_rule "Challenge high threat score visitors" "managed_challenge" "(cf.threat_score gt 40)" "$RULESET_ID"

create_rule "Block common WordPress attack vectors" "block" "(http.request.uri eq \"/xmlrpc.php\") or (http.request.uri contains \"/wp-admin\") or (http.request.uri contains \"/wp-config\") or (http.request.uri contains \"install.php\")" "$RULESET_ID"

create_rule "Block /wp-admin for non-allowed countries" "block" "(http.request.uri contains \"wp-admin\") and not (ip.src.country in {\"CA\" \"GB\" \"US\" \"MX\"})" "$RULESET_ID"

create_rule "Block traffic outside North America & Europe" "block" "not (ip.src.continent in {\"NA\" \"EU\"})" "$RULESET_ID"

create_rule "Challenge HTTP/1.0 requests" "managed_challenge" "(http.request.version eq \"HTTP/1.0\")" "$RULESET_ID"

# Creating rate limiting rule
create_rate_limit_rule "Rate limit PHP requests unless from search engine crawlers" "(http.request.uri.path contains \"php\") or (cf.verified_bot_category ne \"Search Engine Crawler\")"

echo "All rules created successfully!"
