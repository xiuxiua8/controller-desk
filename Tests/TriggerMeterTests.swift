import AppKit
import SwiftUI

enum Palette {
    static let accent=Color(nsColor:NSColor(srgbRed:1,green:0.5,blue:0,alpha:1))
    static let line=Color(nsColor:NSColor(srgbRed:0.8,green:0.8,blue:0.8,alpha:1))
}
@main enum TriggerMeterTests {
    static func main() {
        _=NSApplication.shared
        NSApp.appearance=NSAppearance(named:.aqua)
        var value=0.0
        let meter=TriggerMeterView(frame:NSRect(x:0,y:0,width:200,height:45));meter.provider={value}
        func draw(_ next:Double)->NSBitmapImageRep {
            value=next
            let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:200,pixelsHigh:45,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
            meter.draw(meter.bounds)
            NSGraphicsContext.restoreGraphicsState()
            return bitmap
        }
        func filled(_ image:NSBitmapImageRep,_ x:Int)->Bool {
            (0..<45).contains { y in
                guard let c=image.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB) else {return false}
                return c.redComponent>0.95 && c.greenComponent>0.4 && c.greenComponent<0.6 && c.blueComponent<0.05 && c.alphaComponent>0.9
            }
        }
        assert(!filled(draw(0),180))
        assert(filled(draw(1),180),"full travel must appear in the very first draw")
        assert(meter.accessibilityValue() as? String=="100%")
        assert(!filled(draw(0),180),"release must clear immediately, without easing")
        assert(meter.accessibilityValue() as? String=="0%")
        let quarter=draw(0.25);assert(filled(quarter,20) && !filled(quarter,80))
        assert(meter.accessibilityValue() as? String=="25%")
        assert(filled(draw(2),180));assert(!filled(draw(.nan),20))
        print("PASS first-draw 0/100 percent response, immediate release, exact partial travel, matching labels and bounded invalid values")
    }
}
