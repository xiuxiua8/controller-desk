// Regression coverage for real control surfaces and exclusive eight-way cells.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync(new URL('../Resources/mobapad-preview.html','file://'+__filename),'utf8');
const all=[...html.matchAll(/<[a-z][^>]*\bdata-(?:key|dpad)="[^>]+>/g)].map(m=>{
 const key=m[0].match(/data-key="([^"]+)"/)?.[1],dpad=m[0].match(/data-dpad="([^"]+)"/)?.[1];
 const n={dataset:{key,dpad},on:false,classList:{toggle(name,value){this.owner.on=value}}};n.classList.owner=n;return n;
});
const targets=all.filter(n=>n.dataset.key),cells=all.filter(n=>n.dataset.dpad);
const nodes={};for(const m of html.matchAll(/id="([^"]+)"/g))nodes[m[1]]={attrs:{},setAttribute(k,v){this.attrs[k]=v}};
const context={window:{},document:{querySelectorAll:s=>s==='[data-dpad]'?cells:targets,getElementById:id=>{assert.ok(nodes[id],id);return nodes[id]}},Math,Set};
vm.runInNewContext([...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n'),context);
const expected=['A','B','X','Y','−','+','Home','Capture','L3','R3','L','ZL','R','ZR','SL-L','SR-L','SL-R','SR-R','↑','↓','←','→'];
for(const key of expected){assert.ok(targets.some(n=>n.dataset.key===key),'missing highlight: '+key);context.window.updateController({buttons:[key]});assert.ok(targets.filter(n=>n.dataset.key===key).every(n=>n.on),key);assert.ok(targets.filter(n=>n.dataset.key!==key).every(n=>!n.on),'unrelated highlight: '+key)}
assert.equal(cells.length,9);
for(const [buttons,want] of [[['↑'],'0,-1'],[['↑','→'],'1,-1'],[['→'],'1,0'],[['↓','→'],'1,1'],[['↓'],'0,1'],[['↓','←'],'-1,1'],[['←'],'-1,0'],[['↑','←'],'-1,-1']]){
 context.window.updateController({buttons});assert.deepEqual(cells.filter(n=>n.on).map(n=>n.dataset.dpad),[want]);
}
context.window.updateController({buttons:[],left:[1,-1],right:[-.5,.5],acceleration:{L:[0,0,1],R:[.3,.4,.8]}});
assert.equal(nodes['stick-left'].attrs.transform,'translate(12 12)');
assert.equal(nodes['top-stick-left'].attrs.transform,'translate(-6 -3) rotate(-12 815 454)');
assert.equal(nodes['dot-right'].attrs.cx,-30.5);
assert.ok(nodes['gravity-left'].attrs.d.includes('L'));
assert.ok(!nodes['gravity-right'].attrs.d.includes('NaN'));
assert.ok(targets.every(n=>!n.on) && cells.every(n=>!n.on));
context.window.updateController({});assert.equal(nodes['gravity-left'].attrs.d,'');
assert.ok(!/<image\b/.test(html));
console.log('PASS 22 inputs, one exclusive grid cell for all eight directions, immediate release, main/top stick displacement and measured gravity');
