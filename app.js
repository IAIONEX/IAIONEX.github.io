(function(){
  function esc(s){return String(s).replace(/[&<>"]/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[m]))}
  function ans(q){
    q=(q||"").toLowerCase();
    if(/uid|identity|äg/.test(q)) return "All artifacts are UID‑locked to IAIONEX.70ID with SHA‑256 and optional QR.";
    if(/offline|air.?gap|internet/.test(q)) return "Runs fully offline on Termux/ARM64, Linux, and Windows — no cloud, no telemetry.";
    if(/determin/.test(q)) return "Deterministic: same input → same output. Reproducible and auditable.";
    if(/whitepaper|research|paper/.test(q)) return "Request full whitepaper: johan@iaionex.com";
    if(/owner|author|skapare/.test(q)) return "Created by Johan Gärtner • IAIONEX.AB • ORCID 0009‑0001‑9029‑1379.";
    return "Ask about offline, determinism, UID, ledger, or research.";
  }
  function ready(fn){document.readyState==="loading"?document.addEventListener("DOMContentLoaded",fn):fn()}
  ready(function(){
    const bubble=document.getElementById("iax-bubble");
    const panel=document.getElementById("iax-panel");
    const close=document.getElementById("iax-close");
    const log=document.getElementById("iax-log");
    const form=document.getElementById("iax-form");
    const input=document.getElementById("iax-q");
    if(!bubble||!panel||!close||!form||!input) return;

    function open(){
      if(!panel.hidden) return;
      panel.hidden=false;
      requestAnimationFrame(()=>panel.classList.add("open"));
      if(!sessionStorage.getItem("iax_welc")){ add("Hi — IAIONEX runs fully offline and deterministically. Ask about the system.","bot"); sessionStorage.setItem("iax_welc","1"); }
      input.focus();
    }
    function closePanel(){
      if(panel.hidden) return;
      panel.classList.remove("open");
      panel.addEventListener("transitionend", function h(){ panel.hidden=true; panel.removeEventListener("transitionend",h); }, {once:true});
    }
    function toggle(){ panel.hidden ? open() : closePanel(); }

    function add(msg,who){ const d=document.createElement("div"); d.className="iax-msg "+(who||"bot"); d.innerHTML=msg; log.appendChild(d); log.scrollTop=log.scrollHeight; }

    bubble.addEventListener("click", e=>{ e.preventDefault(); e.stopPropagation(); toggle(); });
    close.addEventListener("click", e=>{ e.preventDefault(); e.stopPropagation(); closePanel(); });
    document.addEventListener("keydown", e=>{ if(e.key==="Escape") closePanel(); });
    document.addEventListener("click", e=>{ if(!panel.hidden && !panel.contains(e.target) && !bubble.contains(e.target)) closePanel(); });
    form.addEventListener("submit", e=>{
      e.preventDefault();
      const q=(input.value||"").trim(); if(!q) return;
      add(esc(q),"user"); add(ans(q),"bot"); input.value="";
    });

    // start closed
    panel.hidden=true; panel.classList.remove("open");
  });
})();
