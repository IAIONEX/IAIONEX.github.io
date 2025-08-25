#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail; umask 0022; export LC_ALL=C
WEB="$HOME/IAIONEX.WEB"; cd "$WEB"
HTML="index.html"; CSS="styles.css"; JS="app.js"

# --- index.html (rent) ---
cat > "$HTML" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>IAIONEX</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <header class="top-header">
    <img class="logo-top" src="assets/brain_logo.png" alt="IAIONEX">
  </header>

  <main>
    <section class="hero" id="top">
      <h1>Sovereign Offline AI</h1>
      <p>100% Offline • UID-Locked • Deterministic — By Johan Gärtner</p>
      <nav class="pill-nav">
        <a href="#about">About</a>
        <a href="#tech">Technology</a>
        <a href="#research">Research</a>
        <a href="#contact">Contact</a>
        <a href="https://github.com/IAIONEX" rel="noopener">GitHub</a>
      </nav>
    </section>

    <section id="about"><h2>About</h2></section>
    <section id="tech"><h2>Technology</h2></section>
    <section id="research"><h2>Research</h2></section>
    <section id="contact"><h2>Contact</h2></section>
  </main>

  <!-- Mini-hjärna + panel, stängd som standard -->
  <div id="iax-chat-root" class="iax-root" aria-live="polite">
    <button id="iax-bubble" class="iax-bubble iax-mini" aria-label="Open IAIONEX chat"></button>
    <div id="iax-panel" class="iax-panel" hidden>
      <div class="iax-head">
        <div class="iax-title">IAIONEX — Local Assistant</div>
        <button id="iax-close" class="iax-close" aria-label="Close">×</button>
      </div>
      <div id="iax-log" class="iax-log"></div>
      <form id="iax-form" class="iax-form">
        <input id="iax-q" class="iax-input" type="text" autocomplete="off"
               placeholder="Ask about offline, determinism, UID, ledger, research…">
        <button class="iax-send" type="submit">Send</button>
      </form>
    </div>
  </div>

  <script src="app.js"></script>
</body>
</html>
HTML

# --- styles.css (ren) ---
cat > "$CSS" <<'CSS'
:root { --bg:#000; --text:#e8eef6; --line:#2a2a2a; --pill:#171717; --accent:#cfd6df; }
*{box-sizing:border-box} html,body{height:100%}
body{margin:0; font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif; background:var(--bg); color:var(--text);}

.top-header{padding:16px 0}
.logo-top{display:block; margin:0 auto; width:min(160px,40vw); height:auto}

.hero{position:relative; min-height:92vh; display:grid; place-items:center; gap:14px; padding:56px 16px; text-align:center}
.hero::before{
  content:""; position:absolute; inset:0; z-index:0; opacity:.9;
  background:#000 url("assets/hero.jpg") center/contain no-repeat;
}
.hero>*{position:relative; z-index:1}
.hero h1{font-size:clamp(28px,6.6vw,44px); margin:0}
.hero p{opacity:.92; margin:0 0 10px}
.pill-nav{display:flex; flex-wrap:wrap; gap:12px; justify-content:center}
.pill-nav a{display:inline-block; padding:10px 16px; border-radius:999px; background:var(--pill); color:var(--text); text-decoration:none; border:1px solid var(--line)}

section{padding:24px 16px}

/* Chat bubble + panel */
.iax-root{position:fixed; right:16px; bottom:20px; z-index:9999}
.iax-bubble.iax-mini{
  width:64px; height:64px; border-radius:50%;
  background:url("assets/brain_logo.png") center/contain no-repeat transparent;
  border:0; box-shadow:0 10px 28px rgba(0,0,0,.45); cursor:pointer;
}
.iax-bubble.iax-mini:active{transform:scale(.98)}

.iax-panel{
  position:fixed; right:16px; bottom:96px; width:min(92vw,380px); max-height:min(70vh,620px);
  background:rgba(16,22,30,.92); border:1px solid rgba(255,255,255,.12);
  border-radius:14px; box-shadow:0 12px 36px rgba(0,0,0,.5);
}
[hidden].iax-panel{display:none}
.iax-head{display:flex;justify-content:space-between;align-items:center;padding:10px 12px;border-bottom:1px solid rgba(255,255,255,.1)}
.iax-close{background:transparent;border:0;color:var(--text);font-size:20px;cursor:pointer}
.iax-log{padding:10px 12px;max-height:48vh;overflow:auto}
.iax-msg{margin:6px 0;padding:8px 10px;border-radius:12px;max-width:92%}
.iax-msg.user{background:rgba(255,255,255,.10);align-self:flex-end}
.iax-msg.bot{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.10)}
.iax-form{display:flex;gap:8px;padding:10px 12px;border-top:1px solid rgba(255,255,255,.1)}
.iax-input{flex:1;padding:10px;border-radius:10px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:var(--text)}
.iax-send{padding:10px 14px;border-radius:10px;border:1px solid transparent;background:var(--accent);color:#0b1520;font-weight:600;cursor:pointer}
CSS

# --- app.js (ren) ---
cat > "$JS" <<'JS'
(function(){
  if(window.__IAIONEX_CHAT_READY__) return; window.__IAIONEX_CHAT_READY__=true;

  function esc(s){return String(s).replace(/[&<>"]/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[m]))}
  function ans(q){
    q=(q||"").toLowerCase();
    if(/uid|identity/.test(q)) return "Artifacts are UID-locked to IAIONEX.70ID with SHA-256 + QR.";
    if(/offline|air.?gap|internet/.test(q)) return "Runs fully offline — Termux/ARM64, Linux, Windows.";
    if(/determin/.test(q)) return "Deterministic: same input → same output. Auditable.";
    if(/whitepaper|research/.test(q)) return "Request full whitepaper: johan@iaionex.com";
    if(/owner|author|skapare/.test(q)) return "Created by Johan Gärtner • IAIONEX.AB • ORCID 0009-0001-9029-1379.";
    return "Ask about offline, determinism, UID, ledger, or research.";
  }

  function init(){
    const bubble=document.getElementById("iax-bubble");
    const panel=document.getElementById("iax-panel");
    const close=document.getElementById("iax-close");
    const log=document.getElementById("iax-log");
    const form=document.getElementById("iax-form");
    const input=document.getElementById("iax-q");

    function open(){ panel.hidden=false; input && input.focus(); }
    function closePanel(){ panel.hidden=true; }
    function toggle(){ panel.hidden ? open() : closePanel(); }
    function add(m,w){ const d=document.createElement("div"); d.className="iax-msg "+(w||"bot"); d.innerHTML=m; log.appendChild(d); log.scrollTop=log.scrollHeight; }

    bubble.addEventListener("click", e=>{ e.preventDefault(); toggle(); });
    close.addEventListener("click", e=>{ e.preventDefault(); closePanel(); });
    document.addEventListener("keydown", e=>{ if(e.key==="Escape") closePanel(); });
    document.addEventListener("click", e=>{ if(!panel.hidden && !panel.contains(e.target) && e.target!==bubble) closePanel(); });
    form.addEventListener("submit", e=>{ e.preventDefault(); const q=(input.value||"").trim(); if(!q) return; add(esc(q),"user"); add(ans(q),"bot"); input.value=""; });
  }

  document.readyState==="loading" ? document.addEventListener("DOMContentLoaded",init) : init();
})();
JS

# --- Git add/commit/push ---
git add "$HTML" "$CSS" "$JS" || true
if ! git diff --cached --quiet; then
  git commit -m "WEB TOTAL: top logo, hero brain image, single mini-brain chat closed-by-default"
  if [ -s "$HOME/.gh_token" ]; then
    GH="$(tr -d '\r\n' < "$HOME/.gh_token")"
    git push "https://${GH}@github.com/IAIONEX/IAIONEX.github.io.git" HEAD:main
  else
    git push
  fi
else
  echo "[INFO] Inget att committa."
fi

# --- Valfri Cloudflare purge, read-only tokens ---
CF="$HOME/.cf_token"
if [ -f "$CF" ]; then
  CF_API_TOKEN=""; CF_ZONE_ID=""
  if grep -q 'CF_API_TOKEN=' "$CF"; then . "$CF"; else
    CF_API_TOKEN="$(head -n1 "$CF" | tr -d '[:space:]' || true)"
    CF_ZONE_ID="$(sed -n '2p' "$CF" | tr -d '[:space:]' || true)"
  fi
  if [ -n "${CF_API_TOKEN:-}" ] && [ -n "${CF_ZONE_ID:-}" ]; then
    curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/purge_cache" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" \
      --data '{"purge_everything":true}' >/dev/null && echo "[CF] Cache purged."
  fi
fi

# --- Snabb kontroll att loggor finns ---
[ -f assets/brain_logo.png ] || echo "[WARN] assets/brain_logo.png saknas."
[ -f assets/hero.jpg ] || echo "[INFO] Tips: lägg din stora hero-bild som assets/hero.jpg för maximal kvalitet."

echo "[DONE] IAIONEX web uppdaterad."
