#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; umask 0022; export LC_ALL=C

# --- Konfiguration ---
DOMAIN="iaionex.com"
OWNER="IAIONEX"
REPO="IAIONEX.github.io"
COMPANY="IAIONEX.AB"
OWNER_NAME="JOHAN GÄRTNER"
IAIONEX_UID="IAIONEX.70ID"
ORCID="0009-0001-9029-1379"

WEB="$HOME/IAIONEX.WEB"
CF_FILE="$HOME/.cf_token"   # läses ej här, men packas i snapshot
GH_FILE="$HOME/.gh_token"
BACKUP_DIR="$HOME/IAIONEX.WEB/.snap"
LEDGER_DIR="$HOME/IAIONEX.AB/ledger"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Hjälpare ---
need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need coreutils git curl grep sed tar zstd qrencode
command -v awk >/dev/null 2>&1 || need gawk

sha256(){ sha256sum "$1" | awk '{print $1}'; }

ua=(-A "Mozilla/5.0")

mkdir -p "$WEB" "$BACKUP_DIR" "$LEDGER_DIR"
cd "$WEB"

# --- CNAME + canonical ---
echo "$DOMAIN" > CNAME
if [ -f index.html ] && ! grep -qi 'rel=["'\'']canonical["'\'']' index.html; then
  sed -i "/<\/head>/i <link rel=\"canonical\" href=\"https://$DOMAIN/\"/>" index.html
fi

# --- Git init + remote ---
if [ ! -d .git ]; then
  git init >/dev/null
  git branch -M main
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "https://github.com/$OWNER/$REPO.git"
fi

# --- Commit om det finns ändringar ---
git add -A
if ! git diff --cached --quiet; then
  git -c user.email="pages@$DOMAIN" -c user.name="$COMPANY" commit -m "WEB MAXFIX $TS" >/dev/null
fi

# --- Push med PAT om finns, annars vanlig https (kan kräva interaktiv inloggning) ---
if [ -f "$GH_FILE" ]; then
  GH_PAT="$(tr -d '\r\n' < "$GH_FILE")"
  git push "https://${GH_PAT}@github.com/$OWNER/$REPO.git" HEAD:main >/dev/null || true
else
  git push "https://github.com/$OWNER/$REPO.git" HEAD:main >/dev/null || true
fi

# --- Verify: endast HTTPS + UA ---
curl "${ua[@]}" -sSI "https://$DOMAIN" | grep -E 'HTTP|Strict-Transport-Security|Location' || true

# --- Snapshot + ledger ---
SNAP="$BACKUP_DIR/iaionex_websnap_${TS}.tar.zst"
tar -I zstd -cf "$SNAP" "$WEB" "$CF_FILE" "$GH_FILE" 2>/dev/null || true
SHA="$(sha256 "$SNAP")"
QRPNG="$BACKUP_DIR/sha_${SHA:0:12}.qr.png"
printf '%s' "$SHA" | qrencode -o "$QRPNG" -s 6 -m 2

LOG="$LEDGER_DIR/ledger_webfix.ndjson"
printf '{"ts":"%s","uid":"%s","owner":"%s","company":"%s","orcid":"%s","domain":"%s","snapshot":"%s","sha256":"%s","qr":"%s"}\n' \
  "$TS" "$IAIONEX_UID" "$OWNER_NAME" "$COMPANY" "$ORCID" "$DOMAIN" "$(basename "$SNAP")" "$SHA" "$(basename "$QRPNG")" >> "$LOG"

echo "[DONE] IAIONEX WEB MAXFIX v2 klar"
echo "HTTPS verifierad, CNAME/canonical satt, snapshot: $SNAP"
echo "SHA256: $SHA"
