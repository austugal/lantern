'use strict';
const $ = id => document.getElementById(id);
const token = location.hash.slice(1) || sessionStorage.getItem('lantern-token') || '';
if (token) sessionStorage.setItem('lantern-token', token);
history.replaceState(null, '', '/');
let state = null, selectedPeer = '', safety = '', geoWatch = null, toastTimer, pollBusy = false;
const element = (tag, text, cls) => {const n=document.createElement(tag); if(text!==undefined)n.textContent=text; if(cls)n.className=cls; return n;};
function toast(message,error=false){$('toast').textContent=message;$('toast').classList.toggle('error',error);$('toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').hidden=true,6500);}
async function api(command,data){const r=await fetch('/api/'+command,{method:'POST',headers:{'Content-Type':'application/json','X-Lantern-Token':token},body:JSON.stringify(data||{})});const body=await r.json();if(!r.ok)throw Error(body.error||'Request failed');return body;}
async function act(command,data){try{const result=await api(command,data);await refresh();return result;}catch(e){toast(e.message,true);return null;}}
function form(id,command,convert=x=>x,done=()=>{}){$(id).addEventListener('submit',async e=>{e.preventDefault();const button=e.submitter;if(button)button.disabled=true;try{const data=convert(Object.fromEntries(new FormData(e.currentTarget)));const result=await act(command,data);if(result)done(result);}finally{if(button)button.disabled=false;}});}
function page(name){document.querySelectorAll('.page').forEach(p=>p.hidden=p.id!=='page-'+name);document.querySelectorAll('.nav').forEach(b=>b.classList.toggle('active',b.dataset.page===name));}
document.querySelectorAll('.nav').forEach(b=>b.addEventListener('click',()=>page(b.dataset.page)));
$('home-link').onclick=e=>{e.preventDefault();page('circle');};
$('add-person').onclick=()=>{$('pair-panel').hidden=!$('pair-panel').hidden;};
$('unlock-form').onsubmit=async e=>{e.preventDefault();const currentForm=e.currentTarget;const button=$('unlock-submit');button.disabled=true;const data=Object.fromEntries(new FormData(currentForm));const result=await act(state?.exists?'unlock':'create',data);currentForm.elements.passphrase.value='';button.disabled=false;if(result)toast('Your vault is unlocked.');};
form('invite-form','invite',x=>x,result=>{$('my-invite').value=result.invitation;});
$('copy-invite').onclick=async()=>{if(!$('my-invite').value)return;try{await navigator.clipboard.writeText($('my-invite').value);toast('Invitation copied.');}catch{$('my-invite').select();toast('Copy the selected invitation.');}};
form('preview-form','preview',x=>x,result=>{safety=result.safety;$('candidate-name').textContent='Compare with '+result.name;$('safety-number').textContent=safety;$('verify-panel').hidden=false;});
$('confirm-pair').onclick=async()=>{if(await act('pair',{safety})){$('verify-panel').hidden=true;toast('Paired. Ask the other person to complete the same steps.');}};
$('chat-peer').onchange=e=>{selectedPeer=e.target.value;renderChat();};
form('message-form','message',x=>({...x,peer:selectedPeer}),()=>{$('message-text').value='';});
form('fix-form','fix',x=>({...x,source:'manual'}),()=>toast('Manual position set locally.'));
form('waypoint-form','waypoint',x=>x,()=>{$('waypoint-form').reset();toast('Waypoint saved for this session.');});
form('walk-form','walk',x=>x,()=>toast('Check-in timer armed. Keep this computer awake.'));
$('checkin').onclick=()=>act('checkin');
$('sos-form').onsubmit=async e=>{e.preventDefault();if(confirm('Send your latest coordinates to your chosen guardians? This is not an emergency service.'))await act('sos',Object.fromEntries(new FormData(e.currentTarget)));};
function stopDevice(){if(geoWatch!==null){navigator.geolocation.clearWatch(geoWatch);geoWatch=null;}$('device-location').disabled=false;}
$('device-location').onclick=()=>{if(!navigator.geolocation){toast('Location is unavailable in this browser.',true);return;}stopDevice();$('device-location').disabled=true;let last=0;geoWatch=navigator.geolocation.watchPosition(async p=>{if(Date.now()-last<5000)return;last=Date.now();await act('fix',{lat:p.coords.latitude,lon:p.coords.longitude,accuracy:p.coords.accuracy,source:'device'});},e=>{stopDevice();toast(e.message,true);},{enableHighAccuracy:true,maximumAge:10000,timeout:20000});};
$('stop-device').onclick=async()=>{stopDevice();await act('stop_location');};
$('stop-sharing').onclick=()=>act('stop_location');
$('lock').onclick=async()=>{if(confirm('Lock, cancel the check-in timer and close connections? Messages and navigation history will clear.')){stopDevice();await act('lock');}};
$('panic').onclick=async()=>{if(confirm('Revoke every permission you issued and cancel the timer? Offline peers may not hear the revocation until reconnecting.')){stopDevice();await act('panic');}};
document.addEventListener('visibilitychange',()=>{if(document.hidden&&state&&!state.locked){stopDevice();api('stop_location').catch(()=>{});}});
function permission(peer,scope){const titles={message:'Allow incoming messages',location:'Share your location',sos:'Choose a guardian'};const help={message:'This person can send you messages until this permission expires. It does not give them your location.',location:'Your current position is shared while this page is active, for up to 15 minutes. The chosen grid limits detail; device uncertainty can make it coarser.',sos:'This person may receive your position only when you trigger an alert or your running check-in timer does. Ask them to agree before choosing them.'};const f=$('permission-form');f.elements.peer.value=peer;f.elements.scope.value=scope;f.elements.ttl.value='900';for(const opt of f.elements.ttl.options)opt.disabled=scope==='location'&&Number(opt.value)>900;$('precision-label').hidden=scope!=='location';$('permission-title').textContent=titles[scope];$('permission-copy').textContent=help[scope];$('permission-dialog').showModal();}
$('cancel-permission').onclick=()=>$('permission-dialog').close();
form('permission-form','grant',x=>x,()=>{$('permission-dialog').close();toast('Permission issued. The other app must be open to receive it.');});
function btn(text,title,fn){const b=element('button',text);b.type='button';b.title=title;b.onclick=fn;return b;}
let peerSignature='';
function renderPeers(){const list=$('peer-list');if(list.contains(document.activeElement))return;const sig=JSON.stringify([state.peers,state.grants.map(g=>({...g,seconds:Math.ceil(g.seconds/60)})),state.pending_revocations]);if(sig===peerSignature)return;peerSignature=sig;list.replaceChildren();$('peer-count').textContent=state.peers.length;$('grant-count').textContent=state.grants.length;$('pending-revokes').textContent=state.pending_revocations?state.pending_revocations+' revocation(s) awaiting receipt':'';
if(!state.peers.length){const empty=element('div',undefined,'empty');empty.append(element('h3','Your circle starts with one person.'),element('p','Add someone you know. Nothing is shared until you both choose it.'));list.append(empty);}
for(const p of state.peers){const card=element('article',undefined,'peer-card'),head=element('div',undefined,'peer-head'),avatar=element('div',p.name.slice(0,1).toUpperCase(),'avatar'),info=element('div');info.append(element('h3',p.name),element('small',p.route?'Invitation route configured':'Reimport invitation to reconnect'));head.append(avatar,info);card.append(head);const actions=element('div',undefined,'peer-actions');actions.append(btn('Message','Open this conversation',()=>{selectedPeer=p.fp;renderChat();page('chat');}),btn('Allow messages','Let this person send messages for a limited time',()=>permission(p.fp,'message')),btn('Share location','Choose a location permission separately',()=>permission(p.fp,'location')),btn('Choose guardian','Authorize position alerts to this person',()=>permission(p.fp,'sos')));card.append(actions);
if(p.location){const loc=element('div',undefined,'peer-location');loc.append(element('strong','Latest shared position'),element('div',p.location.lat.toFixed(5)+', '+p.location.lon.toFixed(5)),element('div',p.heading||'Set your position to calculate a bearing.'));card.append(loc);}
for(const g of state.grants.filter(g=>g.peer===p.fp)){const row=element('div',undefined,'peer-grant');row.append(element('span',g.scope+' · '+Math.ceil(g.seconds/60)+' min'+(g.precision?' · '+g.precision+' m grid':'')),btn('Revoke','Revoke this permission and retry notification until acknowledged or expired',()=>act('revoke',{id:g.id})));card.append(row);}const remove=btn('Remove person','Revoke permissions and remove this person',async()=>{if(confirm('Remove '+p.name+' and revoke their permissions?'))await act('unpair',{peer:p.fp});});remove.className='subtle';card.append(remove);list.append(card);}}
let chatSignature='';
function renderChat(){if(!state||state.locked)return;const select=$('chat-peer');const signature=state.peers.map(p=>p.fp+p.name).join();if(select.dataset.signature!==signature){select.replaceChildren();if(!state.peers.length)select.append(new Option('Pair with someone first',''));for(const p of state.peers)select.append(new Option(p.name,p.fp));select.dataset.signature=signature;}if(!state.peers.some(p=>p.fp===selectedPeer))selectedPeer=state.peers[0]?.fp||'';select.value=selectedPeer;const peer=state.peers.find(p=>p.fp===selectedPeer);$('send-message').disabled=!peer?.can_message;$('chat-permission').textContent=peer?.can_message?'They have allowed you to send messages.':'Ask the other person to allow messages on your card in their app.';const messages=state.messages.filter(m=>m.peer===selectedPeer);const next=JSON.stringify([selectedPeer,messages]);if(next===chatSignature)return;chatSignature=next;const list=$('messages');list.replaceChildren();if(!messages.length)list.append(element('p','A quiet space. Start with a hello.','hint'));for(const m of messages){const b=element('div',m.text,'bubble'+(m.mine?' mine':''));b.append(element('small',m.mine?({'received':'Received by their app','awaiting_receipt':'Sent · awaiting receipt','unconfirmed':'Unconfirmed · check connection'}[m.status]||m.status):'Received'));list.append(b);}list.scrollTop=list.scrollHeight;}
function renderPlaces(){$('position-readout').textContent=state.own_fix?`${state.own_fix.lat.toFixed(5)}, ${state.own_fix.lon.toFixed(5)} · ${state.fix_source} · ${state.fix_age}s old · reported uncertainty ${state.own_fix.precision_m.toFixed(0)} m`:'No position set. Nothing is being shared.';$('waypoints').replaceChildren();for(const w of state.waypoints){const div=element('div',undefined,'waypoint');div.append(element('strong',w.name),element('span',w.heading));$('waypoints').append(div);}$('trail-count').textContent=state.trail_count+' points';$('backtrack').replaceChildren(...state.backtrack.map(x=>element('li',x)));}
function renderSafety(){const w=state.walk;$('walk-status').textContent=!w?'Not armed':w.done?'Checked in':w.fired?'Alert submitted':w.remaining===0?'Overdue · waiting for fresh position':Math.floor(w.remaining/60)+':'+String(w.remaining%60).padStart(2,'0');$('alerts').replaceChildren();for(const a of state.alerts){const person=state.peers.find(p=>p.fp===a.sender)?.name||'Paired person';const div=element('div',undefined,'alert');div.append(element('strong',person+' · '+a.note),element('div',a.fix.lat.toFixed(5)+', '+a.fix.lon.toFixed(5)),element('small','Reported uncertainty/grid '+a.fix.precision_m+' m'));$('alerts').append(div);}$('sos-receipts').replaceChildren();for(const d of state.deliveries.slice(-5)){const person=state.peers.find(p=>p.fp===d.peer)?.name||'Guardian';$('sos-receipts').append(element('div',person+' · '+(d.status==='received'?'Received by app (not a human response)':'Awaiting receipt; delivery unconfirmed'),'receipt'));}}
async function refresh(){if(pollBusy)return;pollBusy=true;try{const r=await fetch('/api/state',{headers:{'X-Lantern-Token':token,'X-Lantern-Active':document.hidden?'0':'1'}});const data=await r.json();if(!r.ok)throw Error(data.error);state=data;$('welcome').hidden=!state.locked;$('app').hidden=state.locked;if(state.locked){stopDevice();peerSignature='';chatSignature='';selectedPeer='';safety='';for(const id of ['peer-list','messages','alerts','sos-receipts','waypoints','backtrack'])$(id).replaceChildren();$('message-form').reset();$('my-invite').value='';$('preview-form').reset();$('verify-panel').hidden=true;$('permission-dialog').close();$('name-field').hidden=state.exists;$('unlock-title').textContent=state.exists?'Welcome back.':'Make yourself at home.';$('unlock-copy').textContent=state.exists?'Unlock the identity stored on this computer. Your passphrase never leaves this local app.':'Create an encrypted vault for your identity and permissions. Conversations stay in memory.';$('unlock-submit').textContent=state.exists?'Unlock my vault →':'Create my vault →';return;}$('my-name').textContent=state.name;$('avatar').textContent=state.name.slice(0,1).toUpperCase();$('network-info').textContent='UDP '+state.port+' · local interface';$('session-status').textContent=state.status;$('share-banner').hidden=!state.sharing;renderPeers();renderChat();renderPlaces();renderSafety();}catch(e){toast(e.message||'Lantern is unavailable. Check the desktop process.',true);}finally{pollBusy=false;}}
refresh();setInterval(refresh,1500);

// Opt-in explanation mode works with mouse, touch and keyboard-generated clicks.
let explainControls = false;
const helpMode = $('help-mode');
helpMode.onclick = () => {
  explainControls = !explainControls;
  helpMode.setAttribute('aria-pressed', String(explainControls));
  helpMode.textContent = explainControls ? 'Help on · turn off to use controls' : 'Explain controls';
};
$('close-control-help').onclick = () => $('control-help').close();
document.addEventListener('click', event => {
  if (!explainControls || !(event.target instanceof Element)) return;
  const control = event.target.closest('button, input:not([type="hidden"]), select, textarea, summary, a');
  if (!control || control === helpMode || control.closest('#control-help')) return;
  event.preventDefault();
  event.stopImmediatePropagation();
  const label = control.closest('label')?.textContent.trim().split('\n')[0];
  const name = control.getAttribute('aria-label') || label || control.textContent.trim() || control.name || 'This field';
  $('control-help-title').textContent = name.slice(0, 80);
  $('control-help-copy').textContent = control.title || control.getAttribute('placeholder') || 'Enter or choose this value before confirming the form. Nothing is submitted until you confirm.';
  $('control-help').showModal();
}, true);

$('exit-control-help').onclick = () => {
  explainControls = false;
  helpMode.setAttribute('aria-pressed', 'false');
  helpMode.textContent = 'Explain controls';
  $('control-help').close();
};
document.addEventListener('submit', event => {
  if (!explainControls) return;
  event.preventDefault();
  event.stopImmediatePropagation();
  $('control-help-title').textContent = 'Help mode is on';
  $('control-help-copy').textContent = 'Turn help off before submitting this form. Your values have not been sent.';
  $('control-help').showModal();
}, true);
