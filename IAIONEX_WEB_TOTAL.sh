if [ -f index.html ] && ! grep -qi "rel=\"canonical\"" index.html; then
  sed -i '/<head>/a <link rel="canonical" href="https://iaionex.com/">' index.html
fi
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C

# Sanera ev. CRLF i skript som råkats inklistras fel
if grep -q $'\r' "$0" 2>/dev/null; then sed -i 's/\r$//' "$0"; fi

DOMAIN="iaionex.com"
OWNER="IAIONEX"
REPO="IAIONEX.github.io"
WEB="$HOME/IAIONEX.WEB"
CF_FILE="$HOME/.cf_token"
GH_FILE="$HOME/.gh_token"
INTERVAL=60
BACKUP_DIR="$HOME/backups"
LEDGER_DIR="$HOME/IAIONEX.AB/ledger"
IAIONEX_UID="IAIONEX.70ID"
OWNER_NAME="JOHAN GÄRTNER"
COMPANY="IAIONEX.AB"
ORCID="0009-0001-9029-1379"

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need curl jq git coreutils sed grep tar
command -v sha256sum >/dev/null 2>&1 || need busybox
command -v zstd >/dev/null 2>&1 || pkg install -y zstd >/dev/null || true
command -v dig  >/dev/null 2>&1 || pkg install -y dnsutils >/dev/null || true
command -v chattr >/dev/null 2>&1 || true

mkdir -p "$WEB" "$BACKUP_DIR" "$LEDGER_DIR"

ts_utc(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
TS="$(ts_utc)"

unlock_ledger(){ [ -f "$1" ] || return 0; command -v chattr >/dev/null 2>&1 && chattr -i "$1" 2>/dev/null || true; chmod u+w "$1" 2>/dev/null || true; }
lock_ledger(){   [ -f "$1" ] || return 0; chmod 400 "$1" 2>/dev/null || true; command -v chattr >/dev/null 2>&1 && chattr +i "$1" 2>/dev/null || true; }

# --- Tokens ---
if [ -f "$CF_FILE" ]; then
  if grep -q 'CF_API_TOKEN=' "$CF_FILE"; then . "$CF_FILE"; else CF_API_TOKEN="$(tr -d '[:space:]' < "$CF_FILE")"; fi
fi
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ZONE_ID="${CF_ZONE_ID:-}"

if [ -z "${CF_API_TOKEN}" ]; then
  read -r -p "Cloudflare API token: " -s CF_API_TOKEN; echo
fi

[ -f "$GH_FILE" ] || { read -r -p "GitHub PAT: " -s GH; echo; printf "%s\n" "$GH" > "$GH_FILE"; chmod 600 "$GH_FILE"; }
GH_PAT="$(head -n1 "$GH_FILE" | tr -d '\r\n')"

if [ -z "${CF_ZONE_ID}" ]; then
  ZRESP="$(curl -fsS -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}")" || { echo "[ERR] Cloudflare API ned"; exit 1; }
  CF_ZONE_ID="$(echo "$ZRESP" | jq -r '.result[0].id // empty')"
  [ -n "$CF_ZONE_ID" ] || { echo "[ERR] Zone saknas för ${DOMAIN}"; exit 1; }
  printf "CF_API_TOKEN=%s\nCF_ZONE_ID=%s\n" "$CF_API_TOKEN" "$CF_ZONE_ID" > "$CF_FILE"; chmod 600 "$CF_FILE"
fi

# --- Cloudflare DNS (utan funktionsdefinitioner) ---
API_CF_ZONE="https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}"
HCF_AUTH="Authorization: Bearer ${CF_API_TOKEN}"
HCF_CT="Content-Type: application/json"
IPS=(185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153)
WWW="www.${DOMAIN}"
CNAME_TARGET="${OWNER}.github.io"

CUR_A_JSON="$(curl -fsS -H "$HCF_AUTH" "${API_CF_ZONE}/dns_records?per_page=100&type=A&name=${DOMAIN}" || echo '')"
for ip in "${IPS[@]}"; do
  ok="$(echo "$CUR_A_JSON" | jq -r --arg ip "$ip" '.result[]?|select(.content==$ip)|.id' 2>/dev/null || true)"
  if [ -z "${ok:-}" ]; then
    curl -fsS -X POST -H "$HCF_AUTH" -H "$HCF_CT" "${API_CF_ZONE}/dns_records" \
      --data "{\"type\":\"A\",\"name\":\"${DOMAIN}\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}" >/dev/null
  fi
done

CUR_C_JSON="$(curl -fsS -H "$HCF_AUTH" "${API_CF_ZONE}/dns_records?per_page=100&type=CNAME&name=${WWW}" || echo '')"
have_www="$(echo "$CUR_C_JSON" | jq -r ".result[]?|select(.content==\"${CNAME_TARGET}\")|.id" 2>/dev/null || true)"
if [ -z "${have_www:-}" ]; then
  curl -fsS -X POST -H "$HCF_AUTH" -H "$HCF_CT" "${API_CF_ZONE}/dns_records" \
    --data "{\"type\":\"CNAME\",\"name\":\"${WWW}\",\"content\":\"${CNAME_TARGET}\",\"ttl\":1,\"proxied\":false}" >/dev/null
fi

# --- Cloudflare SSL/HSTS ---
curl -fsS -X PATCH "${API_CF_ZONE}/settings/ssl" -H "$HCF_AUTH" -H "$HCF_CT" --data '{"value":"strict"}' >/dev/null || true
for k in always_use_https automatic_https_rewrites tls_1_3 opportunistic_encryption http2 http3; do
  curl -fsS -X PATCH "${API_CF_ZONE}/settings/$k" -H "$HCF_AUTH" -H "$HCF_CT" --data '{"value":"on"}' >/dev/null || true
done
curl -fsS -X PATCH "${API_CF_ZONE}/settings/min_tls_version" -H "$HCF_AUTH" -H "$HCF_CT" --data '{"value":"1.2"}' >/dev/null || true
curl -fsS -X PATCH "${API_CF_ZONE}/settings/security_header" -H "$HCF_AUTH" -H "$HCF_CT" --data '{"value":{"strict_transport_security":{"enabled":true,"max_age":31536000,"include_subdomains":true,"preload":false}}}' >/dev/null || true

# --- GitHub Pages push ---
cd "$WEB"
echo "$DOMAIN" > CNAME
if [ ! -f index.html ]; then
  cat > index.html <<'H'
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>IAIONEX</title>
<meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
<style>html,body{margin:0;padding:0;height:100%;font-family:system-ui,Arial}main{min-height:100%;display:grid;place-items:center;text-align:center}h1{letter-spacing:.06em}small{opacity:.7}</style>
</head><body><main>
<div>
<h1>IAIONEX — Sovereign Offline AI</h1>
<p>UID: IAIONEX.70ID • Owner: JOHAN GÄRTNER • ORCID: 0009-0001-9029-1379</p>
<small>Domain: iaionex.com • Pages via GitHub • DNS via Cloudflare • Deterministic • Offline-first</small>
</div>
</main></body></html>
H
fi
if ! grep -qi 'upgrade-insecure-requests' index.html; then
  sed -n '1,/<head>/p' index.html > .ix && \
  printf '<meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">\n' >> .ix && \
  sed -n '/<head>/{n;:a;p;n;ba};$p' index.html >> .ix && mv .ix index.html
fi

git init >/dev/null 2>&1 || true
if ! git rev-parse --verify main >/dev/null 2>&1; then
  git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
fi
git add -A
if ! git diff --cached --quiet; then
  git -c user.email="pages@${DOMAIN}" -c user.name="${COMPANY}" commit -m "IAIONEX.WEB enforce DNS/HTTPS $(ts_utc)" >/dev/null
fi
git push "https://${GH_PAT}:x-oauth-basic@github.com/${OWNER}/${REPO}.git" HEAD:main 2>/dev/null || \
git push "https://${GH_PAT}:x-oauth-basic@github.com/${OWNER}/${REPO}.git" HEAD:master

# --- Cert-bevakning ---
API_GH="https://api.github.com/repos/${OWNER}/${REPO}/pages"
while :; do
  R="$(curl -fsS -H "Authorization: Bearer ${GH_PAT}" -H "Accept: application/vnd.github+json" "$API_GH")" || R=''
  STATE="$(echo "$R" | jq -r '.https_certificate.state // empty' 2>/dev/null || true)"
  ENF="$(echo "$R" | jq -r '.https_enforced // empty' 2>/dev/null || true)"
  printf "[%s] cert=%s enforce=%s\n" "$(date -u +%H:%M:%S)" "${STATE:-}" "${ENF:-}"
  if [ "${STATE:-}" = "approved" ]; then
    if [ "${ENF:-}" != "true" ]; then
      curl -fsS -X PUT -H "Authorization: Bearer ${GH_PAT}" -H "Accept: application/vnd.github+json" "$API_GH" -d '{"https_enforced":true}' >/dev/null || true
    fi
    break
  fi
  sleep "$INTERVAL"
done

# Snabb kontroll
curl -sSI "http://${DOMAIN}"  | grep -E '^(HTTP|Location)'
curl -sSI "https://${DOMAIN}" | grep -E '^(HTTP|Strict-Transport-Security|Location)'

# --- Backup + ledger ---
SNAP="$BACKUP_DIR/iaionex_websnap_$(echo "$TS" | tr -d ':-').tar.zst"
tar -I zstd -cf "$SNAP" "$HOME/IAIONEX.WEB" "$HOME/IAIONEX.AB" "$HOME/.cf_token" "$HOME/.gh_token" 2>/dev/null || true

if command -v sha256sum >/dev/null 2>&1; then
  SHA="$(sha256sum "$SNAP" | cut -d' ' -f1)"
else
  SHA="$(busybox sha256sum "$SNAP" | cut -d' ' -f1)"
fi

LOG="$LEDGER_DIR/ledger_webfix.ndjson"
unlock_ledger "$LOG"
printf '{"ts":"%s","uid":"%s","owner":"%s","company":"%s","orcid":"%s","domain":"%s","snapshot":"%s","sha256":"%s"}\n' \
  "$TS" "$IAIONEX_UID" "$OWNER_NAME" "$COMPANY" "$ORCID" "$DOMAIN" "$(basename "$SNAP")" "$SHA" >> "$LOG"
lock_ledger "$LOG"

echo "[DONE]"
