#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C

DOMAIN="${DOMAIN:-iaionex.com}"
CF_FILE="${CF_FILE:-$HOME/.cf_token}"
GH_FILE="${GH_FILE:-$HOME/.gh_token}"

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need curl jq coreutils

err(){ echo "[ERR] $*" >&2; exit 1; }
ok(){  printf "[OK] %s\n" "$*"; }

# --- GitHub PAT ---
[ -f "$GH_FILE" ] || err "~/.gh_token saknas"
GH_PAT="$(head -n1 "$GH_FILE" | tr -d '\r\n ' )"
[ -n "$GH_PAT" ] || err "GitHub PAT tom"
code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $GH_PAT" https://api.github.com/user)"
[ "$code" = "200" ] || err "GitHub PAT ogiltig eller saknar rättigheter (HTTP $code)"
ok "GitHub PAT accepterad"

# --- Cloudflare token + zone ---
[ -f "$CF_FILE" ] || err "~/.cf_token saknas"
# Stöd båda formaten: ren token eller KEY=VAL
CF_API_TOKEN=""; CF_ZONE_ID=""
if grep -q 'CF_API_TOKEN=' "$CF_FILE"; then . "$CF_FILE"; else CF_API_TOKEN="$(tr -d '[:space:]' < "$CF_FILE")"; fi
[ -n "${CF_API_TOKEN:-}" ] || err "CF_API_TOKEN tom"

# Hämta zone id om saknas
if [ -z "${CF_ZONE_ID:-}" ]; then
  ZRESP="$(curl -s -H "Authorization: Bearer ${CF_API_TOKEN}" "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}")"
  [ "$(echo "$ZRESP" | jq -r '.success')" = "true" ] || err "Cloudflare API fel: $(echo "$ZRESP" | jq -r '.errors[0].message')"
  CF_ZONE_ID="$(echo "$ZRESP" | jq -r '.result[0].id // empty')"
  [ -n "$CF_ZONE_ID" ] || err "Ingen zone för $DOMAIN"
fi

# Verifiera zon-åtkomst
ZCODE="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${CF_API_TOKEN}" "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}")"
[ "$ZCODE" = "200" ] || err "Cloudflare token saknar zon-åtkomst (HTTP $ZCODE)"
ok "Cloudflare token accepterad och har åtkomst till zon $CF_ZONE_ID"

# Rekommenderade scopes (informativt)
echo "[INFO] Rekommenderade Cloudflare token-rättigheter: Zone:Read, Zone:DNS:Edit, Zone:Settings:Edit"
echo "[INFO] Rekommenderade GitHub scopes: repo"

# Spara normaliserat format
printf "CF_API_TOKEN=%s\nCF_ZONE_ID=%s\n" "$CF_API_TOKEN" "$CF_ZONE_ID" > "$CF_FILE"
chmod 600 "$CF_FILE"

ok "Token-test klart"
