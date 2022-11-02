#!/bin/sh

set -e

DNS_RECORD="$1"
DNS_TYPE="$2"
DNS_TARGET="$3"
DNS_ZONE="rm3l.org"

print_usage() {
    echo "usage: CLOUDFLARE_API_TOKEN=<token> ./add_dns_record.sh <dns_record> <dns_type> <dns_target>"
}

if [ -z "${CLOUDFLARE_API_TOKEN}" ]; then
    echo "Missing CLOUDFLARE_API_TOKEN environment variable"
    exit 1
fi
if [ -z "$DNS_RECORD"] || [ -z "$DNS_TYPE" ] || [ -z "$DNS_TARGET" ]; then
    print_usage
    exit 1
fi

CLOUDFLARE_API_BASE_URL="https://api.cloudflare.com/client/v4"

ZONE_ID=$(curl --fail -X GET "${CLOUDFLARE_API_BASE_URL}/zones?name=${DNS_ZONE}" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
     -H "Content-Type:application/json" | jq -r '.result[].id')

if [ -z "$ZONE_ID" ]; then
    echo "DNS Zone $DNS_ZONE not found!"
    exit 1
fi

# Check if DNS record exists
record=$(curl --fail -X GET "${CLOUDFLARE_API_BASE_URL}/zones/${ZONE_ID}/dns_records?type=${DNS_TYPE}&name=${DNS_RECORD}&content=${DNS_TARGET}" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
     -H "Content-Type:application/json" | jq -r '.result[].id')

if [ -z "$record" ]; then
    curl --fail -X POST "${CLOUDFLARE_API_BASE_URL}/zones/${ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data '{"type":"'"${DNS_TYPE}"'","name":"'"${DNS_RECORD}"'","content":"'"${DNS_TARGET}"'","ttl":60,"proxied":false}'
else
    echo "WARN: DNS Record ${DNS_RECORD} (type: ${DNS_TYPE}, target: ${DNS_TARGET}) already exists in zone $DNS_ZONE - skipping it."
fi
