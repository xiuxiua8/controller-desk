"""Build a local live preview from Al. Lopez's MIT-licensed Xbox Series artwork.
The upstream SVG remains unchanged in Vendor. Output is generated; do not edit it.
"""
from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent
tree=ET.fromstring((root/'Vendor/GamepadAssetPack/Xbox-Series-X-Black.svg').read_text())
label='{http://www.inkscape.org/namespaces/inkscape}label'
for element in tree.iter():
    value=element.get(label)
    if value: element.set('data-label',value)
    for key in list(element.attrib):
        if 'inkscape.org' in key or 'sodipodi' in key: del element.attrib[key]
for parent in list(tree.iter()):
    for element in list(parent):
        if not element.tag.startswith('{http://www.w3.org/2000/svg}'):
            parent.remove(element)
ET.register_namespace('', 'http://www.w3.org/2000/svg')
svg=ET.tostring(tree,encoding='unicode')
assert '<image' not in svg and '<script' not in svg
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:">
<style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent}body{display:flex;align-items:center;justify-content:center}svg{width:96%;height:96%;overflow:visible}.pressed{filter:drop-shadow(0 0 8px #C87B5966)}</style>
<body>'''+svg+'''
<script>
// Artwork: Copyright (c) 2024 Al. Lopez, MIT. Native macOS input supplies all values.
const svg=document.querySelector('svg');
svg.setAttribute('role','img');svg.setAttribute('aria-label','Xbox Series 手柄实时预览');
const find=name=>[...svg.querySelectorAll('[data-label]')].find(e=>e.getAttribute('data-label')===name);
const map={A:'A Button',B:'B Button',X:'X Button',Y:'Y Button',Home:'Xbox Guide Button',Capture:'Share Button','−':'View Button','+':'Menu Button',L3:'Left Stick',R3:'Right Stick',ZL:'Left Trigger',ZR:'Right Trigger'};
const nodes=Object.fromEntries(Object.entries(map).map(([k,n])=>[k,find(n)]));
const originals=new Map();
for(const [key,node] of Object.entries(nodes)) {
 if(!node)continue;
 const fills=[...node.querySelectorAll('[data-label]')].filter(e=>/^Color/.test(e.getAttribute('data-label')));
 if(!fills.length)fills.push(node);
 originals.set(node,fills.map(e=>[e,e.style.fill,e.style.fillOpacity]));
}
const stickWrappers={};
for(const key of ['L3','R3']) {
 const node=nodes[key];if(!node)continue;
 const wrapper=document.createElementNS(svg.namespaceURI,'g');node.parentNode.insertBefore(wrapper,node);wrapper.append(node);stickWrappers[key]=wrapper;
}
function highlight(node,on,amount=1) {
 if(!node)return;
 node.classList.toggle('pressed',on);
 for(const [element,fill,opacity] of originals.get(node)||[]) {
  element.style.fill=on ? '#C87B59':fill;
  element.style.fillOpacity=on ? Math.max(.3,amount):opacity;
 }
}
// Highlight copies of the original shoulder surface, clipped at its physical seams.
// These are real curved upstream paths, not visible rectangular markers.
const ns=svg.namespaceURI;
function element(name,attrs={}) {const n=document.createElementNS(ns,name);for(const [k,v] of Object.entries(attrs))n.setAttribute(k,v);return n;}
const defs=element('defs');svg.append(defs);
const shoulderNodes={};
const bumpers=find('Bumpers');
if(bumpers){
 const surface=bumpers.querySelector('#rect35488');
 if(surface){
  const b=surface.getBBox();
  for(const [key,x,width] of [['L',b.x-1,1550.3-b.x+1],['R',1994.3,b.x+b.width-1994.3+1]]){
   const clip=element('clipPath',{id:'bumper-clip-'+key,clipPathUnits:'userSpaceOnUse'});clip.append(element('rect',{x,y:b.y-1,width,height:b.height+2}));defs.append(clip);
   const n=surface.cloneNode(true);n.removeAttribute('id');n.setAttribute('data-key',key);n.setAttribute('data-highlight-kind','original-shoulder-path');n.setAttribute('clip-path','url(#bumper-clip-'+key+')');n.style.fill='#C87B59';n.style.fillOpacity='1';n.style.opacity='0';n.style.pointerEvents='none';
   bumpers.append(n);shoulderNodes[key]=n;
  }
 }
}
// Each active direction selects one full tile in the actual nine-part D-pad bowl.
const dpadCells=[];
const dpad=find('Xbox Series Controller D-PAD');
if(dpad){
 const face=find('Secondary D-PAD')?.querySelector('[data-label="Color"]');
 if(face){
  const m=dpad.getCTM().inverse().multiply(face.getCTM()),b=face.getBBox();
  const a=new DOMPoint(b.x,b.y).matrixTransform(m),z=new DOMPoint(b.x+b.width,b.y+b.height).matrixTransform(m);
  const x=Math.min(a.x,z.x),y=Math.min(a.y,z.y),w=Math.abs(z.x-a.x),h=Math.abs(z.y-a.y);
  const clip=element('clipPath',{id:'dpad-face-clip',clipPathUnits:'userSpaceOnUse'}),shape=face.cloneNode(true);shape.removeAttribute('id');shape.removeAttribute('style');shape.setAttribute('fill','#000');shape.setAttribute('transform',`matrix(${m.a} ${m.b} ${m.c} ${m.d} ${m.e} ${m.f})`);clip.append(shape);defs.append(clip);
  const layer=element('g',{'clip-path':'url(#dpad-face-clip)','data-highlight-kind':'nine-cell-dpad'});dpad.append(layer);
  const xs=[x,x+w*.345,x+w*.655,x+w],ys=[y,y+h*.338,y+h*.645,y+h];
  for(let row=0;row<3;row++)for(let col=0;col<3;col++){
   const cell=element('rect',{x:xs[col],y:ys[row],width:xs[col+1]-xs[col],height:ys[row+1]-ys[row],fill:'#C87B59',opacity:0,'data-dpad':`${col-1},${row-1}`});layer.append(cell);dpadCells.push(cell);
  }
 }
}
window.updateController=s=>{
 const pressed=new Set(s.buttons);
 for(const [key,node] of Object.entries(nodes))highlight(node,key==='ZL'?s.lt>.01:key==='ZR'?s.rt>.01:pressed.has(key),key==='ZL'?s.lt:key==='ZR'?s.rt:1);
 for(const [key,node] of Object.entries(shoulderNodes))node.style.opacity=pressed.has(key)?'1':'0';
 const dx=Number(pressed.has('→'))-Number(pressed.has('←')),dy=Number(pressed.has('↓'))-Number(pressed.has('↑'));
 for(const node of dpadCells)node.setAttribute('opacity',(dx!==0||dy!==0)&&node.getAttribute('data-dpad')===`${dx},${dy}` ? 0.8 : 0);
 if(stickWrappers.L3)stickWrappers.L3.setAttribute('transform',`translate(${s.left[0]*28},${-s.left[1]*28})`);
 if(stickWrappers.R3)stickWrappers.R3.setAttribute('transform',`translate(${s.right[0]*28},${-s.right[1]*28})`);
 svg.setAttribute('aria-label','Xbox Series 手柄实时预览。按下：'+(s.buttons.join('、')||'无'));
};
</script></body></html>'''
(root/'Resources/xbox-preview.html').write_text(html)
print('Generated local Xbox Series SVG live preview.')
