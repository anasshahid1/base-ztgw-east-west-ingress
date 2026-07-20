#!/usr/bin/env bash
#
# deploy_ztgw.sh — Terraform external data source helper
#
# Authenticates to Zscaler OneAPI, deploys a GCP ZTGW via the REST API,
# polls until healthy, and returns JSON to Terraform.
#
# Input (via stdin JSON from Terraform external data source):
#   client_id, client_secret, vanity_domain, cloud,
#   gateway_name, gcp_region, location_name, iam_principal_email
#
# Output (JSON to stdout for Terraform):
#   gateway_id, gateway_name, region, health_status,
#   intercept_deployment_group, intercept_endpoint_groups_count
#

set -eo pipefail

# ---------------------------------------------------------------------------
# Read input JSON from Terraform
# ---------------------------------------------------------------------------
INPUT=$(cat)

CLIENT_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['client_id'])")
CLIENT_SECRET=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['client_secret'])")
VANITY_DOMAIN=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['vanity_domain'])")
CLOUD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['cloud'])")
INPUT_LOGIN_DOMAIN=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('login_domain',''))")
GATEWAY_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['gateway_name'])")
GCP_REGION=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['gcp_region'])")
LOCATION_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['location_name'])")
IAM_PRINCIPAL=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['iam_principal_email'])")

# ---------------------------------------------------------------------------
# Derive URLs from cloud name
# ---------------------------------------------------------------------------
if [ "$CLOUD" = "zscaler" ]; then
    LOGIN_DOMAIN="zslogin.net"
elif [ "$CLOUD" = "zscalerbeta" ]; then
    LOGIN_DOMAIN="zsloginbeta.net"
elif [ "$CLOUD" = "zscalerthree" ]; then
    LOGIN_DOMAIN="zsloginthree.net"
elif [ "$CLOUD" = "zscalerone" ]; then
    LOGIN_DOMAIN="zsloginone.net"
elif [ "$CLOUD" = "zscalertwo" ]; then
    LOGIN_DOMAIN="zslogintwo.net"
else
    LOGIN_DOMAIN="zslogin.net"
fi

if [ -n "$INPUT_LOGIN_DOMAIN" ]; then
    LOGIN_DOMAIN="$INPUT_LOGIN_DOMAIN"
    echo "Using custom login domain: ${LOGIN_DOMAIN}" >&2
fi

TOKEN_URL="https://${VANITY_DOMAIN}.${LOGIN_DOMAIN}/oauth2/v1/token"
BASE_URL="https://connector.${CLOUD}.net/api/v1"

# ---------------------------------------------------------------------------
# Authentication function (reusable for token refresh)
# ---------------------------------------------------------------------------
authenticate() {
    local token_resp
    token_resp=$(curl -sk --connect-timeout 10 --max-time 30 -X POST "$TOKEN_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}" 2>/dev/null || true)

    ACCESS_TOKEN=$(echo "$token_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || true)

    if [ -z "$ACCESS_TOKEN" ]; then
        echo '{"error": "Authentication failed"}' >&2
        exit 1
    fi

    AUTH_HEADER="Authorization: Bearer $ACCESS_TOKEN"
    TOKEN_TIME=$(date +%s)
    echo "Authenticated successfully" >&2
}

# ---------------------------------------------------------------------------
# Refresh token if older than 4 minutes (tokens expire in ~1 hour,
# but refresh proactively to avoid mid-poll expiration)
# ---------------------------------------------------------------------------
refresh_token_if_needed() {
    local now
    now=$(date +%s)
    local age=$((now - TOKEN_TIME))
    if [ $age -ge 240 ]; then
        echo "Refreshing OAuth2 token (age: ${age}s)..." >&2
        authenticate
    fi
}

# ---------------------------------------------------------------------------
# Force activation via OneAPI (reusable)
# ---------------------------------------------------------------------------
force_activation() {
    echo "Triggering force activation via OneAPI..." >&2
    case "${CLOUD}" in
        zscaler)      ACTIVATION_BASE="https://api.zsapi.net" ;;
        zscalerbeta)  ACTIVATION_BASE="https://api.beta.zsapi.net" ;;
        zscalerone)   ACTIVATION_BASE="https://api.one.zsapi.net" ;;
        zscalertwo)   ACTIVATION_BASE="https://api.two.zsapi.net" ;;
        zscalerthree) ACTIVATION_BASE="https://api.three.zsapi.net" ;;
        *) echo "Warning: unknown cloud '${CLOUD}', skipping force activation" >&2; return ;;
    esac

    local ACTIVATE_URL="${ACTIVATION_BASE}/ztw/api/v1/ecAdminActivateStatus/forcedActivate"
    local ACTIVATE_RESPONSE
    ACTIVATE_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 60 -X PUT "$ACTIVATE_URL" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{}' 2>/dev/null || true)

    echo "Force activation response: $ACTIVATE_RESPONSE" >&2
}

# ---------------------------------------------------------------------------
# Initial authentication
# ---------------------------------------------------------------------------
authenticate

# ---------------------------------------------------------------------------
# Check if ZTGW already exists by name
# ---------------------------------------------------------------------------
echo "Checking for existing ZTGW '${GATEWAY_NAME}'..." >&2
EXISTING=$(curl -sk --connect-timeout 10 --max-time 30 "$BASE_URL/ztGateway?platform=GCP" -H "$AUTH_HEADER" 2>/dev/null || true)
EXISTING_ID=$(echo "$EXISTING" | python3 -c "
import sys, json
data = json.load(sys.stdin)
gateways = data if isinstance(data, list) else data.get('list', data.get('gateways', []))
for gw in gateways:
    if gw.get('name') == '${GATEWAY_NAME}':
        print(gw['id'])
        break
" 2>/dev/null || true)

if [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "" ]; then
    GATEWAY_ID="$EXISTING_ID"
    echo "Found existing ZTGW '${GATEWAY_NAME}' (ID: ${GATEWAY_ID}). Checking health..." >&2

    # Single health check — skip polling if already healthy
    GW_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 30 "$BASE_URL/ztGateway/$GATEWAY_ID" -H "$AUTH_HEADER" 2>/dev/null || true)
    HEALTH_RAW=$(echo "$GW_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('healthStatus','UNKNOWN'))" 2>/dev/null || echo "PARSE_ERROR")
    HEALTH=$(echo "$HEALTH_RAW" | tr '[:lower:]' '[:upper:]')

    if [ "$HEALTH" = "HEALTHY" ]; then
        echo "ZTGW already HEALTHY — returning immediately" >&2

        # Wait briefly for interceptDeploymentGroup to propagate
        echo "Waiting 15s for interceptDeploymentGroup to populate..." >&2
        sleep 15

        refresh_token_if_needed

        GW_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 30 "$BASE_URL/ztGateway/$GATEWAY_ID" -H "$AUTH_HEADER" 2>/dev/null || true)

        IDG=$(echo "$GW_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('interceptDeploymentGroup',''))" 2>/dev/null || true)
        if [ -z "$IDG" ]; then
            echo "Warning: interceptDeploymentGroup not yet populated, continuing without it" >&2
        fi

        # Trigger force activation
        force_activation

        # Extract outputs and return immediately
        echo "$GW_RESPONSE" | python3 -c "
import sys, json
gw = json.load(sys.stdin)
print(json.dumps({
    'gateway_id': str(gw.get('id', '')),
    'gateway_name': gw.get('name', ''),
    'region': gw.get('region', ''),
    'health_status': gw.get('healthStatus', 'UNKNOWN'),
    'intercept_deployment_group': gw.get('interceptDeploymentGroup', ''),
    'intercept_endpoint_groups_count': str(gw.get('interceptEndpointGroupsCount', '0'))
}))
"
        exit 0
    fi

    # Set shorter timeouts for existing gateways based on current state
    MAX_WAIT=600
    if [ "$HEALTH" = "INIT" ]; then
        echo "ZTGW exists but still in INIT state. Polling for up to 10 minutes..." >&2
    else
        echo "ZTGW exists but UNHEALTHY ($HEALTH_RAW). Polling for up to 10 minutes..." >&2
    fi
    IS_NEW=false
else
    # -----------------------------------------------------------------------
    # Get location template ID
    # -----------------------------------------------------------------------
    echo "Fetching location template..." >&2
    TEMPLATES=$(curl -sk --connect-timeout 10 --max-time 30 "$BASE_URL/locationTemplate" -H "$AUTH_HEADER" 2>/dev/null || true)
    TEMPLATE_ID=$(echo "$TEMPLATES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
templates = data if isinstance(data, list) else data.get('list', data.get('templates', []))
for t in templates:
    print(t['id'])
    break
" 2>/dev/null || true)

    if [ -z "$TEMPLATE_ID" ]; then
        echo '{"error": "Could not retrieve location template"}' >&2
        exit 1
    fi

    # -----------------------------------------------------------------------
    # Create ZTGW
    # -----------------------------------------------------------------------
    echo "Creating ZTGW '${GATEWAY_NAME}' in ${GCP_REGION}..." >&2
    CREATE_PAYLOAD=$(python3 -c "
import json
region = '${GCP_REGION}'
az_ids = [region + '-a', region + '-b']
payload = {
    'name': '${GATEWAY_NAME}',
    'platform': 'GCP',
    'region': region,
    'availabilityZoneIds': az_ids,
    'provData': {
        'locationName': '${LOCATION_NAME}',
        'locationTemplate': {'id': ${TEMPLATE_ID}},
    }
}
iam = '${IAM_PRINCIPAL}'
if iam:
    payload['provData']['iamPrincipals'] = [{'type': 'USER', 'value': iam}]
print(json.dumps(payload))
")

    CREATE_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 60 -X POST "$BASE_URL/ztGateway" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "$CREATE_PAYLOAD" 2>/dev/null || true)

    GATEWAY_ID=$(echo "$CREATE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)

    if [ -z "$GATEWAY_ID" ]; then
        echo "$CREATE_RESPONSE" >&2
        exit 1
    fi
    echo "ZTGW created (ID: ${GATEWAY_ID}). Waiting for HEALTHY status (up to 10 minutes)..." >&2
    MAX_WAIT=600
    IS_NEW=true
fi

# ---------------------------------------------------------------------------
# Poll for health status (timeout varies: 15min new, 5min INIT, 3min UNHEALTHY)
# ---------------------------------------------------------------------------
INTERVAL=15
START_TIME=$(date +%s)

while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))

    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "Timeout: ZTGW $GATEWAY_ID did not reach HEALTHY within ${MAX_WAIT}s" >&2
        break
    fi

    # Refresh token if needed
    refresh_token_if_needed

    # Poll health
    GW_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 30 "$BASE_URL/ztGateway/$GATEWAY_ID" -H "$AUTH_HEADER" 2>/dev/null || true)

    # Parse health status (case-insensitive)
    HEALTH_RAW=$(echo "$GW_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('healthStatus','UNKNOWN'))" 2>/dev/null || echo "PARSE_ERROR")
    HEALTH=$(echo "$HEALTH_RAW" | tr '[:lower:]' '[:upper:]')

    echo "Poll: ZTGW $GATEWAY_ID health=$HEALTH_RAW elapsed=${ELAPSED}s" >&2

    if [ "$HEALTH" = "HEALTHY" ]; then
        echo "ZTGW $GATEWAY_ID is HEALTHY" >&2
        break
    fi

    # If we got a parse error, the response might be an auth error
    if [ "$HEALTH" = "PARSE_ERROR" ]; then
        echo "Warning: could not parse health response, refreshing token..." >&2
        authenticate
    fi

    sleep $INTERVAL
done

# ---------------------------------------------------------------------------
# Validate health and intercept deployment group
# ---------------------------------------------------------------------------
if [ "$HEALTH" != "HEALTHY" ]; then
    echo "{\"error\": \"ZTGW $GATEWAY_ID did not reach HEALTHY status within ${MAX_WAIT}s (current: $HEALTH_RAW). Re-run terraform apply after the gateway is healthy.\"}" >&2
    exit 1
fi

# Wait briefly for interceptDeploymentGroup to propagate
echo "Waiting 15s for interceptDeploymentGroup to populate..." >&2
sleep 15

refresh_token_if_needed

GW_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 30 "$BASE_URL/ztGateway/$GATEWAY_ID" -H "$AUTH_HEADER" 2>/dev/null || true)

IDG=$(echo "$GW_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('interceptDeploymentGroup',''))" 2>/dev/null || true)
if [ -z "$IDG" ]; then
    echo "Warning: interceptDeploymentGroup not yet populated, continuing without it" >&2
fi

# ---------------------------------------------------------------------------
# Trigger force activation
# ---------------------------------------------------------------------------
force_activation

# ---------------------------------------------------------------------------
# Extract outputs
# ---------------------------------------------------------------------------
RESULT=$(echo "$GW_RESPONSE" | python3 -c "
import sys, json
gw = json.load(sys.stdin)
print(json.dumps({
    'gateway_id': str(gw.get('id', '')),
    'gateway_name': gw.get('name', ''),
    'region': gw.get('region', ''),
    'health_status': gw.get('healthStatus', 'UNKNOWN'),
    'intercept_deployment_group': gw.get('interceptDeploymentGroup', ''),
    'intercept_endpoint_groups_count': str(gw.get('interceptEndpointGroupsCount', '0'))
}))
")

echo "$RESULT"
