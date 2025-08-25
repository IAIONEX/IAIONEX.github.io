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
