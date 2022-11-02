#!/bin/sh

set -e

DNS_RECORD="$1"

print_usage() {
    echo "usage: CLOUDFLARE_API_TOKEN=<token> ./delete_dns_record.sh <dns_record>"
}

if [ -z "${CLOUDFLARE_API_TOKEN}" ]; then
    echo "Missing CLOUDFLARE_API_TOKEN environment variable"
    exit 1
fi
if [ -z "$DNS_RECORD"]; then
    print_usage
    exit 1
fi

CLOUDFLARE_API_BASE_URL="https://api.cloudflare.com/client/v4"

ZONE_ID=$(curl --fail -X GET "${CLOUDFLARE_API_BASE_URL}/zones?name=rm3l.org" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
     -H "Content-Type:application/json" | jq -r '.result[].id')

if [ -z "$ZONE_ID" ]; then
    echo "DNS Zone $DNS_ZONE not found!"
    exit 1
fi

for record in `curl --fail -X GET "${CLOUDFLARE_API_BASE_URL}/zones/${ZONE_ID}/dns_records?name=${DNS_RECORD}" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
     -H "Content-Type:application/json" | jq -r '.result[].id')`; do
    curl --fail -X DELETE "${CLOUDFLARE_API_BASE_URL}/zones/${ZONE_ID}/dns_records/${record}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json"
done
