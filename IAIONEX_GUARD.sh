#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C

# färger
if command -v tput >/dev/null 2>&1; then G="$(tput setaf 2)";R="$(tput setaf 1)";Y="$(tput setaf 3)";N="$(tput sgr0)"; else G="";R="";Y="";N=""; fi
ok(){   printf "%s[OK]%s  %s\n"   "$G" "$N" "$*"; }
fail(){ printf "%s[FAIL]%s %s\n" "$R" "$N" "$*"; exit 1; }
step(){ printf "%s>>>%s  %s\n"  "$Y" "$N" "$*"; }

# konfig
DOMAIN="${DOMAIN:-iaionex.com}"
OWNER="${OWNER:-IAIONEX}"
REPO="${REPO:-IAIONEX.github.io}"
CF_FILE="${CF_FILE:-$HOME/.cf_token}"
GH_FILE="${GH_FILE:-$HOME/.gh_token}"
CF_API="https://api.cloudflare.com/client/v4"
GH_API="https://api.github.com"

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need curl jq coreutils

# tokens
step "Laddar tokens"
[ -f "$GH_FILE" ] || fail "~/.gh_token saknas"
GH_PAT="$(head -n1 "$GH_FILE" | tr -d '\r\n ')"
[ -n "$GH_PAT" ] || fail "GitHub PAT tom"

[ -f "$CF_FILE" ] || fail "~/.cf_token saknas"
CF_API_TOKEN=""; CF_ZONE_ID=""
if grep -q 'CF_API_TOKEN=' "$CF_FILE"; then . "$CF_FILE"; else CF_API_TOKEN="$(tr -d '[:space:]' < "$CF_FILE")"; fi
[ -n "${CF_API_TOKEN:-}" ] || fail "CF_API_TOKEN tom"
ok "Tokens laddade"

# hämta zone-id vid behov
if [ -z "${CF_ZONE_ID:-}" ]; then
  step "Hämtar Cloudflare Zone ID för $DOMAIN"
  zid_json="$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" "$CF_API/zones?name=$DOMAIN")"
  [ "$(echo "$zid_json" | jq -r '.success')" = "true" ] || fail "Cloudflare API fel: $(echo "$zid_json" | jq -r '.errors[0].message')"
  CF_ZONE_ID="$(echo "$zid_json" | jq -r '.result[0].id // empty')"
  [ -n "$CF_ZONE_ID" ] || fail "Ingen Cloudflare-zon för $DOMAIN"
  ok "Zone ID: $CF_ZONE_ID"
fi
H_AUTH=(-H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json")

# GitHub: PAT
step "GitHub: verifierar PAT"
c1="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $GH_PAT" "$GH_API/user")"
[ "$c1" = "200" ] || fail "PAT ogiltig (HTTP $c1). Behövs: repo (eller fine-grained: Pages RW, Contents RW, Metadata R)."
ok "PAT verifierad"

# GitHub: Pages read + detaljerad logg
step "GitHub: Pages read + statuslogg"
PAGES_EP="$GH_API/repos/$OWNER/$REPO/pages"
resp="$(curl -s -H "Authorization: Bearer $GH_PAT" -H "Accept: application/vnd.github+json" "$PAGES_EP" || true)"
code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $GH_PAT" -H "Accept: application/vnd.github+json" "$PAGES_EP")"
if [ "$code" != "200" ]; then
  echo "$resp" | jq . 2>/dev/null || true
  fail "Pages read nekad (HTTP $code)"
fi
state="$(echo "$resp" | jq -r '.https_certificate.state // "none"')"
enf="$(echo "$resp"   | jq -r '.https_enforced // false')"
cname="$(echo "$resp" | jq -r '.cname // ""')"
printf "    cert_state=%s  enforce=%s  cname=%s\n" "$state" "$enf" "$cname"
ok "Pages read OK"

# GitHub: Pages write test (PUT oförändrat)
step "GitHub: Pages write test"
c3="$(curl -s -o /dev/null -w '%{http_code}' -X PUT -d "{\"https_enforced\":$enf}" \
      -H "Authorization: Bearer $GH_PAT" -H "Accept: application/vnd.github+json" "$PAGES_EP")"
{ [ "$c3" = "200" ] || [ "$c3" = "202" ]; } || fail "Pages write nekad (HTTP $c3)"
ok "Pages write OK"

# Cloudflare tester
step "Cloudflare: zon-read"
c4="$(curl -s -o /dev/null -w '%{http_code}' "${H_AUTH[@]}" "$CF_API/zones/$CF_ZONE_ID")"
[ "$c4" = "200" ] || fail "Zon-read nekad (HTTP $c4)"
ok "Zon-read OK"

step "Cloudflare: DNS-edit test (TXT skapa/radera)"
TEST="_iax_perm_test-$(date -u +%H%M%S)"
resp="$(curl -s -X POST "${H_AUTH[@]}" "$CF_API/zones/$CF_ZONE_ID/dns_records" \
        --data "{\"type\":\"TXT\",\"name\":\"$TEST\",\"content\":\"perm-test\",\"ttl\":60,\"proxied\":false}")"
if [ "$(echo "$resp" | jq -r '.success')" = "true" ]; then
  rid="$(echo "$resp" | jq -r '.result.id')"
  curl -s -X DELETE "${H_AUTH[@]}" "$CF_API/zones/$CF_ZONE_ID/dns_records/$rid" >/dev/null || true
  ok "DNS-edit OK"
else
  echo "$resp" | jq . 2>/dev/null || true
  fail "DNS-edit nekad. Behövs: Zone.DNS:Edit"
fi

step "Cloudflare: settings-write test (PATCH ssl oförändrat)"
curr_ssl="$(curl -s "${H_AUTH[@]}" "$CF_API/zones/$CF_ZONE_ID/settings/ssl" | jq -r '.result.value // "strict"')"
c6="$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "${H_AUTH[@]}" \
      "$CF_API/zones/$CF_ZONE_ID/settings/ssl" --data "{\"value\":\"$curr_ssl\"}")"
[ "$c6" = "200" ] || fail "Settings-write nekad (HTTP $c6). Behövs: Zone.Settings:Edit"
ok "Settings-write OK"

ok "Alla rättigheter OK. Startar IAIONEX_WEB_TOTAL.sh"
exec bash "$HOME/IAIONEX.WEB/IAIONEX_WEB_TOTAL.sh"
