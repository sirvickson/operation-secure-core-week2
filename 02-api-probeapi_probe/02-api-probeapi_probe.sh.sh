#!/usr/bin/env bash
#
# probe_medusa_api.sh
#
# Probes a set of Medusa API endpoints with curl and prints a summary
# table of HTTP status codes.
#
# Usage:
#   ./probe_medusa_api.sh [BASE_URL]
#
# Example:
#   ./probe_medusa_api.sh http://localhost:9000
#
# Environment variables (optional):
#   MEDUSA_ADMIN_TOKEN  - Bearer token to authenticate admin endpoints
#   MEDUSA_PUBLISHABLE_KEY - Publishable API key for store endpoints
#                            (sent as x-publishable-api-key header)
#   TIMEOUT             - curl max time in seconds (default: 10)

set -uo pipefail

BASE_URL="${1:-http://localhost:9000}"
TIMEOUT="${TIMEOUT:-10}"
MEDUSA_PUBLISHABLE_KEY="pk_a9589109834f27f702c40a65733eb62a8d2a52fbe291270b02bfd36a11d14ce1"

# Strip any trailing slash from BASE_URL
BASE_URL="${BASE_URL%/}"

# Endpoints to probe
ENDPOINTS=(
  "/health"
  "/store/products"
  "/store/carts"
  "/store/customers"
  "/store/orders"
  "/admin/products"
)

# Arrays to hold results
declare -a RESULT_ENDPOINT
declare -a RESULT_STATUS
declare -a RESULT_TIME

probe_endpoint() {
  local endpoint="$1"
  local url="${BASE_URL}${endpoint}"
  local headers=()

  # Attach auth headers where relevant, if provided
  if [[ "$endpoint" == /admin/* && -n "${MEDUSA_ADMIN_TOKEN:-}" ]]; then
    headers+=(-H "Authorization: Bearer ${MEDUSA_ADMIN_TOKEN}")
  fi
  if [[ "$endpoint" == /store/* && -n "${MEDUSA_PUBLISHABLE_KEY:-}" ]]; then
    headers+=(-H "x-publishable-api-key: ${MEDUSA_PUBLISHABLE_KEY}")
  fi

  # -s silent, -o discard body, -w print status code and time
  # --max-time to avoid hanging on unreachable hosts
  local response
  response=$(curl -s -o /dev/null \
    --max-time "$TIMEOUT" \
    -w "%{http_code} %{time_total}" \
    "${headers[@]}" \
    "$url" 2>/dev/null)

  local status time
  if [[ -z "$response" ]]; then
    status="ERR"
    time="-"
  else
    status=$(awk '{print $1}' <<< "$response")
    time=$(awk '{print $2}' <<< "$response")
    [[ -z "$status" || "$status" == "000" ]] && status="ERR"
  fi

  echo "$status|$time"
}

classify_status() {
  local status="$1"
  case "$status" in
    2*) echo "OK" ;;
    3*) echo "REDIRECT" ;;
    401|403) echo "AUTH REQUIRED" ;;
    404) echo "NOT FOUND" ;;
    4*) echo "CLIENT ERROR" ;;
    5*) echo "SERVER ERROR" ;;
    ERR) echo "UNREACHABLE" ;;
    *) echo "UNKNOWN" ;;
  esac
}

echo "Probing Medusa API at: ${BASE_URL}"
echo "Timeout per request: ${TIMEOUT}s"
echo ""

for endpoint in "${ENDPOINTS[@]}"; do
  IFS='|' read -r status time <<< "$(probe_endpoint "$endpoint")"
  RESULT_ENDPOINT+=("$endpoint")
  RESULT_STATUS+=("$status")
  RESULT_TIME+=("$time")
done

# Print summary table
printf "%-22s %-10s %-16s %-10s\n" "ENDPOINT" "STATUS" "RESULT" "TIME (s)"
printf "%-22s %-10s %-16s %-10s\n" "--------" "------" "------" "--------"

for i in "${!RESULT_ENDPOINT[@]}"; do
  endpoint="${RESULT_ENDPOINT[$i]}"
  status="${RESULT_STATUS[$i]}"
  time="${RESULT_TIME[$i]}"
  result=$(classify_status "$status")
  printf "%-22s %-10s %-16s %-10s\n" "$endpoint" "$status" "$result" "$time"
done

echo ""

# Exit non-zero if any endpoint failed to respond at all
for status in "${RESULT_STATUS[@]}"; do
  if [[ "$status" == "ERR" ]]; then
    exit 1
  fi
done

exit 0