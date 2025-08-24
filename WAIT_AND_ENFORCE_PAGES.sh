#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C
OWNER="${OWNER:-IAIONEX}"
REPO="${REPO:-IAIONEX.github.io}"
DOMAIN="${DOMAIN:-iaionex.com}"
GH_FILE="${GH_FILE:-$HOME/.gh_token}"
INTERVAL="${INTERVAL:-60}"   # sek mellan kontroller

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need curl jq coreutils

[ -f "$GH_FILE" ] || { read -r -p "GitHub PAT: " -s GH; echo; printf "%s\n" "$GH" > "$GH_FILE"; chmod 600 "$GH_FILE"; }
GH="$(head -n1 "$GH_FILE" | tr -d '\r\n')"
API="https://api.github.com/repos/${OWNER}/${REPO}/pages"
HDR=(-H "Authorization: Bearer ${GH}" -H "Accept: application/vnd.github+json")

echo "[IAX] Bevakar GitHub Pages certifikat för $OWNER/$REPO (domain=$DOMAIN)"
while :; do
  R="$(curl -sS "${HDR[@]}" "$API")" || true
  STATE="$(echo "$R" | jq -r '.https_certificate.state // empty')"
  ENF="$(echo "$R"   | jq -r '.https_enforced // empty')"
  CNAME="$(echo "$R"| jq -r '.cname // empty')"
  DNS_OK="$(echo "$R"| jq -r '.status // empty')"  # deprecated, men informativ

  printf "[%s] cert=%s enforce=%s cname=%s status=%s\n" "$(date -u +%H:%M:%S)" "${STATE:-na}" "${ENF:-na}" "${CNAME:-na}" "${DNS_OK:-na}"

  if [ "${STATE}" = "approved" ]; then
    if [ "$ENF" != "true" ]; then
      echo "[IAX] Sätter Enforce HTTPS via API..."
      curl -sS -X PUT "${HDR[@]}" "$API" \
        -d '{"https_enforced":true}' >/dev/null
      # läs om
      R="$(curl -sS "${HDR[@]}" "$API")"
      ENF="$(echo "$R" | jq -r '.https_enforced // empty')"
      echo "[IAX] enforce_https=${ENF}"
    fi
    echo "[IAX] Verifierar http->https och HSTS..."
    curl -sSI "http://${DOMAIN}"  | awk '/^HTTP|^Location/{print}'
    curl -sSI "https://${DOMAIN}" | awk '/^HTTP|^Strict-Transport-Security/{print}'
    echo "[DONE]"
    exit 0
  fi
  sleep "$INTERVAL"
done
