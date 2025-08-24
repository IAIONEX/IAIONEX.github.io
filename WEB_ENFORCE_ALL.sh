#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C
DOMAIN="${DOMAIN:-iaionex.com}"
OWNER="${OWNER:-IAIONEX}"
REPO="${REPO:-IAIONEX.github.io}"
WEB="${WEB:-$HOME/IAIONEX.WEB}"
GH_TOKEN_FILE="${GH_TOKEN_FILE:-$HOME/.gh_token}"

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need curl jq git coreutils sed awk grep

# --- Cloudflare creds ---
if [ ! -f "$HOME/.cf_token" ]; then
  printf "[ERR] ~/.cf_token saknas. Skapa med CF_API_TOKEN och CF_ZONE_ID.\n"; exit 2
fi
# shellcheck disable=SC1090
. "$HOME/.cf_token"; : "${CF_API_TOKEN:?}"; : "${CF_ZONE_ID:?}"

# --- GitHub token ---
if [ ! -f "$GH_TOKEN_FILE" ]; then
  printf "[ERR] %s saknas. Lägg PAT som ren sträng.\n" "$GH_TOKEN_FILE"; exit 3
fi
GH_PAT="$(head -n1 "$GH_TOKEN_FILE" | tr -d '\r\n')"
[ -n "$GH_PAT" ] || { echo "[ERR] PAT tom."; exit 4; }

# --- 1) Cloudflare: tvinga HTTPS/TLS/HSTS ---
API_CF="https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/settings"
HCF=("Authorization: Bearer ${CF_API_TOKEN}" "Content-Type: application/json")
patch_on(){ curl -sS -X PATCH "$API_CF/$1" -H "${HCF[0]}" -H "${HCF[1]}" --data '{"value":"on"}' >/dev/null; }
patch_val(){ curl -sS -X PATCH "$API_CF/$1" -H "${HCF[0]}" -H "${HCF[1]}" --data "{\"value\":\"$2\"}" >/dev/null; }

curl -sS -X PATCH "$API_CF/ssl" -H "${HCF[0]}" -H "${HCF[1]}" --data '{"value":"strict"}' >/dev/null
patch_on always_use_https
patch_on automatic_https_rewrites
patch_on tls_1_3
patch_val min_tls_version "1.2"
patch_on opportunistic_encryption
patch_on http2 || true
patch_on http3 || true
curl -sS -X PATCH "$API_CF/security_header" -H "${HCF[0]}" -H "${HCF[1]}" --data \
'{"value":{"strict_transport_security":{"enabled":true,"max_age":31536000,"include_subdomains":true,"preload":false}}}' >/dev/null || true

# --- 2) GitHub Pages repo: säkerställ CNAME + CSP upgrade ---
mkdir -p "$WEB"; cd "$WEB"
if [ ! -d ".git" ]; then
  git init; git remote add origin "https://github.com/${OWNER}/${REPO}.git" || true
  git fetch origin >/dev/null 2>&1 || true
  git checkout -B main || git checkout -B master
  git pull --rebase origin main >/dev/null 2>&1 || git pull --rebase origin master >/dev/null 2>&1 || true
fi

echo "$DOMAIN" > CNAME

# Lägg CSP meta i index.html (upgrade-insecure-requests) om saknas
if [ -f index.html ] && ! grep -qi 'upgrade-insecure-requests' index.html; then
  awk 'BEGIN{added=0}
  /<head[^>]*>/ && added==0 {print; print "<meta http-equiv=\"Content-Security-Policy\" content=\"upgrade-insecure-requests\">"; added=1; next}
  {print}' index.html > .ix && mv .ix index.html
fi

git add CNAME index.html 2>/dev/null || git add CNAME 2>/dev/null || true
if ! git diff --cached --quiet; then
  git -c user.email="pages@${DOMAIN}" -c user.name="IAIONEX.AB" commit -m "enforce https: CNAME + CSP upgrade"
  git push "https://${GH_PAT}:x-oauth-basic@github.com/${OWNER}/${REPO}.git" HEAD:main >/dev/null 2>&1 || \
  git push "https://${GH_PAT}:x-oauth-basic@github.com/${OWNER}/${REPO}.git" HEAD:master >/dev/null 2>&1
fi

# --- 3) Försök API: Enforce HTTPS (om stöds) ---
API_GH="https://api.github.com/repos/${OWNER}/${REPO}/pages"
curl -sS -H "Authorization: Bearer ${GH_PAT}" -H "Accept: application/vnd.github+json" "$API_GH" >/dev/null 2>&1 || true
# Vissa konton kräver manuell toggle i UI; därför gör vi en HEAD-check istället.

# --- 4) Verifiering http→https och HSTS ---
echo "[VERIFY] Begär http://$DOMAIN → ska bli 301/308 till https"
curl -sSI "http://$DOMAIN" -o /tmp/iax_http.head 2>/dev/null || true
code_http="$(awk 'toupper($0)~^HTTP {print $2; exit}' /tmp/iax_http.head 2>/dev/null || true)"
loc_http="$(awk 'BEGIN{IGNORECASE=1} /^Location:/{print $2; exit}' /tmp/iax_http.head 2>/dev/null || true)"

echo "[VERIFY] Begär https://$DOMAIN → ska ge cert + HSTS"
curl -sSI "https://$DOMAIN" -o /tmp/iax_https.head 2>/dev/null || true
code_https="$(awk 'toupper($0)~^HTTP {print $2; exit}' /tmp/iax_https.head 2>/dev/null || true)"
hsts="$(awk 'BEGIN{IGNORECASE=1} /^Strict-Transport-Security:/{print; exit}' /tmp/iax_https.head 2>/dev/null || true)"

printf "http code: %s  location: %s\n" "${code_http:-NA}" "${loc_http:-NA}"
printf "https code: %s  HSTS: %s\n" "${code_https:-NA}" "${hsts:-none}"

echo "[DONE] Cloudflare och GitHub Pages konfigurerat. Om GitHub UI-flaggan 'Enforce HTTPS' fortfarande är av, slå på den i repo Settings → Pages."
