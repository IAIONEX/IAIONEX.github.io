#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C
DOMAIN="${DOMAIN:-iaionex.com}"

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need curl jq coreutils

read -r -p "Ange Cloudflare API token (eller lämna tomt om CF_API_TOKEN redan är satt): " -s INP || true
echo
CF_API_TOKEN="${CF_API_TOKEN:-${INP:-}}"
if [ -z "${CF_API_TOKEN:-}" ]; then
  echo "[ERR] Ingen token angiven."; exit 2
fi

echo "[*] Hämtar Zone ID för ${DOMAIN} ..."
ZRESP="$(curl -sS -H "Authorization: Bearer ${CF_API_TOKEN}" \
              -H "Content-Type: application/json" \
              "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}")"
if [ "$(echo "$ZRESP" | jq -r '.success')" != "true" ]; then
  echo "[ERR] Cloudflare API misslyckades:"; echo "$ZRESP" | jq -r '.errors[]?.message // .'; exit 3
fi
CF_ZONE_ID="$(echo "$ZRESP" | jq -r '.result[0].id')"
[ -n "$CF_ZONE_ID" ] || { echo "[ERR] Zone ID saknas för ${DOMAIN}."; exit 4; }

cat > "$HOME/.cf_token" <<EOF
CF_API_TOKEN=${CF_API_TOKEN}
CF_ZONE_ID=${CF_ZONE_ID}
EOF
chmod 600 "$HOME/.cf_token"
echo "[OK] Skrev ~/.cf_token"

API="https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/settings"
H="Authorization: Bearer ${CF_API_TOKEN}"
C="Content-Type: application/json"

patch_on(){ curl -sS -X PATCH "${API}/$1" -H "$H" -H "$C" --data '{"value":"on"}' >/dev/null; }
patch_val(){ curl -sS -X PATCH "${API}/$1" -H "$H" -H "$C" --data "{\"value\":\"$2\"}" >/dev/null; }

echo "[*] Tvingar HTTPS och säkra protokoll i Cloudflare ..."
curl -sS -X PATCH "${API}/ssl" -H "$H" -H "$C" --data '{"value":"strict"}' >/dev/null
patch_on always_use_https
patch_on automatic_https_rewrites
patch_on tls_1_3
patch_val min_tls_version "1.2"
patch_on opportunistic_encryption
patch_on http2 || true
patch_on http3 || true
curl -sS -X PATCH "${API}/security_header" -H "$H" -H "$C" --data '{
  "value": { "strict_transport_security": {
    "enabled": true, "max_age": 31536000, "include_subdomains": true, "preload": false }}}' >/dev/null || true

echo "[*] Status:"
for k in ssl always_use_https automatic_https_rewrites tls_1_3 min_tls_version opportunistic_encryption http2 http3; do
  v=$(curl -sS -H "$H" "${API}/${k}" | jq -r '.result.value // empty')
  printf " - %-28s %s\n" "$k" "${v:-unknown}"
done

echo "[DONE] Cloudflare klart. Gå till GitHub Pages → Settings → Pages → Enforce HTTPS."
