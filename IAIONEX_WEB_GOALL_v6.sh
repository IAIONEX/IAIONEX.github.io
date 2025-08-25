#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; umask 0022; export LC_ALL=C

DOMAIN="iaionex.com"
OWNER="IAIONEX"
REPO="IAIONEX.github.io"
COMPANY="IAIONEX.AB"
OWNER_NAME="JOHAN GÄRTNER"
IAIONEX_UID="IAIONEX.70ID"
ORCID="0009-0001-9029-1379"

WEB="$HOME/IAIONEX.WEB"
BACKUP_DIR="$WEB/.snap"
LEDGER_DIR="$HOME/IAIONEX.AB/ledger"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ua=(-A "Mozilla/5.0")

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need coreutils git curl grep sed tar zstd qrencode gawk

sha256(){ sha256sum "$1" | awk '{print $1}'; }

mkdir -p "$WEB" "$BACKUP_DIR" "$LEDGER_DIR"
cd "$WEB"

# .gitignore
cat > .gitignore <<'G'
.snap/
*.tar.zst
*.qr.png
*.sha256
.gh_token
.cf_token
.guard/
CF_PURGE.sh
IAX_REPAIR_HTTPS.sh
URL_PURGE*.sh
G

# pre-commit hook
mkdir -p .git/hooks
cat > .git/hooks/pre-commit <<'H'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
if git diff --cached --name-only | grep -E '\.tar\.zst$|\.qr\.png$|\.gh_token$|\.cf_token$' >/dev/null; then
  echo "[BLOCK] Förbjudna filer i staging:"
  git diff --cached --name-only | grep -E '\.tar\.zst$|\.qr\.png$|\.gh_token$|\.cf_token$' || true
  exit 2
fi
H
chmod +x .git/hooks/pre-commit

# rensa förbjudna filer ur index
git ls-files -z | tr '\0' '\n' | grep -E '\.tar\.zst$|\.qr\.png$|\.gh_token$|\.cf_token$' | xargs -r git rm -f --cached >/dev/null

# bootstrap index
if [ ! -f index.html ]; then
cat > index.html <<'HTML'
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>IAIONEX</title>
</head><body>
<h1>IAIONEX — Sovereign Offline AI</h1>
<p>UID: IAIONEX.70ID • Owner: JOHAN GÄRTNER • Company: IAIONEX.AB</p>
</body></html>
HTML
fi

# CNAME + canonical
echo "$DOMAIN" > CNAME
if ! grep -qi 'rel=["'\'']canonical["'\'']' index.html; then
  sed -i "/<\/head>/i <link rel=\"canonical\" href=\"https://$DOMAIN/\"/>" index.html
fi

# git init/remote
[ -d .git ] || { git init >/dev/null; git branch -M main; }
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$OWNER/$REPO.git"

# commit
git add -A
if git diff --cached --name-only | grep -E '\.tar\.zst$|\.qr\.png$|\.gh_token$|\.cf_token$' >/dev/null; then
  echo "[BLOCK] Förbjudna filer i staging. Avbryter."
  exit 2
fi
if ! git diff --cached --quiet; then
  git -c user.email="pages@$DOMAIN" -c user.name="$COMPANY" commit -m "GOALL v6 $TS" >/dev/null
fi

# push med auto-upstream
if [ -f "$HOME/.gh_token" ]; then
  GH_PAT="$(tr -d '\r\n' < "$HOME/.gh_token")"
  if ! git push "https://${GH_PAT}@github.com/$OWNER/$REPO.git" HEAD:main 2>/dev/null; then
    git push --set-upstream "https://${GH_PAT}@github.com/$OWNER/$REPO.git" main
  fi
else
  if ! git push "https://github.com/$OWNER/$REPO.git" HEAD:main 2>/dev/null; then
    git push --set-upstream "https://github.com/$OWNER/$REPO.git" main
  fi
fi

# verify
curl "${ua[@]}" -sSI "https://$DOMAIN" | grep -E 'HTTP|Strict-Transport-Security|Location' || true

# snapshot
SNAP="$BACKUP_DIR/iaionex_goall_${TS}.tar.zst"
tar -I zstd -cf "$SNAP" \
  --exclude-vcs \
  --exclude='.snap' \
  --exclude='*.tar.zst' \
  --exclude='*.qr.png' \
  --exclude='*.sha256' \
  --exclude='.gh_token' \
  --exclude='.cf_token' \
  "$WEB"

SHA="$(sha256 "$SNAP")"
printf '%s\n' "$SHA  $(basename "$SNAP")" > "$BACKUP_DIR/$(basename "$SNAP").sha256"
QRPNG="$BACKUP_DIR/sha_${SHA:0:12}.qr.png"
printf '%s' "$SHA" | qrencode -o "$QRPNG" -s 6 -m 2

# ledger
LOG="$LEDGER_DIR/ledger_webgoall.ndjson"
printf '{"ts":"%s","uid":"%s","owner":"%s","company":"%s","orcid":"%s","domain":"%s","snapshot":"%s","sha256":"%s","qr":"%s"}\n' \
  "$TS" "$IAIONEX_UID" "$OWNER_NAME" "$COMPANY" "$ORCID" "$DOMAIN" "$(basename "$SNAP")" "$SHA" "$(basename "$QRPNG")" >> "$LOG"

echo "[DONE] IAIONEX WEB GOALL v6 klar"
echo "Snapshot: $SNAP"
echo "SHA256: $SHA"
