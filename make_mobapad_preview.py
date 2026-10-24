"""Generate editable, genuinely vector-only M6 HD artwork and its local preview.
All contours and control centers use the approved official front-view coordinates.
No photographs, embedded bitmaps, image filters, or network resources are rendered.
"""
from pathlib import Path
from math import sin,cos,pi
root=Path(__file__).resolve().parent
# Source pixel coordinates are preserved from the approved front crop (275,132).
css='''
:root{--accent:#C87B59;--ink:#77776F;--label:#777368;--shell:#F4F3ED;--edge:#85857D;--button:#ECECE5;--rim:#D9DAD2}
@media(prefers-color-scheme:dark){:root{--accent:#D89370;--label:#B9B2A5}}
svg{overflow:visible}.shell{fill:var(--shell);stroke:var(--edge);stroke-width:1.4;stroke-linejoin:round}.seam{fill:none;stroke:#B8B9B0;stroke-width:1}.rail{fill:#30332F;stroke:#20231F;stroke-width:1}.rim{fill:var(--rim);stroke:#8C8E84;stroke-width:1.3}.surface{fill:var(--button);stroke:#777A6F;stroke-width:1.3}.control.on .surface,.control.on.surface{fill:var(--accent);stroke:var(--accent)}.control.on .glyph{fill:none;stroke:#FFFAF3}.control.on text{fill:#FFFAF3}.rail-key{fill:#55594F;stroke:#82877B;stroke-width:.65}.rail-key.on{fill:var(--accent);stroke:var(--accent)}.rail-label.on{fill:var(--accent);font-weight:700}.dpad-cell{stroke:#C9CBC0;stroke-width:.65}.dpad-cell.on{fill:var(--accent);stroke:var(--accent)}.glyph{fill:none;stroke:#66695E;stroke-width:1.3;stroke-linecap:round;stroke-linejoin:round}text{font-family:-apple-system,BlinkMacSystemFont,sans-serif;fill:var(--ink);text-anchor:middle;dominant-baseline:middle;font-size:15px;font-weight:400}.caption{fill:var(--label);font-size:11px}.ring{fill:none;stroke:var(--label);stroke-width:1;stroke-opacity:.5;stroke-dasharray:2 5}.gravity{fill:none;stroke:var(--accent);stroke-width:1.5;stroke-linejoin:round}.dot{fill:var(--accent)}
'''
parts=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-230 -30 994 470" role="img" aria-label="Mobapad M6 HD 全矢量实时预览"><style>{css}</style>']
parts.append('''<g id="front-shells"><path class="rail" d="M215 34H226V356H220V344H215Z"/><path class="rail" d="M307 34H317V356H313V344H307Z"/>
<path class="shell" d="M215 14L176 16C166 9 156 9 143 13C107 23 77 35 50 51L50 60C38 72 32 86 28 105C21 143 15 189 11 235C7 272 8 302 16 326C24 350 39 367 61 378C96 393 157 397 214 394Z"/>
<path class="shell" d="M317 14L346 16C357 9 367 10 379 14C416 24 450 37 479 52L479 61C493 74 500 92 503 111C510 151 515 195 520 242C525 277 526 305 518 329C511 353 495 370 474 380C441 395 378 399 317 395Z"/>
<path class="seam" d="M210 20V389M322 20V389"/>
</g>''')
# Accurate octagonal stick gates, moving vector caps, and independent click input.
for side,x,y,key in [('left',92,110,'L3'),('right',382,219,'R3')]:
 poly=' '.join(f'{x+cos(pi/8+i*pi/4)*44:.2f},{y+sin(pi/8+i*pi/4)*44:.2f}' for i in range(8))
 parts.append(f'<g id="gate-{side}"><polygon class="rim" points="{poly}"/><circle class="shell" cx="{x}" cy="{y}" r="37"/><circle fill="#C9CCC2" stroke="#92968A" stroke-width="1" cx="{x}" cy="{y}" r="30"/></g><g id="stick-{side}" class="control" data-key="{key}"><circle class="surface" cx="{x}" cy="{y}" r="25"/><circle fill="none" stroke="#FAFAF5" stroke-width="1.4" cx="{x}" cy="{y}" r="21"/></g>')
buttons={'−':(176,61,12),'+':(356,61,12),'X':(432,76,18),'Y':(397,110,18),'A':(466,111,18),'B':(432,145,18)}
for key,(x,y,r) in buttons.items():
 parts.append(f'<g class="control" data-key="{key}"><circle class="surface" cx="{x}" cy="{y}" r="{r}"/><text x="{x}" y="{y+1}" style="font-size:{15 if r==18 else 14}px">{key}</text></g>')
# A single eight-way input lights one cell of the physical 3 x 3 disc.
parts.append('<defs><clipPath id="dpad-disc"><circle cx="145" cy="216" r="50"/></clipPath></defs><circle class="surface" cx="145" cy="216" r="50"/><g clip-path="url(#dpad-disc)">')
cardinals={(0,-1):'↑',(1,0):'→',(0,1):'↓',(-1,0):'←'}
for dy in [-1,0,1]:
 for dx in [-1,0,1]:
  key=f' data-key="{cardinals[(dx,dy)]}"' if (dx,dy) in cardinals else ''
  fill=['#E4E6DD','#F5F5EE','#ECEDE5'][(dx-dy)%3]
  parts.append(f'<rect class="dpad-cell" data-dpad="{dx},{dy}"{key} x="{95+(dx+1)*100/3:.3f}" y="{166+(dy+1)*100/3:.3f}" width="33.334" height="33.334" fill="{fill}"/>')
parts.append('</g>')
parts.append('''<g class="control" data-key="Capture"><rect class="surface" x="160" y="310" width="24" height="24" rx="4"/><path class="glyph" d="M166 316H178V328H166Z"/><circle class="glyph" cx="172" cy="322" r="3.5"/></g><g class="control" data-key="Home"><circle class="surface" cx="360" cy="322" r="12"/><path class="glyph" d="M353 322L360 316L367 322M355 321V328H358V324H362V328H365V321"/></g>''')
for x in [131,402]:
 parts.append(f'<g id="setting-{x}"><circle class="surface" cx="{x}" cy="322" r="12"/><circle class="glyph" cx="{x}" cy="322" r="4"/>')
 for i in range(8):
  a=i*pi/4;parts.append(f'<path class="glyph" d="M{x+cos(a)*5:.2f} {322+sin(a)*5:.2f}L{x+cos(a)*7:.2f} {322+sin(a)*7:.2f}"/>')
 parts.append('</g>')
# The photographed top-view boundary is redrawn as distinct flat vector regions.
outline='M126 546C128 516 154 486 197 468L197 460Q220 454 246 454L419 453Q437 454 449 469V555Q449 563 439 563H416C395 603 372 632 344 657C320 678 291 688 260 688C207 686 166 656 144 619C132 596 126 570 126 546Z'
Rshoulder='M191 531L349 532Q362 532 361 519L360 495Q359 480 346 481L280 482Q217 484 194 512Q190 520 191 531Z'
Rtrigger='M196 543L359 543Q361 597 325 638Q301 668 268 654Q218 638 196 543Z'
Lshoulder='M724 494Q721 482 739 481Q832 478 877 511Q891 522 891 532L737 533Q725 533 724 520Z'
Ltrigger='M725 543L891 543Q872 625 840 648Q815 670 790 650Q751 628 725 543Z'
for side,x,base,shoulder,trigger in [('left',-220,965,Lshoulder,Ltrigger),('right',555,478,Rshoulder,Rtrigger)]:
 key='L' if side=='left' else 'R';cx=815 if side=='left' else 348
 parts.append(f'<g id="top-{side}" transform="translate({x} -30) scale(.55)"><g transform="translate({base} 700) scale(-1 -1)">')
 if side=='left':parts.append(f'<g transform="translate(1080 0) scale(-1 1)"><rect class="rail" x="450" y="487" width="18" height="53" rx="2"/><path class="rim" d="{outline}"/><path class="seam" d="M128 546Q162 528 197 541L359 541Q408 533 449 530"/></g>')
 else:parts.append(f'<rect class="rail" x="450" y="487" width="18" height="53" rx="2"/><path class="rim" d="{outline}"/><path class="seam" d="M128 546Q162 528 197 541L359 541Q408 533 449 530"/>')
 parts.append(f'<g id="top-stick-{side}" class="control" data-key="{"L3" if side=="left" else "R3"}"><rect class="surface" x="{cx-24}" y="421" width="48" height="35" rx="3"/><path fill="#FAFAF5" d="M{cx-9} 422H{cx+9}V451H{cx-9}Z"/><rect class="surface" x="{cx-46}" y="410" width="92" height="12" rx="5"/><ellipse class="surface" cx="{cx}" cy="410" rx="47" ry="12"/></g><path class="control surface" data-key="{key}" d="{shoulder}"/><path class="control surface" data-key="Z{key}" d="{trigger}"/></g><text x="{base-(810 if side=="left" else 278)}" y="188" style="font-size:17px">{key}</text><text x="{base-(810 if side=="left" else 278)}" y="111" style="font-size:17px">Z{key}</text></g>')
for key,x,y,labelx in [('SL-L',216,116,245),('SR-L',216,276,245),('SR-R',306,116,286),('SL-R',306,276,286)]:
 label=key.split('-')[0];side=key[-1]
 parts.append(f'<rect class="rail-key" data-key="{key}" x="{x}" y="{y-14}" width="11" height="28" rx="3"><title>{side} {label}</title></rect>')
 edge=x+11 if side=='L' else x;end=labelx-9 if side=='L' else labelx+9
 parts.append(f'<path d="M{edge} {y}H{end}" stroke="var(--label)" stroke-width=".8" stroke-opacity=".55"/><text class="rail-label caption" data-key="{key}" x="{labelx}" y="{y}">{label}</text>')
for side,x in [('left',-121),('right',654)]:
 label='左摇杆 / 重力方向' if side=='left' else '右摇杆 / 重力方向'
 parts.append(f'<g transform="translate({x} 285)"><circle class="ring" r="61"/><path d="M-61 0H61M0 -61V61" fill="none" stroke="var(--label)" stroke-opacity=".18"/><path id="gravity-{side}" class="gravity"/><circle id="dot-{side}" class="dot" r="3.5"/><text class="caption" y="88">{label}</text></g>')
parts.append('</svg>')
svg=''.join(parts)
assert '<image' not in svg and 'base64' not in svg and '<filter' not in svg
# Resolve CSS custom properties in the standalone file for vector-editor import.
portable=svg
for name,color in {'accent':'#C87B59','ink':'#77776F','label':'#777368','shell':'#F4F3ED','edge':'#85857D','button':'#ECECE5','rim':'#D9DAD2'}.items():
 portable=portable.replace('var(--'+name+')',color)
(root/'Resources/mobapad-m6-hd.svg').write_text(portable)
script='''
const cube=[[-.7,-1,-.5],[-.7,1,-.5],[.7,1,-.5],[.7,-1,-.5],[-.7,-1,.5],[-.7,1,.5],[.7,1,.5],[.7,-1,.5]];
const edges=[[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
const targets=document.querySelectorAll('[data-key]');
const dpadCells=document.querySelectorAll('[data-dpad]');
window.updateController=function(s){
 const pressed=new Set(s.buttons||[]);targets.forEach(n=>n.classList.toggle('on',pressed.has(n.dataset.key)));
 const dx=Number(pressed.has('→'))-Number(pressed.has('←')),dy=Number(pressed.has('↓'))-Number(pressed.has('↑'));
 dpadCells.forEach(n=>n.classList.toggle('on',(dx!==0||dy!==0)&&n.dataset.dpad===`${dx},${dy}`));
 ['left','right'].forEach(side=>{
  const p=s[side]||[0,0];document.getElementById('stick-'+side).setAttribute('transform',`translate(${p[0]*12} ${-p[1]*12})`);
  document.getElementById('top-stick-'+side).setAttribute('transform',`translate(${-p[0]*6} ${p[1]*3}) rotate(${-p[0]*12} ${side==='left'?815:348} 454)`);
  const dot=document.getElementById('dot-'+side);dot.setAttribute('cx',p[0]*61);dot.setAttribute('cy',-p[1]*61);
  const a=(s.acceleration||{})[side==='left'?'L':'R'],node=document.getElementById('gravity-'+side);
  if(!a||Math.hypot(...a)<.5){node.setAttribute('d','');return;}
  const roll=Math.atan2(a[1],a[2]),pitch=Math.atan2(-a[0],Math.hypot(a[1],a[2]));
  const points=cube.map(v=>{const yy=Math.cos(roll)*v[1]-Math.sin(roll)*v[2],zz=Math.sin(roll)*v[1]+Math.cos(roll)*v[2];return[(Math.cos(pitch)*v[0]+Math.sin(pitch)*zz)*27,yy*27];});
  node.setAttribute('d',edges.map(e=>`M${points[e[0]].join(' ')}L${points[e[1]].join(' ')}`).join(''));
 });
};
window.updateController({});
'''
html='''<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'"><style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent}body{position:relative}body>svg{position:absolute;inset:0;width:100%;height:100%;overflow:hidden}</style></head><body>'''+svg+'<script>'+script+'</script></body></html>'
(root/'Resources/mobapad-preview.html').write_text(html)
print('Generated pure-vector M6 HD front, gates, caps, buttons, rails and top views.')
