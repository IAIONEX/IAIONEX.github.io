#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; umask 0022; export LC_ALL=C

# ==== IDENTITET ====
IAIONEX_UID="IAIONEX.70ID"
OWNER="JOHAN GÄRTNER"
COMPANY="IAIONEX.AB"
ORCID="0009-0001-9029-1379"
DOMAIN="iaionex.com"
DNA="${IAIONEX_DNA:-UNSPECIFIED}"

# ==== PATHS ====
BASE="$HOME/IAIONEX.WEB"
GDIR="$BASE/.guard"
RUN="$GDIR/run"
LOG="$GDIR/log"
LED="$GDIR/ledger"
SHA="$GDIR/sha"
SNAP="$GDIR/snap"
PID="$RUN/iaionex_guard.pid"
LEG="$GDIR/LEGAL.txt"
MAN_CUR="$GDIR/manifest_current.sha256"
MAN_BASE="$GDIR/manifest_baseline.sha256"
REPORT="$RUN/last_report.txt"

mkdir -p "$RUN" "$LOG" "$LED" "$SHA" "$SNAP"

need(){ for b in "$@"; do command -v "$b" >/dev/null 2>&1 || pkg install -y "$b" >/dev/null; done; }
need coreutils awk sed grep find tar zstd qrencode date

# ==== LEGAL ====
cat > "$LEG" <<EOF
IAIONEX.AB • GUARD POLICY
UID: $IAIONEX_UID • Owner: $OWNER • ORCID: $ORCID • Domain: $DOMAIN • DNA: $DNA
Denna vakt övervakar filintegritet i ~/IAIONEX.WEB, signerar loggar med SHA256,
kedjar ledger-poster med prev/chain-hash, roterar loggar, och skapar snapshots.
Ingen nätverksåtkomst. Allt är lokalt och deterministiskt. © IAIONEX.AB.
EOF

# ==== UTIL ====
ts(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
tsc(){ date -u +%Y%m%dT%H%M%SZ; }
sha1(){ sha256sum "$1" | awk '{print $1}'; }
qr_sig(){ local s="$1"; local q="$2"; printf "%s" "$s" > "$q"; qrencode -o "${q}.qr.png" < "$q"; }
rotate(){ # $1=logpath, max 524288 bytes
  local p="$1"; local max=524288
  [ -f "$p" ] || return 0
  local sz; sz=$(wc -c <"$p")
  if [ "$sz" -ge "$max" ]; then
    mv -f "$p" "${p}.$(tsc)"; : > "$p"
  fi
}

chain_head(){ local f="$LED/guard.ndjson"; [ -s "$f" ] && sha1 "$f" || printf "GENESIS"; }

append_ledger(){ # $1=event $2=status $3=detail_file(optional)
  local ev="$1" st="$2" df="${3:-}"
  local head prev chain jdetail
  head="$(chain_head)"; prev="$head"
  chain="$(printf "%s|%s|%s|%s" "$prev" "$(ts)" "$ev" "$st" | sha256sum | awk '{print $1}')"
  if [ -n "$df" ] && [ -f "$df" ]; then
    local dsha; dsha="$(sha1 "$df")"
    jdetail="$(printf '%s' "$df|$dsha" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  else
    jdetail=""
  fi
  printf '{"ts":"%s","ev":"%s","status":"%s","uid":"%s","owner":"%s","orcid":"%s","company":"%s","domain":"%s","dna":"%s","detail":"%s","prev":"%s","chain":"%s"}\n' \
    "$(ts)" "$ev" "$st" "$IAIONEX_UID" "$OWNER" "$ORCID" "$COMPANY" "$DOMAIN" "$DNA" \
    "$jdetail" "$prev" "$chain" >> "$LED/guard.ndjson"
  # signera ledger head
  local headsha; headsha="$(sha1 "$LED/guard.ndjson")"
  printf "%s" "$headsha" > "$SHA/ledger_head.sha256"
  qrencode -o "$SHA/ledger_head.sha256.qr.png" < "$SHA/ledger_head.sha256"
}

manifest_build(){ # skriv MAN_CUR
  : > "$MAN_CUR"
  # Watchlista: html/css/js + meta + shell
  local list=(
    "$BASE/index.html" "$BASE/styles.css" "$BASE/app.js"
    "$BASE/CNAME" "$BASE/robots.txt" "$BASE/sitemap.xml" "$BASE/404.html" "$BASE/.nojekyll"
  )
  # Lägg även till alla .sh i IAIONEX.WEB
  while IFS= read -r f; do list+=("$f"); done < <(find "$BASE" -maxdepth 1 -type f -name "*.sh" | sort)
  for f in "${list[@]}"; do
    [ -f "$f" ] || continue
    sha256sum "$f" >> "$MAN_CUR"
  done
  sort -k2 "$MAN_CUR" -o "$MAN_CUR"
}

manifest_diff(){ # skriv rapport till REPORT, return 0 om identisk
  if [ ! -s "$MAN_BASE" ]; then
    printf "[BASE] saknas, första seal krävs.\n" > "$REPORT"
    return 1
  fi
  diff -u "$MAN_BASE" "$MAN_CUR" > "$REPORT" || return 1
  return 0
}

snapshot_make(){ # heltäckande snapshot av watchlista
  local tag; tag="$(tsc)"
  local tarf="$SNAP/iaionex_web_${tag}.tar"
  local out="$SNAP/iaionex_web_${tag}.tar.zst"
  tar -C "$BASE" -cf "$tarf" \
    index.html styles.css app.js CNAME robots.txt sitemap.xml 404.html .nojekyll 2>/dev/null || true
  # inkludera alla sh
  while IFS= read -r f; do tar -rf "$tarf" -C "$BASE" "$(basename "$f")"; done < <(find "$BASE" -maxdepth 1 -type f -name "*.sh")
  zstd -q --rm -19 "$tarf" -o "$out"
  local s; s="$(sha1 "$out")"
  printf "%s  %s\n" "$s" "$(basename "$out")" > "$SNAP/${tag}.sha256"
  qrencode -o "$SNAP/${tag}.sha256.qr.png" < "$SNAP/${tag}.sha256"
  echo "$out"
}

seal_baseline(){ # uppdatera baseline efter verifierad ändring
  cp -f "$MAN_CUR" "$MAN_BASE"
  local h; h="$(sha1 "$MAN_BASE")"
  printf "%s" "$h" > "$SHA/manifest_baseline.sha256"
  qrencode -o "$SHA/manifest_baseline.sha256.qr.png" < "$SHA/manifest_baseline.sha256"
  append_ledger "seal" "ok" "$MAN_BASE"
}

guard_loop(){
  local logf="$LOG/guard_$(tsc).log"
  append_ledger "start" "ok"
  echo "[GUARD] start $(ts)" >> "$logf"
  while :; do
    rotate "$logf"
    manifest_build
    if manifest_diff; then
      echo "[OK] manifest identisk $(ts)" >> "$logf"
      # signera nuvarande manifest
      local msha; msha="$(sha1 "$MAN_CUR")"; qr_sig "$msha" "$SHA/manifest_current.sha256"
    else
      echo "[ALERT] manifest ändrad $(ts)" >> "$logf"
      cat "$REPORT" >> "$logf" || true
      local snap; snap="$(snapshot_make)"; echo "[SNAP] $snap" >> "$logf"
      append_ledger "change" "alert" "$REPORT"
    fi
    sleep 15
  done
}

start(){
  if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
    echo "[GUARD] redan igång PID $(cat "$PID")"; exit 0
  fi
  nohup "$0" run >/dev/null 2>&1 &
  echo $! > "$PID"
  disown || true
  echo "[GUARD] startad PID $(cat "$PID")"
}

stop(){
  if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
    kill "$(cat "$PID")" 2>/dev/null || true
    rm -f "$PID"
    append_ledger "stop" "ok"
    echo "[GUARD] stoppad"
  else
    echo "[GUARD] ej igång"
  fi
}

status(){
  if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
    echo "[GUARD] igång PID $(cat "$PID")"
  else
    echo "[GUARD] stoppad"
  fi
  echo "Ledger: $LED/guard.ndjson"
  echo "Legal : $LEG"
}

run(){
  trap 'append_ledger "term" "ok"; exit 0' TERM INT
  guard_loop
}

inspect(){
  manifest_build
  if [ -s "$MAN_BASE" ]; then
    diff -u "$MAN_BASE" "$MAN_CUR" || true
  else
    echo "[BASE] saknas. Kör: $0 seal"
  fi
}

seal(){
  manifest_build
  seal_baseline
  echo "[SEAL] baseline uppdaterad"
}

rollback(){ # återställ senast snapshot till BASE
  local last; last="$(ls -1 "$SNAP"/iaionex_web_*.tar.zst 2>/dev/null | tail -n1 || true)"
  [ -n "$last" ] || { echo "[ROLLBACK] ingen snapshot"; exit 1; }
  zstd -dq -c "$last" | tar -C "$BASE" -xvf - >/dev/null 2>&1
  append_ledger "rollback" "ok" "$last"
  echo "[ROLLBACK] återställd från $(basename "$last")"
}

usage(){
  cat <<U
Usage: $(basename "$0") [start|stop|status|run|inspect|seal|rollback|legal]
U
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  run) run ;;
  inspect) inspect ;;
  seal) seal ;;
  rollback) rollback ;;
  legal) cat "$LEG" ;;
  *) usage; exit 1 ;;
esac
