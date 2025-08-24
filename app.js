(function(){
  const box=document.getElementById('assistant-box');
  const brain=document.getElementById('mini-brain');
  const closeBtn=document.getElementById('chat-close');
  const input=document.getElementById('chat-input');
  const body=document.getElementById('chat-body');
  const sendBtn=document.getElementById('chat-send');

  function openBox(){ box.hidden=false; box.setAttribute('aria-hidden','false'); brain.setAttribute('aria-expanded','true'); input&&input.focus(); }
  function closeBox(){ box.hidden=true; box.setAttribute('aria-hidden','true'); brain.setAttribute('aria-expanded','false'); }

  // start stängd
  closeBox();

  // toggla
  brain&&brain.addEventListener('click', (e)=>{ e.preventDefault(); e.stopPropagation(); box.hidden?openBox():closeBox(); });
  // stäng via ×
  closeBtn&&closeBtn.addEventListener('click', (e)=>{ e.preventDefault(); e.stopPropagation(); closeBox(); });
  // stäng via ESC
  document.addEventListener('keydown', (e)=>{ if(e.key==='Escape') closeBox(); });
  // stäng klick utanför
  document.addEventListener('click', (e)=>{ if(!box.hidden && !box.contains(e.target) && e.target!==brain && !brain.contains(e.target)) closeBox(); });

  // enkel offline-svar
  function reply(q){
    q=(q||'').toLowerCase();
    if(/offline|air.?gap/.test(q)) return "IAIONEX runs 100% offline — no cloud, no telemetry.";
    if(/determin/.test(q)) return "Deterministic: same input → same output. Auditable & reproducible.";
    if(/uid|identity|dna/.test(q)) return "All artifacts are UID‑locked to IAIONEX.70ID and DNA‑linked. SHA‑256 + optional QR.";
    if(/whitepaper|research/.test(q)) return "Whitepaper summary is on the site. Full paper: johan@iaionex.com";
    if(/owner|author|who/.test(q)) return "Created from scratch by Johan Gärtner • IAIONEX.AB • ORCID 0009‑0001‑9029‑1379.";
    return "Ask about offline, determinism, UID, ledger or research.";
  }
  function addLine(txt, who){
    const p=document.createElement('div');
    p.className = who==='me' ? 'iax-msg me' : 'iax-msg ai';
    p.style.margin='6px 0'; p.textContent = (who==='me'?'You: ':'IAIONEX: ') + txt;
    body.appendChild(p); body.scrollTop = body.scrollHeight;
  }
  sendBtn&&sendBtn.addEventListener('click', ()=>{
    const v=(input.value||'').trim(); if(!v) return;
    addLine(v, 'me'); addLine(reply(v), 'ai'); input.value='';
  });
})();
