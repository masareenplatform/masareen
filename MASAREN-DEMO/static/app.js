var TOKEN=null,ME=null,FP=0,FF='all',FL=false,FD=false,RX={},UPID=null,NOTIFS=[],NOTIF_OPEN=false;

function toggleTheme(){
  var b=document.body,b2=document.getElementById('themeToggle');
  b.classList.toggle('dark');
  var isDark=b.classList.contains('dark');
  b2.querySelector('.icn').textContent=isDark?'\u2600\uFE0F':'\uD83C\uDF19';
  b2.querySelector('.icn').classList.add('flip');
  setTimeout(function(){b2.querySelector('.icn').classList.remove('flip');},400);
  try{localStorage.setItem('masaren-theme',isDark?'dark':'light');}catch(e){}
}

(function(){
  try{
    var t=localStorage.getItem('masaren-theme');
    if(t==='dark'||(!t&&window.matchMedia('(prefers-color-scheme:dark)').matches)){
      document.body.classList.add('dark');
      var t2=document.getElementById('themeToggle');
      if(t2) t2.querySelector('.icn').textContent='\u2600\uFE0F';
    }
  }catch(e){}
  try{
    var tk=localStorage.getItem('masaren-token');
    var mu=localStorage.getItem('masaren-user');
    if(tk&&mu){TOKEN=tk;try{ME=JSON.parse(mu);}catch(ex){}}
  }catch(e){}
})();

(function(){
  var s=document.createElement('style');
  s.textContent='@keyframes cardIn{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}.card{animation:cardIn .35s ease both;animation-delay:calc(var(--i,0)*60ms)}#fi{scroll-behavior:smooth}';
  document.head.appendChild(s);
})();

function togglePW(id){
  var el=document.getElementById(id);
  el.type=el.type==='password'?'text':'password';
}

function toggleMNav(){
  document.getElementById('mnav-overlay').classList.toggle('open');
}

function toast(msg,type,dur){
  type=type||'s';dur=dur||3500;
  var w=document.getElementById('tw');
  var el=document.createElement('div');
  el.className='t2 '+(type==='success'?'s':type==='error'?'e':'i');
  el.innerHTML=(type==='e'?'\u274C':type==='i'?'\u2139\uFE0F':'\u2705')+' <span>'+msg+'</span>';
  w.appendChild(el);
  setTimeout(function(){el.style.opacity='0';setTimeout(function(){el.remove();},300);},dur);
}

function api(method,path,body,cb){
  var opts={method:method,headers:{'Content-Type':'application/json'}};
  if(TOKEN) opts.headers['Authorization']='Bearer '+TOKEN;
  if(body)  opts.body=JSON.stringify(body);
  fetch(path,opts).then(function(r){return r.json().then(function(d){return{ok:r.ok,d:d};});})
  .then(function(res){
    if(!res.ok){cb&&cb(new Error(res.d.detail||JSON.stringify(res.d)),null);}
    else{cb&&cb(null,res.d);}
  }).catch(function(e){cb&&cb(e,null);});
}

function ago(iso){
  var diff=(Date.now()-new Date(iso).getTime())/1000;
  if(diff<60) return 'just now';
  if(diff<3600) return Math.floor(diff/60)+'m ago';
  if(diff<86400) return Math.floor(diff/3600)+'h ago';
  return Math.floor(diff/86400)+'d ago';
}
function avc(name){
  var cols=['#0F2044','#1E4D8C','#163366','#27ae60','#8e44ad','#c0392b','#d35400'];
  var h=0; for(var i=0;i<name.length;i++) h=(h<<5)-h+name.charCodeAt(i);
  return cols[Math.abs(h)%cols.length];
}
function ini(name){return (name||'?').split(' ').map(function(w){return w[0]||'';}).join('').slice(0,2).toUpperCase();}
function tc(tier){return{BRONZE:'#cd7f32',SILVER:'#aaa',GOLD:'#C9A84C',PLATINUM:'#a0b2c6'}[tier]||'#8A9BB5';}

function selectTag(hid,cid,val,btn){
  document.getElementById(hid).value=val;
  document.querySelectorAll('#'+cid+' .tag-btn').forEach(function(b){b.classList.remove('act');});
  if(btn) btn.classList.add('act');
}
function renderTags(cid,hid,items,opts){
  var c=document.getElementById(cid);
  if(!c) return;
  var sel=(document.getElementById(hid)||{}).value||'';
  var mode=(opts&&opts.mode)||'';
  c.innerHTML=items.map(function(item){
    var val=item.value,label=item.label,active=val===sel,cls='tag-btn'+(active?' act':''),parts='';
    if(mode==='avatar'&&val){
      parts+='<span class="tag-avatar" style="background:'+avc(label)+'">'+ini(label)+'</span>';
    }
    if(mode==='color'&&val){
      var col={HIGH:'#e74c3c',MEDIUM:'#f39c12',LOW:'#27ae60'}[val]||'#8A9BB5';
      parts+='<span class="tag-color" style="background:'+col+'"></span>';
    }
    if(item.sub) parts+='<span class="tag-sub">'+item.sub+'</span>';
    parts+='<span class="tag-label">'+label+'</span>';
    return '<button type="button" class="'+cls+'" data-value="'+val+'" onclick="selectTag(\''+hid+'\',\''+cid+'\',\''+val+'\',this)">'+parts+'</button>';
  }).join('');
}

function stab(t){
  document.getElementById('fl').style.display=t==='login'?'block':'none';
  document.getElementById('fr').style.display=t==='reg'?'block':'none';
  document.getElementById('tl').classList.toggle('act',t==='login');
  document.getElementById('tr').classList.toggle('act',t==='reg');
}
function fill(em){document.getElementById('le').value=em;document.getElementById('lp').value='demo1234';}

function btnLoad(id,loading){
  var el=document.getElementById(id);
  if(!el) return;
  el.disabled=loading;
  el.innerHTML=loading?'<span style="display:inline-block;width:16px;height:16px;border:2px solid rgba(0,0,0,.2);border-top-color:currentColor;border-radius:50%;animation:spin .6s linear infinite;margin-right:.3rem;vertical-align:middle"></span> Processing...':el.getAttribute('data-orig')||el.innerHTML;
  if(!el.getAttribute('data-orig')) el.setAttribute('data-orig',el.innerHTML);
}

function doLogin(){
  var btn=document.getElementById('loginBtn');btnLoad('loginBtn',true);
  api('POST','/api/auth/login',{email:document.getElementById('le').value,password:document.getElementById('lp').value},function(err,d){
    btnLoad('loginBtn',false);
    if(err){toast(err.message,'error');return;}
    TOKEN=d.access_token;ME=d;
    try{localStorage.setItem('masaren-token',TOKEN);localStorage.setItem('masaren-user',JSON.stringify(ME));}catch(e){}
    initApp();toast('Welcome back, '+d.full_name+' \uD83D\uDC4B');
  });
}
function doReg(){
  var btn=document.getElementById('regBtn');btnLoad('regBtn',true);
  api('POST','/api/auth/register',{full_name:document.getElementById('rn').value,email:document.getElementById('re').value,
    password:document.getElementById('rp').value,role:document.getElementById('rr').value},function(err,d){
    btnLoad('regBtn',false);
    if(err){toast(err.message,'error');return;}
    TOKEN=d.access_token;ME=d;
    try{localStorage.setItem('masaren-token',TOKEN);localStorage.setItem('masaren-user',JSON.stringify(ME));}catch(e){}
    initApp();toast('Welcome '+d.full_name+' \u2728');
  });
}
function logout(){
  TOKEN=null;ME=null;
  try{localStorage.removeItem('masaren-token');localStorage.removeItem('masaren-user');}catch(e){}
  document.getElementById('app').style.display='none';
  document.getElementById('auth').style.display='flex';
  document.getElementById('mnav-overlay').classList.remove('open');
}

function initApp(){
  document.getElementById('auth').style.display='none';
  document.getElementById('app').style.display='block';
  var av=document.getElementById('av');
  av.textContent=ini(ME.full_name);
  av.style.background='linear-gradient(135deg,'+avc(ME.full_name)+',#C9A84C)';
  document.getElementById('cav').textContent=ini(ME.full_name);
  document.getElementById('cav').style.background='linear-gradient(135deg,'+avc(ME.full_name)+',#C9A84C)';
  api('POST','/api/demo/seed',{},function(){});
  loadSide();loadLB();loadSDG();loadAlgoParams();openNotif();
  pg('feed');
}

function pg(p){
  document.getElementById('feed-page').style.display=p==='feed'?'block':'none';
  document.getElementById('pp').style.display=p==='passport'?'block':'none';
  document.getElementById('docs-page').style.display=p==='docs'?'block':'none';
  document.getElementById('np').style.display=p==='network'?'block':'none';
  document.getElementById('up').style.display=p==='profile'?'block':'none';
  if(p==='passport') loadPP();
  if(p==='feed'){resetFeed();loadFeed();}
  if(p==='network') setTimeout(loadNetwork,150);
  if(p==='profile'){
    document.getElementById('up').innerHTML='<div style="text-align:center;padding:3rem"><div class="sp"></div></div>';
    document.getElementById('up').style.display='block';
    loadUserProfile(UPID||ME.user_id);
  }
  document.getElementById('mnav-overlay').classList.remove('open');
  document.querySelectorAll('.sni').forEach(function(b){b.classList.remove('act');});
}

function resetFeed(){FP=0;FD=false;FL=false;document.getElementById('fi').innerHTML='';
  document.getElementById('lm').style.display='none';document.getElementById('ef').style.display='none';}
function sf(f,el){
  FF=f;
  if(el){document.querySelectorAll('.ft').forEach(function(b){b.classList.remove('act');});el.classList.add('act');}
  resetFeed();loadFeed();
}

function loadFeed(){
  if(FL||FD) return;
  FL=true;
  if(FP===0){
    document.getElementById('fi').innerHTML='<div class="skc"><div class="skr"><div class="sk skci"></div><div style="flex:1"><div class="sk skl" style="width:55%;margin-bottom:.35rem"></div><div class="sk skl" style="width:35%"></div></div></div><div class="sk skl" style="width:80%;margin-bottom:.35rem"></div><div class="sk skl" style="width:60%"></div></div><div class="skc"><div class="skr"><div class="sk skci"></div><div style="flex:1"><div class="sk skl" style="width:50%;margin-bottom:.35rem"></div><div class="sk skl" style="width:30%"></div></div></div><div class="sk skl" style="width:75%;margin-bottom:.35rem"></div><div class="sk skl" style="width:50%"></div></div>';
    setTimeout(function(){
      document.getElementById('fi').innerHTML='';
      fetchFeed();
    },700);
  } else {
    document.getElementById('lm').style.display='block';
    setTimeout(fetchFeed,400);
  }
}

function fetchFeed(){
  api('GET','/api/feed?page='+FP+'&limit=6&filter='+FF,null,function(err,data){
    document.getElementById('lm').style.display='none';
    if(err){toast('Feed error','error');FL=false;return;}
    if(data.items.length===0&&FP===0){
      document.getElementById('fi').innerHTML='<div class="em"><div class="ei">\uD83C\uDF31</div><p>No activity yet. Create a program or submit evidence.</p><br/><button class="btn bg" onclick="om(\'mprog\')">Launch First Program</button></div>';
    } else {
      data.items.forEach(function(item,i){
        document.getElementById('fi').insertAdjacentHTML('beforeend',buildCard(item,i));
      });
    }
    if(!data.has_more){FD=true;if(FP>0) document.getElementById('ef').style.display='block';}
    FP++;FL=false;
  });
}

var obs=new IntersectionObserver(function(entries){if(entries[0].isIntersecting&&TOKEN) loadFeed();},{rootMargin:'200px'});
(function(){var s=document.getElementById('sen');if(s) obs.observe(s);})();
function buildCard(item,idx){
  idx=idx||0;
  var actor=item.actor||{};
  var bg=avc(actor.name||'?');
  var avStyle=actor.avatar?'background-image:url('+actor.avatar+');background-size:cover;background-position:center':'background:'+bg;
  var aid=actor.id||'';
  var av2='<div onclick="openUserProfile(\''+aid+'\')" class="cav2 t'+actor.tier+'" style="'+avStyle+'">'+(actor.avatar?'':ini(actor.name||'?'))+'<div class="tr"></div></div>';
  var tb={'TASK_COMPLETED':'<span class="tb2 tTC">Task</span>','IMPACT_ASSET':'<span class="tb2 tIA">Asset</span>','PROGRAM_LAUNCHED':'<span class="tb2 tPL">Program</span>'}[item.type]||'';
  var sdgs=((item.program_sdgs||item.sdg_goals||[]).map(function(g){return '<span class="sdgp">SDG '+g+'</span>';}).join(''));
  var r=item.reactions||{};
  var rk=item.id;
  var cc=item.comment_count||0;
  var typeClass={'IMPACT_ASSET':'type-asset','TASK_COMPLETED':'type-task','PROGRAM_LAUNCHED':'type-program','PODCAST_EPISODE':'type-podcast','VODCAST_EPISODE':'type-vodcast','LIVE':'type-live'}[item.type]||'';
  var body='';

  if(item.type==='PODCAST_EPISODE'||item.type==='VODCAST_EPISODE'||item.type==='LIVE'){
    var isVod=item.type==='VODCAST_EPISODE';
    var isLive=item.type==='LIVE';
    var lb='';
    if(isLive) lb='<span class="live-badge" style="display:inline-flex;align-items:center;gap:.25rem;padding:.15rem .5rem;background:var(--red);color:#fff;border-radius:20px;font-size:.68rem;font-weight:700;margin-bottom:.4rem">\uD83D\uDD34 LIVE</span>';
    var mt=item.media_type||'';
    var dur=item.duration?'<span style="font-size:.72rem;color:var(--text-secondary);display:flex;align-items:center;gap:.25rem">\u23F1 '+item.duration+'</span>':'';
    var wf=(!isVod&&!isLive)?'<div class="wf"><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span><span></span></div>':'';
    var thumb=(isVod||isLive)?'<div class="vod-thumb" style="border-radius:10px;overflow:hidden;margin:.4rem 0;background:linear-gradient(135deg,var(--navy),var(--navy-mid));display:flex;align-items:center;justify-content:center;padding:1.5rem;font-size:2.5rem;color:var(--gold)">'+(isLive?'\uD83D\uDCF9':'\uD83C\uDFA5')+'</div>':'';
    body=lb+'<div class="cb2"><div class="ct2">'+item.title+'</div>'+(item.description?'<div class="cd">'+item.description+'</div>':'')+wf+thumb+
      '<div style="display:flex;align-items:center;gap:.5rem;flex-wrap:wrap">'+dur+
      '<button class="btn bg bsm" style="font-size:.75rem" onclick="toast(\''+(isLive?'Joining live stream... (demo)':'Playing... (demo)')+'\',\'i\')">'+(isLive?'\u25B6 Join':isVod?'\u25B6 Watch':'🔊 Listen')+'</button></div></div>'+
      '<div class="cst"><div class="csi"><div class="v">'+(isLive?'LIVE':isVod?'VOD':'POD')+'</div><div class="l">Format</div></div>'+
      '<div class="csi"><div class="v">\u2713</div><div class="l">Verified</div></div>'+
      '<div class="csi"><div class="v">'+(item.duration||'--')+'</div><div class="l">Duration</div></div></div>';
  } else if(item.type==='IMPACT_ASSET'){
    var conf=item.ai_confidence||0;
    var aib='<span class="aib'+(conf<0.8?' w':'')+'">'+(conf<0.8?'Under Review':'AI Verified')+' '+(conf*100).toFixed(1)+'%</span>';
    var mi={PHOTO:'\uD83D\uDCF8',VIDEO:'\uD83C\uDFA5',AUDIO:'\uD83C\uDF99\uFE0F',DOCUMENT:'\uD83D\uDCC4'}[item.media_type]||'\uD83D\uDCCE';
    var imgUrl=item.evidence_image_url||'';
    var mediaContent='';
    if(item.media_type==='VIDEO'){
      mediaContent=imgUrl?'<div class="ev-media" onclick="openLightbox(\''+imgUrl+'\',\'video\')"><img src="'+imgUrl+'" alt="Field recording" loading="lazy"/><div class="play-overlay">\u25B6</div></div>':'<div class="vid-container"><div class="vid-placeholder"><span class="vid-play">\u25B6</span><div class="vid-label">Field Recording</div></div></div>';
    }
    if(item.media_type==='PHOTO'||item.media_type==='IMAGE'){
      mediaContent=imgUrl?'<div class="ev-media" onclick="openLightbox(\''+imgUrl+'\',\'image\')"><img src="'+imgUrl+'" alt="Field photo" loading="lazy"/></div>':'<div class="img-container"><div class="img-placeholder"><span class="img-icon">\uD83D\uDCF8</span><div class="img-label">Field Photo</div></div></div>';
    }
    body='<div class="cb2"><div class="ct2"><span style="cursor:pointer" onclick="loadTaskDetail(\''+(item.task_id||item.id)+'\')">'+(item.task_title||'Field Evidence Verified')+'</span></div>'+(item.description?'<div class="cd">'+item.description+'</div>':'')+
      mediaContent+
      '<div class="ep"><div class="ei2">'+mi+'</div><div class="ev2"><div class="el">Impact Value</div><div class="ev">$'+(item.value_usd||0).toFixed(2)+'</div><div class="es">'+(item.impact_magnitude||'MEDIUM')+' Impact \u00B7 '+item.media_type+'</div></div>'+
      '<div style="text-align:right">'+aib+(item.latitude?'<br/><span class="gc" style="margin-top:.3rem">\uD83D\uDCCD '+(item.latitude.toFixed(4))+', '+(item.longitude.toFixed(4))+'</span>':'')+'</div></div>'+
      '<div class="htimeline"><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">Captured</div></div><div class="ht-line done"></div><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">Uploaded</div></div><div class="ht-line done"></div><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">AI Verified</div></div><div class="ht-line done"></div><div class="ht-step"><div class="ht-dot '+(conf>=0.8?'done':'curr')+'"></div><div class="ht-label">Asset Created</div></div><div class="ht-line"></div><div class="ht-step"><div class="ht-dot"></div><div class="ht-label">PMS Updated</div></div></div>'+
'<div class="hbar"><div class="hfill hfill-gold" style="width:'+(conf*100)+'%"></div></div>'+
      (sdgs?'<div class="sdgr">'+sdgs+'</div>':'')+(item.program?'<div style="font-size:.73rem;color:var(--slate);cursor:pointer" onclick="loadProgramDetail(\''+item.program_id+'\')">\uD83C\uDFDB '+item.program+'</div>':'')+'</div>'+
      '<div class="cst"><div class="csi"><div class="v">$'+(item.value_usd||0).toFixed(0)+'</div><div class="l">Value</div></div>'+
      '<div class="csi"><div class="v">'+((item.ai_confidence||0)*100).toFixed(0)+'%</div><div class="l">AI Conf</div></div>'+
      '<div class="csi"><div class="v">'+(item.impact_magnitude||'-')+'</div><div class="l">Magnitude</div></div></div>';
  } else if(item.type==='TASK_COMPLETED'){
    var qa='';
    if(item.status==='PENDING')     qa='<button class="qa" onclick="qta(\''+item.id+'\',\'PENDING\')">\u26A1 Assign</button>';
    if(item.status==='ASSIGNED')    qa='<button class="qa" onclick="qta(\''+item.id+'\',\'ASSIGNED\')">\u25B6 Start</button>';
    if(item.status==='IN_PROGRESS') qa='<button class="qa" onclick="om(\'mev\')">\uD83D\uDCF8 Evidence</button>';
    if(item.status==='SUBMITTED')   qa='<button class="qa" onclick="qta(\''+item.id+'\',\'SUBMITTED\')">\u2714 Complete</button>';
    body='<div class="cb2"><div class="ct2"><span style="cursor:pointer" onclick="loadTaskDetail(\''+item.id+'\')">'+item.title+'</span></div>'+(sdgs?'<div class="sdgr">'+sdgs+'</div>':'')+
      (item.program?'<div style="font-size:.76rem;color:var(--slate);cursor:pointer" onclick="loadProgramDetail(\''+item.program_id+'\')">\uD83C\uDFDB '+item.program+'</div>':'')+
      '<div style="display:flex;gap:.5rem;align-items:center;margin-top:.45rem;flex-wrap:wrap">'+
      '<span style="font-size:.75rem;background:#d5f5e3;color:#1e8449;padding:.18rem .55rem;border-radius:20px;font-weight:700">\u2713 Verified</span>'+
      '<span style="font-size:.73rem;color:var(--slate)">Priority: '+item.priority+'</span>'+
      (item.evidence_count?'<span style="font-size:.73rem;color:var(--slate)">\uD83D\uDCCE '+item.evidence_count+' evidence</span>':'')+'</div></div>'+
      '<div class="htimeline"><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">Created</div></div><div class="ht-line done"></div><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">Assigned</div></div><div class="ht-line done"></div><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">In Progress</div></div><div class="ht-line done"></div><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">Submitted</div></div><div class="ht-line done"></div><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">Completed</div></div></div>'+
      '<div class="hbar"><div class="hfill hfill-green" style="width:100%"></div></div>'+
      '<div class="cst"><div class="csi"><div class="v">'+(item.evidence_count||0)+'</div><div class="l">Evidence</div></div>'+
      '<div class="csi"><div class="v">'+item.priority+'</div><div class="l">Priority</div></div>'+
      '<div class="csi"><div class="v">\u2713</div><div class="l">Verified</div></div></div>';
    r._qa=qa;
  } else {
    var pr = item.task_count ? Math.round(((item.tasks_completed||0)/item.task_count)*100) : 0;
    body='<div class="cb2"><div class="ct2"><span style="cursor:pointer" onclick="loadProgramDetail(\''+item.id+'\')">'+item.title+'</span></div>'+(item.description?'<div class="cd">'+item.description+'</div>':'')+
      (sdgs?'<div class="sdgr">'+sdgs+'</div>':'')+(item.country?'<div style="font-size:.73rem;color:var(--slate)">\uD83D\uDCCD '+item.country+'</div>':'')+
      '</div>'+
      '<div class="htimeline"><div class="ht-step"><div class="ht-dot done"></div><div class="ht-label">Launched</div></div><div class="ht-line done"></div><div class="ht-step"><div class="ht-dot curr"></div><div class="ht-label">Active</div></div><div class="ht-line"></div><div class="ht-step"><div class="ht-dot"></div><div class="ht-label">Impact</div></div></div>'+
      '<div class="hbar"><div class="hfill hfill-blue" style="width:'+pr+'%"></div></div>'+
      '<div class="cst"><div class="csi"><div class="v">'+(item.task_count||0)+'</div><div class="l">Tasks</div></div>'+
      '<div class="csi"><div class="v">'+(item.enrolled||0)+'</div><div class="l">Enrolled</div></div>'+
      '<div class="csi"><div class="v">'+((item.sdg_goals||[]).length)+'</div><div class="l">SDGs</div></div></div>';
  }

  var tierLabel=actor.tier!=='BRONZE'?'<span style="font-size:.68rem;color:'+tc(actor.tier)+';font-weight:700"> \u25CF '+actor.tier+'</span>':'';
  var commentsSection='<div class="csection" id="cs-'+rk+'" style="display:none"><div class="clist" id="cl-'+rk+'"></div><div class="cpost"><input id="ci-'+rk+'" placeholder="Write a comment..." class="ci-input"/><button class="btn bg bsm" onclick="postComment(\''+rk+'\')">Post</button></div></div>';
  return '<div class="card '+typeClass+'" id="c-'+item.id+'" style="--i:'+idx+'">'+
    '<div class="ch">'+av2+'<div class="cm"><div class="cn" onclick="openUserProfile(\''+aid+'\')">'+actor.name+tierLabel+'</div>'+
    '<div class="cs">'+actor.role+' \u00B7 PMS '+(actor.pms||0).toFixed(3)+'</div></div>'+tb+
    '<div class="ct">'+ago(item.created_at)+'</div></div>'+body+
    '<div class="rb">'+
    '<button class="rx" id="rf-'+rk+'" onclick="rx(\''+rk+'\',\'fire\',this)">\uD83D\uDD25 <span class="rxn">'+(r.fire||0)+'</span></button>'+
    '<button class="rx" id="rs-'+rk+'" onclick="rx(\''+rk+'\',\'star\',this)">\u2B50 <span class="rxn">'+(r.star||0)+'</span></button>'+
    '<button class="rx" id="rc-'+rk+'" onclick="rx(\''+rk+'\',\'clap\',this)">\uD83D\uDC4F <span class="rxn">'+(r.clap||0)+'</span></button>'+
    '<button class="rx cmt-btn" onclick="toggleComments(\''+rk+'\')">\uD83D\uDCAC <span class="rxn">'+cc+'</span></button>'+
    (r._qa||'')+
    '<button class="sh2" onclick="toast(\'Link copied! (demo)\',\'i\')">\u2192</button>'+
    '</div>'+commentsSection+'</div>';
}

function rx(id,type,btn){
  var k=id+type,on=RX[k];RX[k]=!on;
  var el=btn.querySelector('.rxn');
  el.textContent=parseInt(el.textContent)+(on?-1:1);
  btn.classList.toggle('on',!on);
}

function toggleComments(postId){
  var section=document.getElementById('cs-'+postId);
  if(!section)return;
  var show=section.style.display!=='block';
  section.style.display=show?'block':'none';
  if(show) loadCommentsInline(postId);
}
function loadCommentsInline(postId){
  var list=document.getElementById('cl-'+postId);
  if(!list)return;
  list.innerHTML='<div style="text-align:center;padding:.6rem;color:var(--text-secondary);font-size:.78rem">Loading comments...</div>';
  api('GET','/api/comments/'+postId,null,function(err,comments){
    if(err||!comments||!comments.length){
      list.innerHTML='<div style="text-align:center;padding:.6rem;color:var(--text-secondary);font-size:.78rem">No comments yet. Be the first!</div>';
      return;
    }
    list.innerHTML=comments.map(function(c){
      return '<div class="cmt"><div class="cmt-av" style="background:'+avc(c.user_name)+'">'+ini(c.user_name)+'</div><div class="cmt-body"><div class="cmt-hdr"><span class="cmt-name">'+c.user_name+'</span><span class="cmt-time">'+ago(c.created_at)+'</span></div><div class="cmt-text">'+c.content+'</div></div></div>';
    }).join('');
  });
}
function postComment(postId){
  if(!postId)return;
  var input=document.getElementById('ci-'+postId);
  if(!input)return;
  var content=input.value.trim();
  if(!content){toast('Write a comment first','i');return;}
  api('POST','/api/comments',{post_id:postId,content:content},function(err){
    if(err){toast(err.message,'error');return;}
    input.value='';
    loadCommentsInline(postId);
    toast('Comment posted','success');
    var btn=document.querySelector('#c-'+postId+' .cmt-btn .rxn');
    if(btn) btn.textContent=parseInt(btn.textContent||'0')+1;
  });
}

function qta(tid,status){
  if(status==='PENDING'){
    api('GET','/api/users',null,function(err,us){
      if(err) return;
      document.getElementById('atid').value=tid;
      renderTags('asu-tags','asu',(us||[]).map(function(u){return {value:u.id,label:u.full_name};}),{mode:'avatar'});
      om('massign');
    });return;
  }
  if(status==='ASSIGNED')  api('POST','/api/tasks/'+tid+'/start',{},function(err){if(err)toast(err.message,'error');else{toast('Task started \u25B6');reload();}});
  if(status==='SUBMITTED') api('POST','/api/tasks/'+tid+'/complete',{},function(err){if(err)toast(err.message,'error');else{toast('Task completed \uD83C\uDF89');reload();}});
}
function doAssign(){
  var tid=document.getElementById('atid').value;
  var uid=document.getElementById('asu').value;
  api('POST','/api/tasks/'+tid+'/assign?assignee_id='+uid,{},function(err){
    if(err){toast(err.message,'error');return;}
    cm('massign');toast('Task assigned \u2713');reload();
  });
}

function reload(){loadSide();loadLB();loadSDG();resetFeed();loadFeed();}

function loadSide(){
  api('GET','/api/stats',null,function(err,s){
    if(err) return;
    document.getElementById('ssbox').innerHTML='<div style="font-size:.68rem;font-weight:700;color:var(--text);text-transform:uppercase;letter-spacing:.7px;margin-bottom:.45rem">Platform Stats</div>'+
      [['\uD83D\uDC65 Users',s.users],['\uD83D\uDCCB Programs',s.programs],['\u2705 Completed',s.tasks_completed],
       ['\uD83D\uDC8E Assets',s.impact_assets],['\uD83D\uDCB0 Value','$'+s.total_value_usd.toFixed(0)],['\u26A1 Events',s.events_emitted]]
      .map(function(x){return '<div class="ss-row"><span>'+x[0]+'</span><span class="v">'+x[1]+'</span></div>';}).join('');
  });
}

function loadLB(){
  api('GET','/api/leaderboard',null,function(err,lb){
    if(err) return;
    document.getElementById('lbl').innerHTML=lb.map(function(u,i){
      return '<div class="lbi"><div class="lbr '+(i<3?'top':'')+'">'+
        (i===0?'\uD83E\uDD47':i===1?'\uD83E\uDD48':i===2?'\uD83E\uDD49':i+1)+'</div>'+
        '<div class="lba" style="background:'+avc(u.name)+'">'+ini(u.name)+'</div>'+
        '<div style="flex:1;min-width:0"><div class="lbn">'+u.name+'</div>'+
        '<div class="lbt" style="color:'+tc(u.tier)+'">'+u.tier+' \u00B7 '+u.tasks+' tasks</div></div>'+
        '<div class="lbs">'+u.composite.toFixed(3)+'</div></div>';
    }).join('')||'<div style="color:var(--text-secondary);font-size:.8rem">No data yet</div>';
  });
}

function loadSDG(){
  api('GET','/api/sdg-impact',null,function(err,sdgs){
    if(err) return;
    if(!sdgs||!sdgs.length){document.getElementById('sdgw').innerHTML='<div style="color:var(--text-secondary);font-size:.8rem">Submit evidence to see SDG impact</div>';return;}
    var mx=Math.max.apply(null,sdgs.map(function(s){return s.activities;}));
    document.getElementById('sdgw').innerHTML=sdgs.map(function(s){
      return '<div class="sdgi"><div class="sdgn">'+s.sdg+'</div>'+
        '<div class="sdgbw"><div style="font-size:.68rem;color:var(--text-secondary);margin-bottom:.18rem">$'+s.value_usd.toFixed(0)+' \u00B7 '+s.activities+' activities</div>'+
        '<div class="sdgbt"><div class="sdgbf" style="width:'+Math.round(s.activities/mx*100)+'%"></div></div></div>'+
        '<div class="sdgv">'+s.activities+'</div></div>';
    }).join('');
  });
}

function loadPP(uid){
  var id=uid||(ME&&ME.user_id);
  if(!id) return;
  api('GET','/api/users/'+id+'/impact-passport',null,function(err,pp){
    if(err){toast('Could not load passport','error');return;}
    document.getElementById('ppid').textContent=pp.passport_id;
    document.getElementById('ppn').textContent=pp.full_name;
    document.getElementById('pps').textContent=pp.pms_score.toFixed(3);
    document.getElementById('ppt').textContent=pp.tasks_completed||0;
    document.getElementById('ppe').textContent=pp.evidence_submitted||0;
    document.getElementById('ppv').textContent='$'+(pp.total_value_usd||0).toFixed(0);
    var tb=document.getElementById('pptier');
    tb.textContent=pp.tier;tb.style.background=tc(pp.tier);tb.style.color=pp.tier==='GOLD'?'#0A1628':'#fff';
    var dims=pp.dimensions||{};
    document.getElementById('ppdims').innerHTML=Object.keys(dims).map(function(k){
      return '<div class="dc"><div class="dl">'+k.replace(/_/g,' ')+'</div>'+
        '<div class="dt"><div class="df" style="width:'+(dims[k]*100).toFixed(1)+'%"></div></div>'+
        '<div class="dv">'+dims[k].toFixed(3)+'</div></div>';
    }).join('');
    api('GET','/api/users',null,function(err,us){
      if(err) return;
      document.getElementById('ppusers').innerHTML=us.map(function(u){
        return '<div style="display:flex;align-items:center;gap:.55rem;padding:.45rem 0;border-bottom:1px solid var(--border-light)">'+
          '<div style="width:32px;height:32px;border-radius:50%;background:'+avc(u.full_name)+';display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:.72rem;flex-shrink:0">'+ini(u.full_name)+'</div>'+
          '<div style="flex:1;min-width:0"><div style="font-size:.82rem;font-weight:600">'+u.full_name+'</div>'+
          '<div style="font-size:.68rem;color:var(--text-secondary)">'+u.role+' \u00B7 '+u.tasks_completed+' tasks</div></div>'+
          '<button class="btn bgh bsm" onclick="loadPP(\''+u.id+'\')">View</button></div>';
      }).join('');
    });
  });
}

function om(id){
  if(id==='mprog'||id==='mtask'){
    api('GET','/api/organizations',null,function(err,os){
      var items=(os||[]).map(function(o){return {value:o.id,label:o.name};});
      if(!items.length) items=[{value:'',label:'No orgs yet \u2014 create one below'}];
      renderTags('mpo-tags','mpo',items,{});
    });
    api('GET','/api/programs',null,function(err,ps){
      renderTags('mtp-tags','mtp',[{value:'',label:'Select program...'}].concat((ps||[]).map(function(p){return {value:p.id,label:p.title};})),{});
    });
    api('GET','/api/users',null,function(err,us){
      renderTags('mtu-tags','mtu',[{value:'',label:'Unassigned'}].concat((us||[]).map(function(u){return {value:u.id,label:u.full_name};})),{mode:'avatar'});
    });
  }
  if(id==='mev'){
    api('GET','/api/tasks',null,function(err,ts){
      var items=[{value:'',label:'Select task...'}].concat((ts||[]).map(function(t){return {value:t.id,label:t.title,sub:'['+t.status+']'};}));
      renderTags('met-tags','met',items,{});
    });
  }
  document.getElementById(id).classList.add('open');
  document.getElementById('mnav-overlay').classList.remove('open');
}
function cm(id){document.getElementById(id).classList.remove('open');}
document.addEventListener('click',function(e){
  if(e.target.classList.contains('mb')) e.target.classList.remove('open');
  if(!e.target.closest('.sw')) closeSearchResults();
});
function createOrg(){
  var n=document.getElementById('mon').value.trim();
  if(!n){toast('Enter org name','error');return;}
  api('POST','/api/organizations',{name:n,org_type:'NGO',country:'Egypt'},function(err){
    if(err){toast(err.message,'error');return;}
    document.getElementById('mon').value='';toast('Organization created \u2713');
    api('GET','/api/organizations',null,function(err,os){
      renderTags('mpo-tags','mpo',(os||[]).map(function(o){return {value:o.id,label:o.name};}),{});
    });
  });
}

function createOrg2(){
  var n=document.getElementById('orn').value.trim();
  if(!n){toast('Enter org name','error');return;}
  api('POST','/api/organizations',{name:n,org_type:document.getElementById('ort').value,country:document.getElementById('orc').value},function(err){
    if(err){toast(err.message,'error');return;}
    cm('morg');toast('Organization created \u2713');
  });
}

function createProg(){
  var oid=document.getElementById('mpo').value;
  var title=document.getElementById('mpt').value.trim();
  if(!oid){toast('Select or create an organization first','error');return;}
  if(!title){toast('Enter program title','error');return;}
  var sdgs=document.getElementById('mpsdg').value.split(',').map(function(s){return parseInt(s.trim());}).filter(Boolean);
  api('POST','/api/programs',{organization_id:oid,title:title,description:document.getElementById('mpd').value,
    sdg_goals:sdgs,country:document.getElementById('mpc').value},function(err){
    if(err){toast(err.message,'error');return;}
    document.getElementById('mpt').value='';document.getElementById('mpd').value='';
    cm('mprog');toast('Program launched \uD83D\uDE80');reload();
  });
}

function createTask(){
  var pid=document.getElementById('mtp').value;
  var title=document.getElementById('mtt').value.trim();
  if(!pid){toast('Select a program','error');return;}
  if(!title){toast('Enter task title','error');return;}
  api('POST','/api/tasks',{program_id:pid,title:title,priority:document.getElementById('mtz').value,
    assignee_id:document.getElementById('mtu').value||null,evidence_required:true},function(err){
    if(err){toast(err.message,'error');return;}
    document.getElementById('mtt').value='';cm('mtask');toast('Task created \u2713');reload();
  });
}

function submitEv(){
  var tid=document.getElementById('met').value;
  if(!tid){toast('Select a task','error');return;}
  api('POST','/api/evidence',{task_id:tid,media_type:document.getElementById('mem').value,
    file_size_bytes:1800000,latitude:parseFloat(document.getElementById('mela').value)||null,
    longitude:parseFloat(document.getElementById('melo').value)||null,
    description:document.getElementById('med').value},function(err,ev){
    if(err){toast(err.message,'error');return;}
    api('POST','/api/tasks/'+tid+'/submit?evidence_ids='+ev.id,{},function(){});
    document.getElementById('med').value='';cm('mev');
    var v=ev.verification||{};
    if((v.confidence||0)>=0.8) toast('\u2705 APPROVED \u2014 AI confidence '+(v.confidence*100).toFixed(1)+'% \u00B7 Impact asset created!','success',5000);
    else toast('\u26A0\uFE0F Needs Review \u2014 AI confidence '+(v.confidence*100).toFixed(1)+'%','i',4000);
    reload();if(document.getElementById('pp').style.display==='block') loadPP();
  });
}

var ALGO_PARAMS_DEFAULTS={
  verified_weight:0.5,value_weight:0.3,value_threshold:50,
  confidence_weight:0.2,confidence_threshold:0.9,
  pms_weight:0.3,recency_boost:0.0,reaction_weight:0.0,
  content_diversity:0.0
};

function loadAlgoParams(){
  api('GET','/api/algo-params',null,function(err,params){
    if(err){toast('Could not load algo params','error');return;}
    var container=document.getElementById('algoparams');
    var labels={
      verified_weight:'Verified Bonus',value_weight:'Value Bonus',
      value_threshold:'Value Threshold ($)',confidence_weight:'AI Confidence Bonus',
      confidence_threshold:'AI Confidence Threshold',pms_weight:'PMS Weight',
      recency_boost:'Recency Boost',reaction_weight:'Engagement Weight',
      content_diversity:'Content Diversity'
    };
    var hints={
      verified_weight:'Extra score for verified items',
      value_weight:'Score bonus for items above value threshold',
      confidence_threshold:'Minimum AI confidence for bonus',
      recency_boost:'Higher = newer items rank higher',
      reaction_weight:'Higher = popular items rank higher'
    };
    container.innerHTML=Object.keys(ALGO_PARAMS_DEFAULTS).map(function(k){
      var v=params[k]!==undefined?params[k]:ALGO_PARAMS_DEFAULTS[k];
      var isPct=k.indexOf('threshold')>-1||k==='confidence_weight'||k==='content_diversity';
      var max=k.indexOf('threshold')>-1?100:k==='content_diversity'?2:2;
      var step=k.indexOf('threshold')>-1||k.indexOf('weight')>-1||k==='recency_boost'||k==='reaction_weight'?0.05:1;
      var displayVal=isPct?(v*100).toFixed(0):(typeof v==='number'?v.toFixed(step<1?2:0):v);
      return '<div class="ap-row">'+
        '<div class="ap-label"><strong>'+(labels[k]||k)+'</strong>'+
        (hints[k]?'<br/><span class="ap-hint">'+hints[k]+'</span>':'')+'</div>'+
        '<div class="ap-slider-wrap">'+
        '<input type="range" class="ap-slider" id="ap-'+k+'" min="0" max="'+max+'" step="'+step+'" value="'+v+'" oninput="updateAlgoVal(\''+k+'\',this.value)"/>'+
        '<span class="ap-val" id="apv-'+k+'">'+displayVal+(isPct?'%':'')+'</span></div></div>';
    }).join('');
    window._algoParams=JSON.parse(JSON.stringify(params));
  });
}

function updateAlgoVal(k,v){
  v=parseFloat(v);
  var isPct=k.indexOf('threshold')>-1||k==='confidence_weight'||k==='content_diversity';
  document.getElementById('apv-'+k).textContent=(isPct?(v*100).toFixed(0):(k.indexOf('weight')>-1||k==='recency_boost'||k==='reaction_weight'?v.toFixed(2):v.toFixed(0)))+(isPct?'%':'');
}

function saveAlgoParams(){
  var body={};
  Object.keys(ALGO_PARAMS_DEFAULTS).forEach(function(k){
    var el=document.getElementById('ap-'+k);
    if(el) body[k]=parseFloat(el.value);
  });
  api('PUT','/api/algo-params',body,function(err,res){
    if(err){toast(err.message,'error');return;}
    toast('Algorithm parameters updated \u2713','success');
    window._algoParams=JSON.parse(JSON.stringify(res));
  });
}

function resetAlgoParams(){
  Object.keys(ALGO_PARAMS_DEFAULTS).forEach(function(k){
    var el=document.getElementById('ap-'+k);
    if(el){el.value=ALGO_PARAMS_DEFAULTS[k];updateAlgoVal(k,ALGO_PARAMS_DEFAULTS[k]);}
  });
  toast('Reset to defaults \u21A9','i');
}

(function(){
  var origOm=om;
  om=function(id){
    if(id==='malgo'){loadAlgoParams();}
    origOm(id);
  };
})();
function loadNetwork(){
  var canvas=document.getElementById('netCanvas');
  if(!canvas) return;
  var container=canvas.parentElement;
  if(!container) return;
  var tipEl=document.getElementById('netTip');
  api('GET','/api/network',null,function(err,data){
    if(err||!data||!data.nodes||!data.nodes.length){toast('Network data unavailable','error');return;}
    var dpr=window.devicePixelRatio||1;
    var W=container.clientWidth||600;
    var H=Math.max(400,window.innerHeight-480);
    if(W<10) W=600;
    canvas.width=W*dpr;
    canvas.height=H*dpr;
    canvas.style.width=W+'px';
    canvas.style.height=H+'px';
    var ctx=canvas.getContext('2d');
    ctx.scale(dpr,dpr);
    
    document.getElementById('ntotal').textContent=data.nodes.length;
    document.getElementById('nedges').textContent=data.edges.length;
    document.getElementById('nclusters').textContent=(data.edges.length/Math.max(data.nodes.length,1)).toFixed(1);
    
    var nodes=data.nodes.map(function(n){
      var r=16+(n.pms||0)*10;
      return {id:n.id,name:n.name||'User',tier:n.tier||'BRONZE',pms:n.pms||0,
        x:Math.random()*W*0.6+W*0.2,y:Math.random()*H*0.6+H*0.2,
        vx:0,vy:0,radius:r<20?20:r>40?40:r};
    });
    var nodeMap={};
    nodes.forEach(function(n){nodeMap[n.id]=n;});
    var edges=data.edges.filter(function(e){return nodeMap[e.source]&&nodeMap[e.target];});
    
    var tierColors={BRONZE:'#cd7f32',SILVER:'#aaa',GOLD:'#C9A84C',PLATINUM:'#a0b2c6'};
    var dragNode=null,dx=0,dy=0;
    
    function gpos(e){
      var r=canvas.getBoundingClientRect();
      var cx=e.clientX||(e.touches&&e.touches[0].clientX)||0;
      var cy=e.clientY||(e.touches&&e.touches[0].clientY)||0;
      return {x:cx-r.left,y:cy-r.top};
    }
    function onDown(e){
      var p=gpos(e);
      for(var i=nodes.length-1;i>=0;i--){
        var n=nodes[i];
        if(p.x>n.x-n.radius&&p.x<n.x+n.radius&&p.y>n.y-n.radius&&p.y<n.y+n.radius){
          dragNode=n;dx=p.x-n.x;dy=p.y-n.y;n.vx=0;n.vy=0;break;
        }
      }
    }
    function onMove(e){
      var p=gpos(e);
      if(dragNode){dragNode.x=p.x-dx;dragNode.y=p.y-dy;return;}
      if(!tipEl)return;
      var found=false;
      for(var i=nodes.length-1;i>=0;i--){
        var n=nodes[i];
        if(p.x>n.x-n.radius&&p.x<n.x+n.radius&&p.y>n.y-n.radius&&p.y<n.y+n.radius){
          tipEl.innerHTML='<b>'+n.name+'</b><br/>PMS '+n.pms.toFixed(2)+' | '+n.tier;
          tipEl.style.display='block';
          tipEl.style.left=Math.min(p.x+12,W-150)+'px';
          tipEl.style.top=Math.max(p.y-30,0)+'px';
          found=true;break;
        }
      }
      if(!found) tipEl.style.display='none';
    }
    function onUp(){dragNode=null;}
    
    canvas.addEventListener('mousedown',onDown);
    canvas.addEventListener('mousemove',onMove);
    canvas.addEventListener('mouseup',onUp);
    canvas.addEventListener('mouseleave',function(){dragNode=null;if(tipEl)tipEl.style.display='none';});
    canvas.addEventListener('touchstart',function(e){onDown(e);},{passive:true});
    canvas.addEventListener('touchmove',function(e){if(dragNode){var p=gpos(e);dragNode.x=p.x-dx;dragNode.y=p.y-dy;}},{passive:true});
    canvas.addEventListener('touchend',onUp);
    
    var running=true;
    function step(){
      try{
        if(!running||!nodes.length) return;
        for(var i=0;i<nodes.length;i++){
          for(var j=i+1;j<nodes.length;j++){
            var a=nodes[i],b=nodes[j];
            var dx2=a.x-b.x,dy2=a.y-b.y;
            var dist=Math.sqrt(dx2*dx2+dy2*dy2)||1;
            var f=1200/(dist+1);
            a.vx+=dx2/dist*f;a.vy+=dy2/dist*f;
            b.vx-=dx2/dist*f;b.vy-=dy2/dist*f;
          }
        }
        edges.forEach(function(e){
          var a=nodeMap[e.source],b=nodeMap[e.target];
          if(!a||!b)return;
          var dx2=b.x-a.x,dy2=b.y-a.y;
          var dist=Math.sqrt(dx2*dx2+dy2*dy2)||1;
          var f=(dist-200)*0.003;
          a.vx+=dx2/dist*f;a.vy+=dy2/dist*f;
          b.vx-=dx2/dist*f;b.vy-=dy2/dist*f;
        });
        var cx=W/2,cy=H/2;
        for(var i=0;i<nodes.length;i++){
          var n=nodes[i];
          n.vx+=(cx-n.x)*0.001;
          n.vy+=(cy-n.y)*0.001;
          n.vx*=0.85;n.vy*=0.85;
          n.x+=n.vx;n.y+=n.vy;
          n.x=Math.max(n.radius,Math.min(W-n.radius,n.x));
          n.y=Math.max(n.radius,Math.min(H-n.radius,n.y));
        }
        ctx.clearRect(0,0,W,H);
        ctx.fillStyle='rgba(10,22,40,0.05)';
        ctx.fillRect(0,0,W,H);
        ctx.strokeStyle='rgba(201,168,76,0.15)';
        ctx.lineWidth=1;
        for(var i=0;i<edges.length;i++){
          var e=edges[i],a=nodeMap[e.source],b=nodeMap[e.target];
          if(!a||!b)continue;
          ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke();
        }
        for(var i=0;i<nodes.length;i++){
          var n=nodes[i],c=tierColors[n.tier]||'#8A9BB5';
          ctx.beginPath();ctx.arc(n.x,n.y,n.radius,0,Math.PI*2);
          ctx.fillStyle=c;ctx.fill();
          ctx.strokeStyle='rgba(255,255,255,0.2)';ctx.lineWidth=2;ctx.stroke();
          ctx.fillStyle='#fff';ctx.font='bold '+(n.radius*0.5)+'px sans-serif';
          ctx.textAlign='center';ctx.textBaseline='middle';
          ctx.fillText(ini(n.name),n.x,n.y);
        }
      }catch(e){}
      requestAnimationFrame(step);
    }
    step();
  });
}

function openUserProfile(id){
  if(!id||id==='platform'||id==='undefined'||id==='null') return;
  UPID=id;
  pg('profile');
}

function loadUserProfile(userId){
  if(!userId) return;
  var container=document.getElementById('up');
  container.innerHTML='<div class="up-loading"><div class="sp"></div></div>';
  api('GET','/api/users/'+userId+'/profile',null,function(err,pp){
    if(err||!pp){toast('Could not load profile','error');container.innerHTML='<div class="up-loading" style="text-align:center;padding:2rem"><p>Profile not available</p><button class="btn bgh bsm" onclick="pg(\'feed\')">Back to Feed</button></div>';return;}
    var name=pp.full_name||'User';
    var pms=pp.pms||{};
    var dims=pms.dimensions||{};
    var ra=pp.recent_activity||[];
    var tier=pms.tier||'BRONZE';
    var cover=pp.cover_photo||'https://picsum.photos/seed/'+userId+'/820/240';
    var avatar=pp.avatar||'https://i.pravatar.cc/120?u='+userId;
    var tierColor=tc(tier);
    var role=(pp.role||'INDIVIDUAL');
    var location=(pp.location||'');
    
    var statsHTML='<div class="up-stats">'+
      '<div class="us-item"><div class="us-num">'+(pms.composite!==undefined?pms.composite.toFixed(3):'0.000')+'</div><div class="us-label">PMS</div></div>'+
      '<div class="us-item"><div class="us-num">'+(pp.tasks_completed_count||0)+'</div><div class="us-label">Tasks</div></div>'+
      '<div class="us-item"><div class="us-num">'+(pp.evidence_count||0)+'</div><div class="us-label">Evidence</div></div>'+
      '<div class="us-item"><div class="us-num">$'+(pp.total_value_usd||0).toFixed(0)+'</div><div class="us-label">Value</div></div></div>';
    
    var dimsHTML='<div class="wg" style="margin-top:1rem"><h3>PMS Dimensions</h3><div class="dg">'+
      (Object.keys(dims).length?Object.keys(dims).map(function(k){
        return '<div class="dc"><div class="dl">'+k.replace(/_/g,' ')+'</div><div class="dt"><div class="df" style="width:'+(dims[k]*100).toFixed(1)+'%"></div></div><div class="dv">'+dims[k].toFixed(3)+'</div></div>';
      }).join(''):'<div style="color:var(--text-secondary);font-size:.8rem">No data</div>')+'</div></div>';
    
    var activityHTML='<div class="up-activity-list">'+
      (ra.length?ra.map(function(a){
        var icon='<span style="font-size:1.1rem">'+(a.type==='TASK_COMPLETED'?'\u2705':'\uD83D\uDC8E')+'</span>';
        var desc=a.type==='TASK_COMPLETED'?'Completed <strong>'+a.title+'</strong>':('Evidence approved: <strong>'+(a.task_title||a.title||'')+'</strong> ('+a.media_type+')');
        var prog=a.program_title?'<span style="color:var(--text-secondary);font-size:.72rem">in '+a.program_title+'</span>':'';
        return '<div class="ua-item">'+icon+'<div class="ua-body"><div class="ua-text">'+desc+'</div>'+prog+'<div class="ua-time">'+ago(a.created_at)+'</div></div></div>';
      }).join(''):'<div class="up-empty">No recent activity</div>')+'</div>';
    
    container.innerHTML='<div class="up-cover"><img src="'+cover+'" alt="Cover"/><div class="up-avatar"><img src="'+avatar+'" alt="'+name+'" onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\'"/><div class="up-avatar-f" style="display:none;background:linear-gradient(135deg,'+avc(name)+',#C9A84C)"><span>'+ini(name)+'</span></div></div></div>'+
      '<div class="up-body"><h1>'+name+'</h1>'+
      '<div class="up-meta"><span class="tb2">'+role+'</span><span class="up-tier" style="color:'+tierColor+'">'+tier+'</span>'+
      (location?'<span class="up-location">'+location+'</span>':'')+'</div>'+
      '<p class="up-bio">'+(pp.bio||'No bio yet')+'</p>'+
      statsHTML+
      '<div class="up-dims-section">'+dimsHTML+'</div>'+
      '<div class="up-ptabs"><button class="up-ptab act" onclick="switchUpTab(\'activity\',this)">Activity</button><button class="up-ptab" onclick="switchUpTab(\'evidence\',this)">Evidence</button><button class="up-ptab" onclick="switchUpTab(\'programs\',this)">Programs</button></div>'+
      '<div class="up-ptab-content active" id="upTabActivity">'+activityHTML+'</div>'+
      '<div class="up-ptab-content" id="upTabEvidence"><div class="up-empty">Evidence tab loaded</div></div>'+
      '<div class="up-ptab-content" id="upTabPrograms"><div class="up-empty">Programs tab loaded</div></div>'+
      '<div style="text-align:center;margin:1rem 0"><button class="btn bgh bsm" onclick="pg(\'feed\')">\u2190 Back to Feed</button></div></div>';
    
    // Load evidence and programs into tabs
    var pid=pp.user_id||userId;
    api('GET','/api/evidence?user_id='+pid,null,function(err,evs){
      if(evs&&evs.length){
        document.getElementById('upTabEvidence').innerHTML='<div class="up-ev-grid">'+
          evs.slice(0,12).map(function(e){
            var url=e.evidence_image_url||'';
            var type=e.media_type||'DOCUMENT';
            var icon={'PHOTO':'','VIDEO':'','AUDIO':'','DOCUMENT':''}[type]||'';
            if(type==='PHOTO'||type==='IMAGE'){
              return '<div class="up-ev-item" onclick="openLightbox(\''+(url||'https://picsum.photos/seed/'+e.id+'/600/400')+'\',\'image\')"><img src="'+(url||'https://picsum.photos/seed/'+e.id+'/400/300')+'" loading="lazy"/></div>';
            }
            if(type==='VIDEO'){
              return '<div class="up-ev-item up-ev-video" onclick="openLightbox(\''+(url||'')+'\',\'video\')"><div class="up-ev-play">\u25B6</div><img src="'+(url||'https://picsum.photos/seed/'+e.id+'/400/300')+'" loading="lazy"/></div>';
            }
            return '<div class="up-ev-item up-ev-doc"><span>'+(e.description||type)+'</span></div>';
          }).join('')+'</div>';
      } else {
        document.getElementById('upTabEvidence').innerHTML='<div class="up-empty">No evidence submitted yet</div>';
      }
    });
    api('GET','/api/programs?user_id='+pid,null,function(err,progs){
      if(progs&&progs.length){
        document.getElementById('upTabPrograms').innerHTML=progs.map(function(p){
          return '<div class="up-prog-item" onclick="loadProgramDetail(\''+p.id+'\')"><div class="upp-cover"><img src="'+(p.cover_photo||'https://picsum.photos/seed/'+p.id+'/100/60')+'"/></div><div class="upp-body"><div class="upp-title">'+p.title+'</div><div class="upp-meta">'+(p.task_count||0)+' tasks | '+(p.enrolled||0)+' enrolled</div></div></div>';
        }).join('');
      } else {
        document.getElementById('upTabPrograms').innerHTML='<div class="up-empty">No programs joined yet</div>';
      }
    });
  });
}
function switchUpTab(tab,btn){
  document.querySelectorAll('.up-ptab').forEach(function(b){b.classList.remove('act');});
  if(btn) btn.classList.add('act');
  document.querySelectorAll('.up-ptab-content').forEach(function(c){c.classList.remove('active');});
  var el={activity:'upTabActivity',evidence:'upTabEvidence',programs:'upTabPrograms'}[tab];
  if(el) document.getElementById(el).classList.add('active');
}
function loadProgramDetail(progId){
  if(!progId)return;
  api('GET','/api/programs/'+progId,null,function(err,p){
    if(err||!p){toast('Could not load program','error');return;}
    var ci=document.getElementById('mpdCoverImg');
    if(ci)ci.src=p.cover_photo||'';
    document.getElementById('mpdTitle').textContent=p.title||'';
    document.getElementById('mpdSdgs').innerHTML=(p.sdg_goals||[]).map(function(g){return '<span class="sdgp">SDG '+g+'</span>';}).join('');
    document.getElementById('mpdDesc').textContent=p.description||'';
    document.getElementById('mpdTasks').textContent=(p.tasks||[]).length||0;
    document.getElementById('mpdEnrolled').textContent=p.enrolled_count||0;
    document.getElementById('mpdCountry').textContent=p.country||'';
    var tl=document.getElementById('mpdTaskList');
    if(tl){
      var ts=p.tasks||[];
      tl.innerHTML=ts.length?ts.map(function(t){
        var sc={PENDING:'#f39c12',ASSIGNED:'#3498db',IN_PROGRESS:'#9b59b6',SUBMITTED:'#e67e22',COMPLETED:'#27ae60'};
        return '<div style="display:flex;align-items:center;gap:.5rem;padding:.35rem 0;border-bottom:1px solid var(--border-light);cursor:pointer" onclick="cm(\'mpdetail\');loadTaskDetail(\''+t.id+'\')"><span style="color:'+(sc[t.status]||'#8A9BB5')+';font-size:.7rem">\u25CF</span><span style="flex:1;color:var(--text)">'+t.title+'</span><span style="font-size:.68rem;color:var(--text-secondary)">'+t.status+'</span></div>';
      }).join(''):'<div style="color:var(--text-secondary);font-size:.8rem">No tasks yet</div>';
    }
    om('mpdetail');
  });
}

function loadTaskDetail(taskId){
  if(!taskId)return;
  api('GET','/api/tasks/'+taskId,null,function(err,t){
    if(err||!t){toast('Could not load task','error');return;}
    document.getElementById('mtdTitle').textContent=t.title||'';
    var se=document.getElementById('mtdStatus');
    se.textContent=t.status||'PENDING';
    var sc={PENDING:'#f39c12',ASSIGNED:'#3498db',IN_PROGRESS:'#9b59b6',SUBMITTED:'#e67e22',COMPLETED:'#27ae60',APPROVED:'#2ecc71'};
    se.style.background=sc[t.status]||'#8A9BB5';
    se.style.color='#fff';
    document.getElementById('mtdDesc').textContent=t.description||'';
    document.getElementById('mtdPriority').textContent=t.priority||'MEDIUM';
    document.getElementById('mtdProgram').textContent=(t.program&&t.program.title)||'';
    if(t.assignee){
      var av=document.getElementById('mtdAv');
      av.textContent=ini(t.assignee.full_name||'?');
      av.style.background=avc(t.assignee.full_name||'?');
      document.getElementById('mtdAssigneeName').textContent=t.assignee.full_name||'Unassigned';
      document.getElementById('mtdAssignee').dataset.uid=t.assignee.id||'';
    }
    var evList=document.getElementById('mtdEvidence');
    if(evList){
      var ev=t.evidence||[];
      evList.innerHTML=ev.length?ev.map(function(e){
        var mt=e.media_type||'DOCUMENT';
        var icon={PHOTO:'\uD83D\uDCF8',VIDEO:'\uD83C\uDFA5',AUDIO:'\uD83C\uDF99\uFE0F',DOCUMENT:'\uD83D\uDCC4'}[mt]||'\uD83D\uDCCE';
        var st=e.status||'pending';
        return '<div style="display:flex;align-items:center;gap:.5rem;padding:.35rem 0;border-bottom:1px solid var(--border-light);font-size:.8rem"><span>'+icon+'</span><span style="flex:1;color:var(--text)">'+(e.description||mt)+'</span><span style="font-size:.68rem;color:var(--text-secondary)">'+st+'</span><span style="font-size:.68rem;color:var(--text-secondary)">'+ago(e.created_at)+'</span></div>';
      }).join(''):'<div style="color:var(--text-secondary);font-size:.8rem">No evidence submitted</div>';
    }
    om('mtdetail');
  });
}

function openNotif(){
  NOTIFS=[
    {id:'n1',text:'\uD83D\uDD14 New impact asset worth $1,234 verified',time:new Date(Date.now()-300000).toISOString(),read:false},
    {id:'n2',text:'\u2705 Task "Site Assessment - Village X" completed',time:new Date(Date.now()-1800000).toISOString(),read:false},
    {id:'n3',text:'\uD83C\uDFC6 Your PMS score increased by 0.042',time:new Date(Date.now()-3600000).toISOString(),read:false},
    {id:'n4',text:'\uD83D\uDCF8 Khalid Nour submitted field evidence for review',time:new Date(Date.now()-7200000).toISOString(),read:true},
    {id:'n5',text:'\uD83D\uDE80 Program "Water Initiative" reached 10 tasks',time:new Date(Date.now()-14400000).toISOString(),read:true}
  ];
  updateNotifBadge();
}

function updateNotifBadge(){
  var badge=document.querySelector('#tb .nd');
  if(!badge) return;
  var unread=NOTIFS.filter(function(n){return !n.read;}).length;
  badge.textContent=unread||'';
  badge.style.display=unread?'flex':'none';
}
function toggleNotif(){
  var dd=document.getElementById('notifDropdown');
  if(!dd){
    dd=document.createElement('div');
    dd.id='notifDropdown';
    dd.style.cssText='position:fixed;top:56px;right:1rem;width:340px;max-height:400px;background:var(--bg-card);border:1px solid var(--border);border-radius:12px;box-shadow:0 8px 32px rgba(0,0,0,.2);z-index:5000;overflow-y:auto;display:none;font-size:.82rem';
    dd.onclick=function(e){e.stopPropagation();};
    document.body.appendChild(dd);
    document.addEventListener('click',function(e){
      var btn=document.querySelector('#tb .ni button[title="Notifications"]');
      if(btn&&!btn.contains(e.target)&&!dd.contains(e.target)){dd.style.display='none';NOTIF_OPEN=false;}
    });
  }
  NOTIF_OPEN=!NOTIF_OPEN;
  dd.style.display=NOTIF_OPEN?'block':'none';
  if(NOTIF_OPEN){
    var unread=NOTIFS.filter(function(n){return !n.read;}).length;
    dd.innerHTML='<div style="padding:.65rem .85rem;font-weight:700;border-bottom:1px solid var(--border-light);display:flex;justify-content:space-between;align-items:center"><span>Notifications</span><span style="background:var(--gold);color:#0A1628;font-size:.7rem;padding:.1rem .5rem;border-radius:10px">'+unread+' new</span></div>'+
      NOTIFS.map(function(n){
        return '<div style="display:flex;align-items:flex-start;gap:.5rem;padding:.55rem .85rem;border-bottom:1px solid var(--border-light);'+(n.read?'':'background:var(--bg)')+';cursor:pointer" onclick="markNotifRead(\''+n.id+'\')">'+
          '<div style="flex:1;min-width:0"><div style="font-size:.8rem;color:var(--text);line-height:1.4">'+n.text+'</div><div style="font-size:.68rem;color:var(--text-secondary);margin-top:.15rem">'+ago(n.time)+'</div></div>'+
          (n.read?'':'<div style="width:8px;height:8px;border-radius:50%;background:var(--gold);flex-shrink:0;margin-top:.35rem"></div>')+
          '</div>';
      }).join('')+
      '<div style="text-align:center;padding:.5rem;font-size:.72rem;color:var(--text-secondary);cursor:pointer" onclick="markAllNotifRead()">Mark all as read</div>';
  }
}

function markNotifRead(id){
  NOTIFS.forEach(function(n){if(n.id===id)n.read=true;});
  updateNotifBadge();
  var dd=document.getElementById('notifDropdown');
  if(dd&&dd.style.display==='block') toggleNotif();
}

function markAllNotifRead(){
  NOTIFS.forEach(function(n){n.read=true;});
  updateNotifBadge();
  var dd=document.getElementById('notifDropdown');
  if(dd) dd.style.display='none';
  NOTIF_OPEN=false;
  toast('All notifications marked as read','i');
}

function openLightbox(url,type){
  var lb=document.getElementById('lightbox');
  if(!lb){
    lb=document.createElement('div');
    lb.id='lightbox';
    lb.style.cssText='position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.92);z-index:9999;display:none;align-items:center;justify-content:center;opacity:0;transition:opacity .3s';
    lb.innerHTML='<div class="lb-close-wrap"><button class="lb-close" style="position:absolute;top:1rem;right:1.5rem;background:rgba(0,0,0,.5);border:none;color:#fff;font-size:1.5rem;cursor:pointer;z-index:10;line-height:1;width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;transition:.2s">\u2715</button></div><div id="lbContent" style="max-width:95vw;max-height:93vh;display:flex;align-items:center;justify-content:center"></div>';
    document.body.appendChild(lb);
    lb.addEventListener('click',function(e){if(e.target===lb) closeLightbox();});
    lb.querySelector('.lb-close').addEventListener('click',closeLightbox);
    document.addEventListener('keydown',function(e){if(e.key==='Escape') closeLightbox();});
  }
  var c=document.getElementById('lbContent');
  if(type==='video'){
    var isHls=url.match(/\.m3u8/i);
    if(isHls&&typeof Hls!=='undefined'){
      c.innerHTML='<video id="hlsVideo" controls autoplay style="max-width:95vw;max-height:93vh;border-radius:8px;background:#000;width:auto;height:auto"></video>';
      var v=document.getElementById('hlsVideo');
      var hls=new Hls();hls.loadSource(url);hls.attachMedia(v);
    } else if(isHls){
      c.innerHTML='<video controls autoplay style="max-width:95vw;max-height:93vh;border-radius:8px;background:#000;width:auto;height:auto"><source src="'+url+'" type="application/x-mpegURL"></video>';
    } else {
      c.innerHTML='<video src="'+url+'" controls autoplay style="max-width:95vw;max-height:93vh;border-radius:8px;background:#000;width:auto;height:auto"></video>';
    }
  } else {
    var hires=url.replace(/\/\d+\/\d+$/,'/1200/800').replace(/w=\d+/,'w=1200').replace(/h=\d+/,'h=800');
    if(hires===url) hires=url.replace(/\?.*$/,'')+'?w=1200&h=800';
    c.innerHTML='<img src="'+hires+'" class="lb-img" style="max-width:95vw;max-height:93vh;border-radius:8px;object-fit:contain;background:#000;width:auto;height:auto"/>';
  }
  lb.style.display='flex';
  setTimeout(function(){lb.style.opacity='1';},10);
}

function closeLightbox(){
  var lb=document.getElementById('lightbox');
  if(!lb)return;
  lb.style.opacity='0';
  setTimeout(function(){lb.style.display='none';},300);
}

function updateScrollProgress(){
  var scrollTop=window.scrollY||document.documentElement.scrollTop;
  var scrollHeight=document.documentElement.scrollHeight-document.documentElement.clientHeight;
  if(scrollHeight<=0) return;
  var bar=document.getElementById('scrollProgress');
  if(!bar){
    bar=document.createElement('div');
    bar.id='scrollProgress';
    bar.style.cssText='position:fixed;top:0;left:0;height:3px;background:linear-gradient(90deg,var(--gold),#e8c84a);z-index:10000;transition:width .1s;border-radius:0 2px 2px 0';
    document.body.appendChild(bar);
  }
  bar.style.width=Math.min(scrollTop/scrollHeight*100,100)+'%';
}

window.addEventListener('scroll',function(){
  updateScrollProgress();
  var btn=document.getElementById('scrollTop');
  if(btn) btn.classList.toggle('show',window.scrollY>600);
});

document.addEventListener('DOMContentLoaded',function(){
  var notifBtn=document.querySelector('#tb .ni button[title="Notifications"]');
  if(notifBtn) notifBtn.onclick=toggleNotif;
  var mo=document.getElementById('malgo');
  if(mo){var mo2=mo.querySelector('.md');if(mo2){mo2.addEventListener('click',function(e){e.stopPropagation();});}}
  if(TOKEN&&ME&&ME.user_id){
    document.getElementById('auth').style.display='none';
    document.getElementById('app').style.display='block';
    initApp();
  }
});

var searchDebounce=null;
document.getElementById('searchInput').addEventListener('input',function(){
  clearTimeout(searchDebounce);
  var q=this.value.trim();
  if(!q){closeSearchResults();return;}
  searchDebounce=setTimeout(function(){doSearch(q);},300);
});
document.getElementById('searchInput').addEventListener('keydown',function(e){
  if(e.key==='Enter'){
    clearTimeout(searchDebounce);
    var q=this.value.trim();
    if(q) doSearch(q);
  }
});

function doSearch(q){
  api('GET','/api/search?q='+encodeURIComponent(q),null,function(err,data){
    if(err) return;
    showSearchResults(data);
  });
}

function showSearchResults(data){
  var existing=document.getElementById('searchResults');
  if(existing) existing.remove();
  var div=document.createElement('div');
  div.id='searchResults';
  div.className='search-results';
  var html='',has=false;
  if(data.users&&data.users.length){
    html+='<div class="sr-section"><div class="sr-heading">Users</div>';
    data.users.forEach(function(u){
      has=true;
      html+='<div class="sr-item" onclick="openUserProfile(\''+u.id+'\');closeSearchResults()">'+
        '<div class="sr-avatar" style="background:'+avc(u.full_name)+'">'+ini(u.full_name)+'</div>'+
        '<div class="sr-info"><div class="sr-name">'+u.full_name+'</div><div class="sr-sub">'+u.role+'</div></div>'+
        '<span class="sr-badge tb2 tTC">User</span></div>';
    });
    html+='</div>';
  }
  if(data.programs&&data.programs.length){
    html+='<div class="sr-section"><div class="sr-heading">Programs</div>';
    data.programs.forEach(function(p){
      has=true;
      html+='<div class="sr-item" onclick="loadProgramDetail(\''+p.id+'\');closeSearchResults()">'+
        '<div class="sr-icon">\uD83D\uDCCB</div>'+
        '<div class="sr-info"><div class="sr-name">'+p.title+'</div><div class="sr-sub">'+(p.org_name||'')+'</div></div>'+
        '<span class="sr-badge tb2 tPL">Program</span></div>';
    });
    html+='</div>';
  }
  if(data.tasks&&data.tasks.length){
    html+='<div class="sr-section"><div class="sr-heading">Tasks</div>';
    data.tasks.forEach(function(t){
      has=true;
      html+='<div class="sr-item" onclick="loadTaskDetail(\''+t.id+'\');closeSearchResults()">'+
        '<div class="sr-icon">\u2705</div>'+
        '<div class="sr-info"><div class="sr-name">'+t.title+'</div><div class="sr-sub">'+t.status+' \u00B7 '+t.priority+'</div></div>'+
        '<span class="sr-badge tb2 tIA">Task</span></div>';
    });
    html+='</div>';
  }
  if(!has) html='<div class="sr-empty">No results found</div>';
  div.innerHTML=html;
  var sw=document.querySelector('.sw');
  if(sw) sw.appendChild(div);
}

function closeSearchResults(){
  var el=document.getElementById('searchResults');
  if(el) el.remove();
}
