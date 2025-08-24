#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; export LC_ALL=C
DOMAIN="${DOMAIN:-iaionex.com}"
WWW="www.${DOMAIN}"

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need curl jq coreutils dnsutils

# Cloudflare creds
[ -f "$HOME/.cf_token" ] || { echo "[ERR] ~/.cf_token saknas"; exit 2; }
. "$HOME/.cf_token"; : "${CF_API_TOKEN:?}"; : "${CF_ZONE_ID:?}"
HCF=("Authorization: Bearer ${CF_API_TOKEN}" "Content-Type: application/json")
API="https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}"

# GitHub Pages IP:er
IPS=(185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153)
CNAME_TARGET="IAIONEX.github.io"   # ändra om org/repo byts

# helper
cf_list(){ curl -sS -H "${HCF[0]}" "${API}/dns_records?per_page=100&type=$1&name=$2"; }
cf_del(){ curl -sS -X DELETE -H "${HCF[0]}" "${API}/dns_records/$1" >/dev/null; }
cf_add_a(){ curl -sS -X POST -H "${HCF[0]}" -H "${HCF[1]}" "${API}/dns_records" \
  --data "{\"type\":\"A\",\"name\":\"${DOMAIN}\",\"content\":\"$1\",\"ttl\":1,\"proxied\":false}" >/dev/null; }
cf_add_cname(){ curl -sS -X POST -H "${HCF[0]}" -H "${HCF[1]}" "${API}/dns_records" \
  --data "{\"type\":\"CNAME\",\"name\":\"${WWW}\",\"content\":\"${CNAME_TARGET}\",\"ttl\":1,\"proxied\":false}" >/dev/null; }

echo "[CF] Rensar felaktiga A-poster för ${DOMAIN}"
CUR_A_JSON="$(cf_list A "${DOMAIN}")"
mapfile -t CUR_A_IDS < <(echo "$CUR_A_JSON" | jq -r '.result[] | select(.content|test("^185\\.199\\." )|not) | .id')
for id in "${CUR_A_IDS[@]:-}"; do [ -n "$id" ] && cf_del "$id"; done

echo "[CF] Säkerställer A-poster -> GitHub Pages"
for ip in "${IPS[@]}"; do
  have=$(echo "$CUR_A_JSON" | jq -r --arg ip "$ip" '.result[]?|select(.content==$ip)|.id' | head -1)
  if [ -z "$have" ]; then cf_add_a "$ip"; fi
done

echo "[CF] Rensar felaktiga CNAME för ${WWW}"
CUR_C_JSON="$(cf_list CNAME "${WWW}")"
mapfile -t CUR_C_IDS < <(echo "$CUR_C_JSON" | jq -r ".result[] | select(.content!=\"${CNAME_TARGET}\") | .id")
for id in "${CUR_C_IDS[@]:-}"; do [ -n "$id" ] && cf_del "$id"; done

echo "[CF] Säkerställer CNAME ${WWW} -> ${CNAME_TARGET}"
have_www=$(echo "$CUR_C_JSON" | jq -r ".result[]?|select(.content==\"${CNAME_TARGET}\")|.id" | head -1)
[ -n "$have_www" ] || cf_add_cname

echo "[CHECK] DNS-resolver"
dig +short "${DOMAIN}"    | sed 's/^/A  /'
dig +short "${WWW}" CNAME | sed 's/^/C  /'

echo "[VERIFY] http->https och HSTS (när cert är utfärdat)"
curl -sSI "http://${DOMAIN}"  | awk '/^HTTP|^Location/{print}'
curl -sSI "https://${DOMAIN}" | awk '/^HTTP|^Strict-Transport-Security/{print}'

# sätt Cloudflare HTTPS/HSTS igen för säkerhets skull om skript finns
if [ -x "$HOME/IAIONEX.WEB/CF_SETUP_AND_ENFORCE.sh" ]; then
  bash "$HOME/IAIONEX.WEB/CF_SETUP_AND_ENFORCE.sh" </dev/tty || true
fi

echo "[DONE] DNS fix klar. Gå till GitHub Pages Settings → Pages och bocka i Enforce HTTPS när DNS-checken är klar."
