import AppKit
import SwiftUI

final class LivePlotView:NSView {
    var point:()->CGPoint={.zero}
    var history:()->[Vector3]={[]}
    var motion=false
    private var timer:Timer?
    override var isFlipped:Bool { true }
    override init(frame:NSRect) {
        super.init(frame:frame);wantsLayer=true
        timer=Timer(timeInterval:1.0/60,repeats:true) { [weak self] _ in MainActor.assumeIsolated { self?.needsDisplay=true } }
        RunLoop.main.add(timer!,forMode:.common)
    }
    required init?(coder:NSCoder) { nil }
    deinit { timer?.invalidate() }
    override func draw(_ dirtyRect:NSRect) {
        guard let c=NSGraphicsContext.current?.cgContext else { return }
        c.clear(bounds)
        let ink=NSColor.secondaryLabelColor,teal=NSColor(Palette.accent)
        if !motion {
            let r=min(bounds.width,bounds.height)/2-3,center=CGPoint(x:bounds.midX,y:bounds.midY),p=point()
            let box=CGRect(x:center.x-r,y:center.y-r,width:2*r,height:2*r)
            c.setFillColor(NSColor.windowBackgroundColor.cgColor);c.fillEllipse(in:box)
            c.setStrokeColor(ink.withAlphaComponent(0.3).cgColor);c.setLineWidth(1);c.strokeEllipse(in:box)
            c.setLineDash(phase:0,lengths:[3,3]);c.move(to:CGPoint(x:center.x-r,y:center.y));c.addLine(to:CGPoint(x:center.x+r,y:center.y));c.move(to:CGPoint(x:center.x,y:center.y-r));c.addLine(to:CGPoint(x:center.x,y:center.y+r));c.strokePath();c.setLineDash(phase:0,lengths:[])
            let dot=CGPoint(x:center.x+p.x*r,y:center.y-p.y*r)
            c.setStrokeColor(teal.withAlphaComponent(0.5).cgColor);c.move(to:center);c.addLine(to:dot);c.strokePath()
            c.setFillColor(teal.cgColor);c.fillEllipse(in:CGRect(x:dot.x-4,y:dot.y-4,width:8,height:8))
            return
        }
        let samples=history(),maxValue=max(5,samples.flatMap(\.values).map(abs).max() ?? 5)
        let height=bounds.height-20,left=40.0,width=bounds.width-left
        c.setStrokeColor(ink.withAlphaComponent(0.2).cgColor);c.setLineWidth(0.7)
        for i in 0...4 {
            let y=CGFloat(i)*height/4+8;c.move(to:CGPoint(x:left,y:y));c.addLine(to:CGPoint(x:bounds.width,y:y));c.strokePath()
        }
        for (text,y) in [(String(format:"+%.0f",maxValue),2.0),("0",height/2),(String(format:"-%.0f",maxValue),height-2)] {
            NSAttributedString(string:text,attributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:9,weight:.regular),.foregroundColor:ink]).draw(at:CGPoint(x:0,y:y))
        }
        let colors=[teal,NSColor.systemOrange,NSColor.systemIndigo]
        for axis in 0..<3 {
            c.setStrokeColor(colors[axis].cgColor);c.setLineWidth(1.7)
            for (i,value) in samples.enumerated() {
                let p=CGPoint(x:left+width*Double(i)/359,y:8+height/2-value.values[axis]/maxValue*height/2)
                if i==0 { c.move(to:p) } else { c.addLine(to:p) }
            }
            c.strokePath()
        }
    }
}
struct LiveStickScope:NSViewRepresentable {
    let provider:()->CGPoint
    func makeNSView(context:Context)->LivePlotView { let v=LivePlotView(frame:.zero);v.point=provider;return v }
    func updateNSView(_ v:LivePlotView,context:Context) { v.point=provider }
}
struct LiveMotionScope:NSViewRepresentable {
    let provider:()->[Vector3]
    func makeNSView(context:Context)->LivePlotView { let v=LivePlotView(frame:.zero);v.motion=true;v.history=provider;return v }
    func updateNSView(_ v:LivePlotView,context:Context) { v.history=provider }
}
