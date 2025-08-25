(function(){
  if (window.__IAIONEX_CHAT_READY__) return; window.__IAIONEX_CHAT_READY__=true;

  function esc(s){return String(s).replace(/[&<>"]/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[m]))}
  function ans(q){
    q=(q||"").toLowerCase();
    if(/uid|identity|äg/.test(q)) return "All artifacts are UID-locked to IAIONEX.70ID with SHA-256 and QR.";
    if(/offline|air.?gap|internet/.test(q)) return "Runs fully offline on Termux/ARM64, Linux, Windows — no cloud.";
    if(/determin/.test(q)) return "Deterministic: same input → same output. Reproducible & auditable.";
    if(/whitepaper|research|paper/.test(q)) return "Request full whitepaper: johan@iaionex.com";
    if(/owner|author|skapare/.test(q)) return "Created by Johan Gärtner • IAIONEX.AB • ORCID 0009-0001-9029-1379.";
    return "Ask about offline, determinism, UID, ledger, or research.";
  }

  function init(){
    const root=document.getElementById("iax-chat-root"); if(!root||root.dataset.ready) return;
    const bubble=document.getElementById("iax-bubble");
    const panel=document.getElementById("iax-panel");
    const close=document.getElementById("iax-close");
    const log=document.getElementById("iax-log");
    const form=document.getElementById("iax-form");
    const input=document.getElementById("iax-q");

    function open(){ panel.hidden=false; input && input.focus();
      if(!root.dataset.welc){ add("Hi — IAIONEX runs fully offline and deterministically.","bot"); root.dataset.welc="1"; } }
    function closePanel(){ panel.hidden=true; }
    function toggle(){ panel.hidden ? open() : closePanel(); }
    function add(m,w){ const d=document.createElement("div"); d.className="iax-msg "+(w||"bot"); d.innerHTML=m; log.appendChild(d); log.scrollTop=log.scrollHeight; }

    bubble.addEventListener("click", e=>{ e.preventDefault(); e.stopPropagation(); toggle(); });
    close.addEventListener("click", e=>{ e.preventDefault(); e.stopPropagation(); closePanel(); });
    document.addEventListener("keydown", e=>{ if(e.key==="Escape") closePanel(); });
    document.addEventListener("click", e=>{ if(!panel.hidden && !panel.contains(e.target) && e.target!==bubble) closePanel(); });
    form.addEventListener("submit", e=>{ e.preventDefault(); const q=(input.value||"").trim(); if(!q) return;
      add(esc(q),"user"); add(ans(q),"bot"); input.value=""; });

    root.dataset.ready="1";
  }
  document.readyState==="loading" ? document.addEventListener("DOMContentLoaded",init) : init();
})();
