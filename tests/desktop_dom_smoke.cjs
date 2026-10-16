const {JSDOM,VirtualConsole}=require(process.env.LANTERN_JSDOM || 'jsdom');
const {spawn}=require('child_process');const fs=require('fs');const os=require('os');const path=require('path');
const repo=path.resolve(__dirname,'..');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'lantern-dom-'));const children=[];const windows=[];
function launch(name){return new Promise((resolve,reject)=>{const p=spawn(process.env.LANTERN_PYTHON || 'python3',['-m','lantern','app','--no-browser','--data-dir',path.join(root,name)],{cwd:repo,env:{...process.env,PYTHONPATH:path.join(repo,'src')}});children.push(p);let log='';p.stdout.on('data',d=>{log+=d;const m=log.match(/http:\/\/127\.0\.0\.1:\d+\/#[A-Za-z0-9_-]+/);if(m)resolve(m[0]);});p.stderr.on('data',d=>{if(d.toString().includes('Traceback'))reject(Error(d.toString()));});});}
const pause=ms=>new Promise(r=>setTimeout(r,ms));async function until(fn,label){for(let i=0;i<200;i++){if(await fn())return;await pause(25);}throw Error('Timeout: '+label);}
async function request(url,cmd,data){const u=new URL(url);const r=await fetch(u.origin+'/api/'+cmd,{method:data?'POST':'GET',headers:{'X-Lantern-Token':u.hash.slice(1),'Content-Type':'application/json'},...(data?{body:JSON.stringify(data)}:{})});const b=await r.json();if(!r.ok)throw Error(b.error);return b;}
(async()=>{const [url,burl]=await Promise.all([launch('Alice'),launch('Bob')]);const errors=[];const vc=new VirtualConsole();vc.on('jsdomError',e=>errors.push(e.message));const dom=await JSDOM.fromURL(url,{resources:'usable',runScripts:'dangerously',pretendToBeVisual:true,virtualConsole:vc,beforeParse(w){w.fetch=(u,opts)=>fetch(new URL(u,w.location.href),opts);w.confirm=()=>true;w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};w.HTMLDialogElement.prototype.close=function(){this.open=false;};}});windows.push(dom.window);const d=dom.window.document;
await until(()=>d.readyState==='complete' && typeof d.getElementById('unlock-form').onsubmit==='function','onboarding');await pause(200);
d.querySelector('[name=name]').value='Alice';d.querySelector('[name=passphrase]').value='a sufficiently long passphrase';d.getElementById('unlock-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
try{await until(()=>!d.getElementById('app').hidden,'unlock app');}catch(e){console.log('UI errors',errors,'toast',d.getElementById('toast').textContent,'ready',d.readyState,'button',d.getElementById('unlock-submit').textContent);throw e;}
await request(burl,'create',{name:'Bob',passphrase:'a sufficiently long passphrase'});
const ai=(await request(url,'invite',{host:'127.0.0.1'})).invitation,bi=(await request(burl,'invite',{host:'127.0.0.1'})).invitation;
const bp=await request(burl,'preview',{invitation:ai});await request(burl,'pair',{safety:bp.safety});
d.getElementById('add-person').click();d.querySelector('#preview-form textarea').value=bi;d.getElementById('preview-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));await until(()=>!d.getElementById('verify-panel').hidden,'safety preview');if(d.getElementById('safety-number').textContent!==bp.safety)throw Error('Safety mismatch');d.getElementById('confirm-pair').click();await until(()=>d.getElementById('peer-count').textContent==='1','paired card');
const ast=await request(url,'state'),bst=await request(burl,'state');await request(burl,'grant',{peer:ast.fp,scope:'message',ttl:900});await until(async()=> (await request(url,'state')).peers[0].can_message,'grant arrives');
d.querySelector('[data-page=chat]').click();await until(()=>!d.getElementById('send-message').disabled,'send enabled');d.getElementById('message-text').value='UI-to-UDP message';d.getElementById('message-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));await until(async()=> (await request(burl,'state')).messages.some(m=>m.text==='UI-to-UDP message'),'real UDP received');await until(()=>d.getElementById('messages').textContent.includes('Received by their app'),'UI receipt');
d.querySelector('[data-page=places]').click();const fix=d.getElementById('fix-form');fix.elements.lat.value='38.7';fix.elements.lon.value='-9.1';fix.dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));await until(()=>d.getElementById('position-readout').textContent.includes('manual'),'manual fix');

// Help must not perform the selected action or submit a form.
d.getElementById('help-mode').click();d.getElementById('lock').click();
if(!d.getElementById('control-help').open)throw Error('Help dialog missing');
if((await request(url,'state')).locked)throw Error('Help executed lock');
d.getElementById('close-control-help').click();
d.getElementById('fix-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
if(!d.getElementById('control-help-copy').textContent.includes('not been sent'))throw Error('Help allowed submit');
d.getElementById('exit-control-help').click();
// Real subprocess, HTTP API and UDP consent/location/expiry checks.
await request(url,'grant',{peer:bst.fp,scope:'location',ttl:30,precision:100});
await until(async()=> (await request(burl,'state')).peers[0].location!==null,'location arrives');
await request(url,'stop_location',{});
await until(async()=> (await request(burl,'state')).peers[0].location===null,'location revoked');
await request(url,'message',{peer:bst.fp,text:'expires-in-one-second',ttl:1});
await until(async()=> (await request(burl,'state')).messages.some(m=>m.text==='expires-in-one-second'),'expiring message arrives');
await until(async()=> !(await request(burl,'state')).messages.some(m=>m.text==='expires-in-one-second'),'receiver message expires');
await until(async()=> !(await request(url,'state')).messages.some(m=>m.text==='expires-in-one-second'),'sender message expires');
const u=new URL(url);for(const headers of [{},{'X-Lantern-Token':'wrong'},{'X-Lantern-Token':u.hash.slice(1),Origin:'https://evil.example'}]){const r=await fetch(u.origin+'/api/state',{headers});if(r.status!==403)throw Error('Bad authorization accepted');}
d.getElementById('lock').click();await until(()=>!d.getElementById('welcome').hidden,'locked');
await request(url,'unlock',{passphrase:'a sufficiently long passphrase'});
const resumed=await request(url,'state');if(resumed.fp!==ast.fp||resumed.messages.length||resumed.peers.some(p=>p.route)||resumed.sharing)throw Error('Unlock restored private transient state');
let wrongRejected=false;await request(url,'lock',{});try{await request(url,'unlock',{passphrase:'incorrect sufficiently long passphrase'});}catch{wrongRejected=true;}if(!wrongRejected)throw Error('Wrong password accepted');
if(errors.length)throw Error(errors.join('\n'));console.log('EXTENDED DOM/HTTP/UDP integration passed: help prevents click/submission, location grant/revocation, message expiry both ends, HTTP authorization, identity persistence with transient clearing, wrong passphrase rejection; vault onboarding, signed pairing, safety number, real UDP message, receipt UI, manual position, lock.');
})().then(()=>process.exitCode=0).catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>{windows.forEach(w=>w.close());children.forEach(p=>p.kill('SIGINT'));fs.rmSync(root,{recursive:true,force:true});});
