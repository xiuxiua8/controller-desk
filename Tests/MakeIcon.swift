import AppKit
let folder=URL(fileURLWithPath:CommandLine.arguments[1])
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
for size in [16,32,64,128,256,512,1024] {
    let image=NSImage(size:NSSize(width:size,height:size))
    image.lockFocus()
    let context=NSGraphicsContext.current!.cgContext
    context.scaleBy(x:CGFloat(size)/1024,y:CGFloat(size)/1024)
    let bg=NSBezierPath(roundedRect:NSRect(x:52,y:52,width:920,height:920),xRadius:210,yRadius:210)
    NSColor(calibratedRed:0.91,green:0.87,blue:0.80,alpha:1).setFill(); bg.fill()
    for right in [false,true] {
        let x:CGFloat=right ? 546:258
        let body=NSBezierPath(roundedRect:NSRect(x:x,y:255,width:220,height:514),xRadius:98,yRadius:98)
        NSColor(calibratedRed:0.30,green:0.27,blue:0.23,alpha:1).setFill(); body.fill()
        NSColor(calibratedRed:0.91,green:0.87,blue:0.80,alpha:1).setFill()
        let positions=right ? [(x+110,590.0),(x+110,435.0),(x+65,480.0),(x+155,480.0)] : [(x+110,590.0),(x+110,435.0),(x+65,480.0),(x+155,480.0)]
        for (index,p) in positions.enumerated() {
            let r:CGFloat=index==0 ? 43:17
            NSBezierPath(ovalIn:NSRect(x:p.0-r,y:p.1-r,width:r*2,height:r*2)).fill()
        }
    }
    image.unlockFocus()
    let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
    let png=rep.representation(using:.png,properties:[:])!
    let base=size==1024 ? "icon_512x512@2x.png":"icon_\(size)x\(size).png"
    try png.write(to:folder.appendingPathComponent(base))
    if size>=32 && size<=512 { try png.write(to:folder.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png")) }
}
