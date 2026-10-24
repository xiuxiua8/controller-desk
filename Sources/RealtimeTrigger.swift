import AppKit
import SwiftUI

// Reads the current input on each display tick. No NSProgressIndicator or animation.
final class TriggerMeterView:NSView {
    var provider:()->Double={0}
    var title="ZL"
    private var timer:Timer?
    private var accessibilitySnapshot=""
    override var isFlipped:Bool { true }
    override init(frame:NSRect) {
        super.init(frame:frame);wantsLayer=true
        layer?.actions=["contents":NSNull(),"bounds":NSNull(),"position":NSNull()]
        timer=Timer(timeInterval:1.0/60,repeats:true) { [weak self] _ in MainActor.assumeIsolated { self?.needsDisplay=true } }
        RunLoop.main.add(timer!,forMode:.common)
        setAccessibilityElement(true);setAccessibilityRole(.levelIndicator)
    }
    required init?(coder:NSCoder) { nil }
    deinit { timer?.invalidate() }
    override func draw(_ dirtyRect:NSRect) {
        guard let c=NSGraphicsContext.current?.cgContext else { return }
        c.clear(bounds)
        let raw=provider(),value=raw.isFinite ? min(1,max(0,raw)):0
        let label=NSAttributedString(string:title,attributes:[.font:NSFont.systemFont(ofSize:13,weight:.medium),.foregroundColor:NSColor.labelColor])
        label.draw(at:CGPoint(x:0,y:0))
        let number=NSAttributedString(string:String(format:"%.0f%%",value*100),attributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:13,weight:.medium),.foregroundColor:NSColor.secondaryLabelColor])
        number.draw(at:CGPoint(x:bounds.width-number.size().width,y:0))
        let track=CGRect(x:0,y:30,width:bounds.width,height:7)
        c.setFillColor(NSColor(Palette.line).cgColor);c.addPath(CGPath(roundedRect:track,cornerWidth:3.5,cornerHeight:3.5,transform:nil));c.fillPath()
        if value>0 {
            c.saveGState();c.addPath(CGPath(roundedRect:track,cornerWidth:3.5,cornerHeight:3.5,transform:nil));c.clip()
            c.setFillColor(NSColor(Palette.accent).cgColor);c.fill(CGRect(x:0,y:30,width:track.width*value,height:7));c.restoreGState()
        }
        let formatted=String(format:"%.0f%%",value*100),snapshot=title+formatted
        if snapshot != accessibilitySnapshot {
            setAccessibilityLabel(title+" 扳机行程");setAccessibilityValue(formatted);accessibilitySnapshot=snapshot
        }
    }
}
struct RealtimeTrigger:NSViewRepresentable {
    var title:String
    let provider:()->Double
    func makeNSView(context:Context)->TriggerMeterView { let v=TriggerMeterView(frame:.zero);v.title=title;v.provider=provider;return v }
    func updateNSView(_ v:TriggerMeterView,context:Context) { v.title=title;v.provider=provider }
    static func dismantleNSView(_ v:TriggerMeterView,coordinator:()) { v.provider={0} }
}
