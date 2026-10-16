// Offline guide behavior test. jsdom tests DOM behavior, not visual layout.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require(process.env.LANTERN_JSDOM || 'jsdom');
const web = path.resolve(__dirname, '../src/lantern/web');
const dom = new JSDOM(fs.readFileSync(path.join(web, 'index.html'), 'utf8'), {
  url: 'http://127.0.0.1:1234/#test', runScripts: 'outside-only'
});
const w = dom.window, d = w.document;
let requests = 0, copied = [];
w.fetch = async () => {requests++; return {ok:true, json:async()=>({locked:true,exists:false})};};
w.setInterval = () => 0;
w.HTMLDialogElement.prototype.showModal = function(){this.open=true;};
w.HTMLDialogElement.prototype.close = function(){this.open=false;};
Object.defineProperty(w.navigator, 'clipboard', {value:{writeText:async value=>copied.push(value)}});
w.eval(fs.readFileSync(path.join(web,'app.js'),'utf8'));
const get = id => d.getElementById(id);
const search = value => {get('guide-search').value=value;get('guide-search').dispatchEvent(new w.Event('input'));};
(async()=>{
  await new Promise(resolve=>setImmediate(resolve));
  const baseline=requests;
  get('open-guide').click();assert.equal(get('offline-guide').open,true);
  assert.equal(get('guide-results').children.length,6);
  assert.match(get('offline-guide').textContent,/not AI/);
  assert.match(get('offline-guide').textContent,/not configured/);
  search('firewall');assert.match(get('guide-results').textContent,/Do not disable/);
  search('staff');assert.equal(get('guide-results').children.length,1);
  assert.equal(copied.length,0); // Opening/searching never touches clipboard.
  get('guide-results').querySelector('button').click();await Promise.resolve();
  assert.equal(copied.length,1);assert.match(copied[0],/Task: \[what needs doing\]/);
  assert.equal(get('message-text').value,''); // No automatic composition or sending.
  search('guardian');assert.match(get('guide-results').textContent,/no alert is sent until/);
  search('<img src=x onerror=alert(1)>');assert.match(get('guide-count').textContent,/No matching/);
  assert.equal(get('guide-results').children.length,0);
  get('close-guide').click();assert.equal(get('offline-guide').open,false);
  get('help-mode').click();get('open-guide').click();
  assert.equal(get('offline-guide').open,false);assert.equal(get('control-help').open,true);
  get('exit-control-help').click();get('open-guide').click();search('staff');
  get('help-mode').click();get('guide-results').querySelector('button').click();
  await Promise.resolve();assert.equal(copied.length,1); // Help preserves no-action behavior.
  assert.equal(requests,baseline); // Guide performs no API or network requests.
  console.log('Offline guide: search, fixed guidance, explicit copy, no composition/network/actions, empty results and help interception passed.');
})().catch(error=>{console.error(error);process.exitCode=1;}).finally(()=>w.close());
