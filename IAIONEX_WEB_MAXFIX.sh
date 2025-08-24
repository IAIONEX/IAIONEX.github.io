#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C

DOMAIN="iaionex.com"
OWNER="IAIONEX"
REPO="IAIONEX.github.io"
WEB="$HOME/IAIONEX.WEB"
CF_FILE="$HOME/.cf_token"
GH_FILE="$HOME/.gh_token"
BACKUP_DIR="$HOME/backups"
LEDGER_DIR="$HOME/IAIONEX.AB/ledger"
IAIONEX_UID="IAIONEX.70ID"
OWNER_NAME="JOHAN GÄRTNER"
COMPANY="IAIONEX.AB"
ORCID="0009-0001-9029-1379"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

# --- deps ---
need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need curl jq git coreutils sed grep tar zstd

mkdir -p "$WEB" "$BACKUP_DIR" "$LEDGER_DIR"

# --- tokens ---
[ -f "$CF_FILE" ] && . "$CF_FILE" || true
CF_API_TOKEN="${CF_API_TOKEN:-}"; CF_ZONE_ID="${CF_ZONE_ID:-}"
[ -z "$CF_API_TOKEN" ] && { read -r -p "Cloudflare API token: " -s CF_API_TOKEN; echo; }
if [ -z "$CF_ZONE_ID" ]; then
  ZRESP="$(curl -fsS -H "Authorization: Bearer $CF_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN")"
  CF_ZONE_ID="$(echo "$ZRESP" | jq -r '.result[0].id')"
  echo "CF_API_TOKEN=$CF_API_TOKEN" > "$CF_FILE"; echo "CF_ZONE_ID=$CF_ZONE_ID" >> "$CF_FILE"; chmod 600 "$CF_FILE"
fi

[ -f "$GH_FILE" ] || { read -r -p "GitHub PAT: " -s GH; echo; printf "%s\n" "$GH" > "$GH_FILE"; chmod 600 "$GH_FILE"; }
GH_PAT="$(head -n1 "$GH_FILE" | tr -d '\r\n')"

# --- Cloudflare DNS ---
API_CF="https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID"
AUTH_CF=(-H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json")
IPS=(185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153)
for ip in "${IPS[@]}"; do
  if ! dig +short "$DOMAIN" A | grep -q "$ip"; then
    curl -fsS -X POST "${AUTH_CF[@]}" "$API_CF/dns_records" \
      --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}" >/dev/null
  fi
done
if ! dig +short www."$DOMAIN" CNAME | grep -q "$OWNER.github.io."; then
  curl -fsS -X POST "${AUTH_CF[@]}" "$API_CF/dns_records" \
    --data "{\"type\":\"CNAME\",\"name\":\"www.$DOMAIN\",\"content\":\"$OWNER.github.io\",\"ttl\":1,\"proxied\":false}" >/dev/null
fi

# --- Cloudflare SSL/HSTS ---
curl -fsS -X PATCH "$API_CF/settings/ssl"     "${AUTH_CF[@]}" --data '{"value":"strict"}' >/dev/null || true
for k in always_use_https automatic_https_rewrites tls_1_3 opportunistic_encryption http2 http3; do
  curl -fsS -X PATCH "$API_CF/settings/$k" "${AUTH_CF[@]}" --data '{"value":"on"}' >/dev/null || true
done
curl -fsS -X PATCH "$API_CF/settings/security_header" "${AUTH_CF[@]}" \
  --data '{"value":{"strict_transport_security":{"enabled":true,"max_age":31536000,"include_subdomains":true,"preload":false}}}' >/dev/null || true

# --- GitHub Pages canonical + push ---
cd "$WEB"
echo "$DOMAIN" > CNAME
if [ -f index.html ] && ! grep -qi 'rel="canonical"' index.html; then
  sed -i '/<head>/a <link rel="canonical" href="https://'"$DOMAIN"'"/>' index.html
fi
if [ ! -d .git ]; then
  git init; git branch -M main
  git remote add origin "https://github.com/$OWNER/$REPO.git" || true
fi
git add -A
if ! git diff --cached --quiet; then
  git -c user.email="pages@$DOMAIN" -c user.name="$COMPANY" commit -m "MAXFIX $TS"
  git push "https://$GH_PAT@github.com/$OWNER/$REPO.git" HEAD:main
fi

# --- Verify ---
curl -sSI "http://$DOMAIN"  | grep -E 'HTTP|Location'
curl -sSI "https://$DOMAIN" | grep -E 'HTTP|Strict-Transport-Security|Location'

# --- Backup + ledger ---
SNAP="$BACKUP_DIR/iaionex_websnap_${TS}.tar.zst"
tar -I zstd -cf "$SNAP" "$WEB" "$CF_FILE" "$GH_FILE" "$HOME/IAIONEX.AB" 2>/dev/null || true
SHA="$(sha256sum "$SNAP" | cut -d' ' -f1)"
LOG="$LEDGER_DIR/ledger_webfix.ndjson"
echo "{\"ts\":\"$TS\",\"uid\":\"$IAIONEX_UID\",\"owner\":\"$OWNER_NAME\",\"company\":\"$COMPANY\",\"orcid\":\"$ORCID\",\"domain\":\"$DOMAIN\",\"snapshot\":\"$(basename "$SNAP")\",\"sha256\":\"$SHA\"}" >> "$LOG"

echo "[DONE] IAIONEX WEB MAXFIX klar. Snapshot: $SNAP"
