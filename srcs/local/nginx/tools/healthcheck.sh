#!/bin/bash
set -euo pipefail

DOMAIN="${DOMAIN_NAME:-login.42.fr}"
URL="https://127.0.0.1/"

curl -kfsS -H "Host: ${DOMAIN}" "$URL" >/dev/null
