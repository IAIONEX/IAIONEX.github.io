(function(){
  const root=document.getElementById("iax-chat-root");
  if(!root || root.dataset.ready) return;
  const bubble=document.getElementById("iax-bubble");
  const panel=document.getElementById("iax-panel");
  const closeBtn=document.getElementById("iax-close");
  const log=document.getElementById("iax-log");
  const form=document.getElementById("iax-form");
  const input=document.getElementById("iax-q");

  function esc(s){return String(s).replace(/[&<>"]/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[m]))}
  function add(who,html){
    const row=document.createElement("div"); row.className="iax-msg "+(who==="me"?"me":"ai");
    const b=document.createElement("div"); b.className="iax-bubble-msg"; b.innerHTML=html;
    row.appendChild(b); log.appendChild(row); log.scrollTop=log.scrollHeight;
  }
  function answer(q){
    q=(q||"").toLowerCase();
    if(/offline|air.?gap|no\s*internet|ingen\s*internet/.test(q)) return "IAIONEX runs fully offline on Termux/ARM64, Linux and Windows. No cloud, no telemetry.";
    if(/determin/.test(q)) return "Deterministic execution: same input → same output. Reproducible and auditable.";
    if(/uid|identity|äg|owner|dna/.test(q)) return "All artifacts are UID‑locked to IAIONEX.70ID with SHA‑256 and optional QR; authorship is DNA‑linked.";
    if(/security|säkerhet|policy|guard|integrity/.test(q)) return "Local policy gates, ASCII‑only processing, no network calls, append‑only ledgers.";
    if(/whitepaper|research|paper|forsk/.test(q)) return "Public summary on site. Request full whitepaper: <a href=\"mailto:johan@iaionex.com\">johan@iaionex.com</a>";
    if(/who|about|owner|author|skapare/.test(q)) return "Created and owned by <b>Johan Gärtner</b> (IAIONEX.AB). UID: IAIONEX.70ID • ORCID: 0009‑0001‑9029‑1379.";
    return "Ask about offline, determinism, UID‑lock, ledger, or research.";
  }

  function open(){ panel.hidden=false; input && input.focus(); if(!root.dataset.welc){ add("ai","Hi — local IAIONEX assistant ready."); root.dataset.welc="1"; } }
  function close(){ panel.hidden=true; }
  function toggle(){ panel.hidden ? open() : close(); }

  bubble && bubble.addEventListener("click", e=>{ e.preventDefault(); e.stopPropagation(); toggle(); });
  closeBtn && closeBtn.addEventListener("click", e=>{ e.preventDefault(); e.stopPropagation(); close(); });
  document.addEventListener("keydown", e=>{ if(e.key==="Escape") close(); });
  document.addEventListener("click", e=>{ if(!panel.hidden && !panel.contains(e.target) && e.target!==bubble) close(); });

  form && form.addEventListener("submit", e=>{
    e.preventDefault();
    const q=(input.value||"").trim(); if(!q) return;
    add("me", esc(q)); add("ai", answer(q)); input.value="";
  });

  root.dataset.ready="1";
})();
