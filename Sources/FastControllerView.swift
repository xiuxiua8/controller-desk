// SPDX-FileCopyrightText: Copyright 2020 yuzu Emulator Project
// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted 2026-10-23: direct CoreGraphics port of PlayerControlPreview.
// This NSView redraws independently from SwiftUI layout.
import AppKit
import SwiftUI

private struct NativeShade {
    var value:Color
    static func color(_ value:Color)->Self { Self(value:value) }
}
private struct NativePainter {
    let cg:CGContext
    func translateBy(x:CGFloat,y:CGFloat) { cg.translateBy(x:x,y:y) }
    func scaleBy(x:CGFloat,y:CGFloat) { cg.scaleBy(x:x,y:y) }
    func fill(_ p:Path,with shade:NativeShade,style:FillStyle=FillStyle()) {
        cg.setFillColor(NSColor(shade.value).cgColor);cg.addPath(p.cgPath);cg.drawPath(using:style.isEOFilled ? .eoFill:.fill)
    }
    func stroke(_ p:Path,with shade:NativeShade,lineWidth:CGFloat) {
        cg.saveGState();cg.setStrokeColor(NSColor(shade.value).cgColor);cg.setLineWidth(lineWidth);cg.addPath(p.cgPath);cg.strokePath();cg.restoreGState()
    }
    func stroke(_ p:Path,with shade:NativeShade,style:StrokeStyle) {
        cg.saveGState();cg.setStrokeColor(NSColor(shade.value).cgColor);cg.setLineWidth(style.lineWidth);cg.setLineDash(phase:style.dashPhase,lengths:style.dash);cg.addPath(p.cgPath);cg.strokePath();cg.restoreGState()
    }
    func drawLabel(_ value:String,at point:CGPoint) {
        let text=NSAttributedString(string:value,attributes:[.font:NSFont.systemFont(ofSize:9),.foregroundColor:NSColor.secondaryLabelColor])
        let s=text.size();text.draw(at:CGPoint(x:point.x-s.width/2,y:point.y-s.height/2))
    }
}
final class FastControllerView:NSView {
    var provider:()->InputState={InputState()}
    var kind="joycon"
    static weak var current:FastControllerView?
    private var timer:Timer?
    private var lastFrame=0.0
    private var intervals:[Double]=[]
    override var isFlipped:Bool { true }
    override init(frame:NSRect) {
        super.init(frame:frame)
        wantsLayer=true
        Self.current=self
        timer=Timer(timeInterval:1.0/60,repeats:true) { [weak self] _ in MainActor.assumeIsolated { self?.needsDisplay=true } }
        RunLoop.main.add(timer!,forMode:.common)
        setAccessibilityElement(true);setAccessibilityLabel("Joy-Con 实时预览，60 Hz 绘制")
    }
    required init?(coder:NSCoder) { nil }
    deinit { timer?.invalidate() }
    override func draw(_ dirtyRect:NSRect) {
        guard let cg=NSGraphicsContext.current?.cgContext else { return }
        cg.clear(bounds)
        let now=ProcessInfo.processInfo.systemUptime
        if lastFrame>0 { intervals.append(now-lastFrame);if intervals.count>180 { intervals.removeFirst(intervals.count-180) } }
        lastFrame=now
        let input=provider(),size=bounds.size
        let scheme:ColorScheme=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? .dark:.light
        let context=NativePainter(cg:cg)
        cg.saveGState();defer { cg.restoreGState() }
            let scale=min(size.width/530,size.height/310)
            context.translateBy(x:size.width/2,y:size.height/2)
            context.scaleBy(x:scale,y:scale)
            let outline=scheme == .dark ? Color(white:0.65):Color(white:0.18)
            let gray=Color(red:103/255,green:106/255,blue:110/255)
            let defaultButton=scheme == .dark ? Color(white:0.14):Color(white:0.32)
            let left=input.bodyColors["L"].map(rgbColor) ?? Color(white:0.65)
            let right=input.bodyColors["R"].map(rgbColor) ?? Color(white:0.65)
            func buttonColor(_ name:String,_ side:String) -> Color {
                if input.buttons.contains(name) { return Palette.accent }
                return input.buttonColors[side].map(rgbColor) ?? defaultButton
            }
            func path(_ name:String,_ sx:Double=1,_ sy:Double=1,_ tx:Double=0,_ ty:Double=0,_ rotate:Double=0) -> Path {
                let values=YuzuVectors.arrays[name] ?? []
                var p=Path()
                for i in stride(from:0,to:values.count,by:2) {
                    let x=values[i]*sx,y=values[i+1]*sy
                    let point=CGPoint(x:x*cos(rotate)-y*sin(rotate)+tx,y:x*sin(rotate)+y*cos(rotate)+ty)
                    if i==0 { p.move(to:point) } else { p.addLine(to:point) }
                }
                p.closeSubpath(); return p
            }
            func paint(_ p:Path,_ fill:Color,_ stroke:Bool=true) {
                context.fill(p,with:.color(fill),style:FillStyle(eoFill:true))
                if stroke { context.stroke(p,with:.color(outline),lineWidth:0.75) }
            }
            func polygon(_ name:String,_ sx:Double=1,_ sy:Double=1,_ tx:Double=0,_ ty:Double=0,_ fill:Color,_ rotate:Double=0) {
                paint(path(name,sx,sy,tx,ty,rotate),fill)
            }
            func line(_ x:Double,_ y:Double,_ xx:Double,_ yy:Double,_ color:Color?=nil) {
                var p=Path(); p.move(to:CGPoint(x:x,y:y)); p.addLine(to:CGPoint(x:xx,y:yy))
                context.stroke(p,with:.color(color ?? outline),lineWidth:0.75)
            }
            func round(_ name:String,_ side:String,_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ radius:Double=2) {
                paint(Path(roundedRect:CGRect(x:x-w,y:y-h,width:w*2,height:h*2),cornerRadius:radius),buttonColor(name,side))
            }
            func circle(_ name:String,_ side:String,_ x:Double,_ y:Double,_ r:Double) {
                paint(Path(ellipseIn:CGRect(x:x-r,y:y-r,width:r*2,height:r*2)),buttonColor(name,side))
            }
            func symbol(_ name:String,_ x:Double,_ y:Double,_ scale:Double=1,_ shiftY:Double=0) {
                paint(path(name,scale,scale,x,y+shiftY),Color.white,false)
            }
            func stick(_ side:String,_ x:Double,_ y:Double,_ point:CGPoint) {
                let name=side=="L" ? "L3":"R3",xx=x+point.x*7,yy=y-point.y*7
                circle(name,side,xx,yy,13*1.62)
                line(xx-13*1.62,yy,xx+13*1.62,yy); line(xx,yy-13*1.62,xx,yy+13*1.62)
                paint(Path(ellipseIn:CGRect(x:xx-9*1.62,y:yy-9*1.62,width:18*1.62,height:18*1.62)),input.buttons.contains(name) ? Palette.accent.opacity(0.8):Color(white:0.1))
            }
            // Original Yuzu trigger transforms and top/side-view button locations.
            polygon("left_joycon_trigger",1.62,1.62,210.6,input.buttons.contains("L") ? 0.5:0,buttonColor("L","L"))
            polygon("left_joycon_trigger",-1.62,1.62,-210.6,input.buttons.contains("R") ? 0.5:0,buttonColor("R","R"))
            polygon("left_joystick_sideview",1,1,180,-79,buttonColor("R3","R"),(-input.right.x+15)*18 * .pi/180)
            for (key,x) in [("A",200.0),("B",180.0),("X",180.0),("Y",160.0)] { round(key,"R",x,-71,10,5) }
            round("+","R",154,-72,7,4,1); round("+","R",154,-72,2.33,4,1)
            round("←","L",-200,-71,10,5); round("→","L",-160,-71,10,5)
            polygon("left_joystick_sideview",1,1,-180.5,-79,buttonColor("L3","L"),(-input.left.x+15)*18 * .pi/180)
            round("−","L",-154,-72,7,4,1)
            round("SL-L","L",-20,-62,4,11); round("SR-L","L",-20,47,4,11)
            round("SL-R","R",20,47,4,11); round("SR-R","R",20,-62,4,11)
            // Original DrawDualBody: unchanged source vertices and transforms.
            polygon("left_joycon_body",-1.61,1.61,-209.3,-1,right)
            polygon("left_joycon_body",1.61,1.61,209.3,-1,left)
            paint(Path(roundedRect:CGRect(x:-155,y:-113.5,width:12,height:11),cornerRadius:2),defaultButton)
            paint(Path(roundedRect:CGRect(x:143,y:-113.5,width:12,height:11),cornerRadius:2),defaultButton)
            polygon("left_joycon_slider_topview",0.9,0.9,-52,-52,gray)
            polygon("left_joycon_slider_topview",-0.9,0.9,52,-52,gray)
            line(-133.8,-99,-133.8,-78.5); line(133.8,-99,133.8,-78.5)
            polygon("left_joycon_topview",0.9,0.9,-52,-52,left)
            polygon("left_joycon_topview",-0.9,0.9,52,-52,right)
            polygon("left_joycon_slider",-1,1,0,0,gray)
            polygon("left_joycon_slider",1,1,0,0,gray)
            polygon("left_joystick_L_topview",0.9,0.9,-50,-52,buttonColor("L","L"))
            polygon("left_joystick_L_topview",-0.9,0.9,50,-52,buttonColor("R","R"))
            symbol("symbol_l",-183,-84,1,-1); symbol("symbol_r",177,-84,1,-1)
            polygon("left_joystick_ZL_topview",0.9,0.9,-52,-52,buttonColor("ZL","L"))
            polygon("left_joystick_ZL_topview",-0.9,0.9,52,-52,buttonColor("ZR","R"))
            symbol("symbol_zl",-180,-113); symbol("symbol_zr",180,-113)
            stick("L",-65,-65,input.left); stick("R",65,12,input.right)
            for (name,x,y) in [("A",85.0,-65.0),("B",65.0,-45.0),("X",65.0,-85.0),("Y",45.0,-65.0)] {
                circle(name,"R",x,y,10); symbol("symbol_"+name.lowercased(),x,y)
            }
            for (name,x,y) in [("→",-45.0,12.0),("↓",-65.0,32.0),("↑",-65.0,-8.0),("←",-85.0,12.0)] {
                circle(name,"L",x,y,10)
                let rotation=name=="↑" ? 0.0:name=="→" ? Double.pi/2:name=="↓" ? Double.pi : -Double.pi/2
                paint(path("up_arrow_symbol",1.1,1.1,x,y,rotation),.white,false)
            }
            round("−","L",-39,-106,7,14/6,0)
            round("+","R",39,-106,7,14/6,0); round("+","R",39,-106,14/6,7,0)
            round("Capture","L",-52,63,8,8)
            paint(Path(ellipseIn:CGRect(x:-57,y:58,width:10,height:10)),Color(white:0.7))
            circle("Home","R",50,60,11); circle("Home","R",50,60,8.5)
            symbol("house",50,60,4.2,-0.025*4.2)
            // Yuzu raw-stick indicator locations. Motion cube uses measured gravity tilt.
            for side in ["L","R"] {
                let x:Double=side=="L" ? -180:180,y=90.0
                let point=side=="L" ? input.left:input.right
                let ring=Path(ellipseIn:CGRect(x:x-45,y:y-45,width:90,height:90))
                context.stroke(ring,with:.color(outline.opacity(0.7)),style:StrokeStyle(lineWidth:0.75,dash:[1,3]))
                paint(Path(ellipseIn:CGRect(x:x+point.x*45-2,y:y-point.y*45-2,width:4,height:4)),Palette.accent,false)
                if let acc=input.sideAcceleration[side],acc.magnitude>0.5 {
                    let a=atan2(acc.y,acc.z),b=atan2(-acc.x,sqrt(acc.y*acc.y+acc.z*acc.z))
                    let cube:[Vector3]=[.init([-0.7,-1,-0.5]),.init([-0.7,1,-0.5]),.init([0.7,1,-0.5]),.init([0.7,-1,-0.5]),.init([-0.7,-1,0.5]),.init([-0.7,1,0.5]),.init([0.7,1,0.5]),.init([0.7,-1,0.5])]
                    let projected=cube.map { v -> CGPoint in
                        let yy=cos(a)*v.y-sin(a)*v.z,zz=sin(a)*v.y+cos(a)*v.z
                        return CGPoint(x:x+(cos(b)*v.x+sin(b)*zz)*20,y:y+yy*20)
                    }
                    for edge in [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)] {
                        let p=projected[edge.0],q=projected[edge.1]; line(p.x,p.y,q.x,q.y,Palette.accent.opacity(0.65))
                    }
                }
                context.drawLabel(side=="L" ? "左摇杆 / 重力方向":"右摇杆 / 重力方向",at:CGPoint(x:x,y:145))
            }
    }
    func diagnostics()->[String:Double] {
        let sorted=intervals.sorted();guard !sorted.isEmpty else { return [:] }
        let median=sorted[sorted.count/2]
        return ["measuredFPS":1/median,"medianFrameMs":median*1000,"p95FrameMs":sorted[Int(Double(sorted.count-1)*0.95)]*1000]
    }

}
struct FastYuzuPreview:NSViewRepresentable {
    var provider:()->InputState
    var kind="joycon"
    func makeNSView(context:Context)->FastControllerView { let v=FastControllerView(frame:.zero);v.provider=provider;v.kind=kind;return v }
    func updateNSView(_ v:FastControllerView,context:Context) { v.provider=provider;v.kind=kind }
}
