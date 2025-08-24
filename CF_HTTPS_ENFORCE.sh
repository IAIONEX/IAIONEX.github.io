#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C

# --- tokens from ~/.cf_token ---
if [ ! -f "$HOME/.cf_token" ]; then
  echo "[ERR] ~/.cf_token saknas. Skapa filen med:"
  echo "CF_API_TOKEN=..."; echo "CF_ZONE_ID=..."
  exit 1
fi
# shellcheck disable=SC1090
. "$HOME/.cf_token"
: "${CF_API_TOKEN:?}"; : "${CF_ZONE_ID:?}"

API="https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/settings"
H="Authorization: Bearer ${CF_API_TOKEN}"
C="Content-Type: application/json"

jqval(){ jq -r '.result.value // .result' 2>/dev/null || true; }

patch_on(){
  local key="$1"
  curl -sS -X PATCH "${API}/${key}" -H "$H" -H "$C" --data '{"value":"on"}' | jqval
}
patch_value(){
  local key="$1" val="$2"
  curl -sS -X PATCH "${API}/${key}" -H "$H" -H "$C" --data "{\"value\":\"${val}\"}" | jqval
}

echo "[CF] Set SSL mode = strict"
curl -sS -X PATCH "${API}/ssl" -H "$H" -H "$C" --data '{"value":"strict"}' | jqval

echo "[CF] Enable Always Use HTTPS"
patch_on "always_use_https" >/dev/null

echo "[CF] Enable Automatic HTTPS Rewrites"
patch_on "automatic_https_rewrites" >/dev/null

echo "[CF] Enable TLS 1.3"
patch_on "tls_1_3" >/dev/null

echo "[CF] Set Min TLS Version = 1.2"
patch_value "min_tls_version" "1.2" >/dev/null

echo "[CF] Enable Opportunistic Encryption"
patch_on "opportunistic_encryption" >/dev/null

echo "[CF] Enable HTTP/2"
patch_on "http2" >/dev/null

echo "[CF] Enable HTTP/3"
patch_on "http3" >/dev/null

echo "[CF] Configure HSTS (max-age 1y, includeSubdomains, preload=false)"
curl -sS -X PATCH "${API}/security_header" -H "$H" -H "$C" --data '{
  "value": {
    "strict_transport_security": {
      "enabled": true,
      "max_age": 31536000,
      "include_subdomains": true,
      "nosniff": false,
      "preload": false
    }
  }
}' | jq -r '.success' >/dev/null 2>&1 || true

echo "[CF] Read-back summary:"
for k in ssl always_use_https automatic_https_rewrites tls_1_3 min_tls_version opportunistic_encryption http2 http3; do
  v=$(curl -sS -H "$H" "${API}/${k}" | jq -r '.result.value // empty')
  printf " - %-28s %s\n" "$k" "${v:-unknown}"
done

echo "[OK] Cloudflare HTTPS är nu påtvingat. Säkerställ även i GitHub Pages: Settings → Pages → Enforce HTTPS."
