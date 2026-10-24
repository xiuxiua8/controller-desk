import SwiftUI

struct ControllerDrawing: View {
    let kind: String
    let input: InputState
    var body: some View {
        Canvas { context,size in
            let scale=min(size.width/640,size.height/310)
            context.translateBy(x:(size.width-640*scale)/2,y:(size.height-310*scale)/2)
            context.scaleBy(x:scale,y:scale)
            func rounded(_ rect:CGRect,_ radius:CGFloat,_ color:Color) {
                context.fill(Path(roundedRect:rect,cornerRadius:radius),with:.color(color))
            }
            func text(_ value:String,_ x:Double,_ y:Double,_ color:Color = .white,_ font:Double=12) {
                context.draw(Text(value).font(.system(size:font,weight:.semibold,design:.rounded)).foregroundColor(color),at:CGPoint(x:x,y:y))
            }
            func circle(_ name:String,_ x:Double,_ y:Double,_ radius:Double=14,_ label:String?=nil,_ color:Color?=nil) {
                let down=input.buttons.contains(name)
                let path=Path(ellipseIn:CGRect(x:x-radius,y:y-radius,width:radius*2,height:radius*2))
                if down { context.addFilter(.shadow(color:Palette.accent.opacity(0.45),radius:8)) }
                context.fill(path,with:.color(down ? Palette.accent : Color(white:0.16)))
                context.addFilter(.shadow(color:.clear,radius:0))
                context.stroke(path,with:.color(.white.opacity(0.18)),lineWidth:1)
                text(label ?? name,x,y,down ? .white : color ?? Color(white:0.88),radius<11 ? 9:12)
            }
            func stick(_ name:String,_ x:Double,_ y:Double,_ point:CGPoint) {
                context.fill(Path(ellipseIn:CGRect(x:x-26,y:y-26,width:52,height:52)),with:.color(Color.black.opacity(0.15)))
                context.stroke(Path(ellipseIn:CGRect(x:x-26,y:y-26,width:52,height:52)),with:.color(Color.white.opacity(0.20)),lineWidth:1)
                let dx=point.x*12,dy = -point.y*12
                circle(name,x+dx,y+dy,21,"")
                context.stroke(Path(ellipseIn:CGRect(x:x+dx-14,y:y+dy-14,width:28,height:28)),with:.color(Color.white.opacity(0.15)),lineWidth:1)
            }
            func shoulder(_ name:String,_ x:Double,_ y:Double,_ label:String?=nil) {
                rounded(CGRect(x:x-29,y:y-9,width:58,height:18),7,input.buttons.contains(name) ? Palette.accent : Color(white:0.22))
                text(label ?? name,x,y,.white,10)
            }
            if kind == "joycon" || kind == "mobapad" {
                let mob=kind == "mobapad"
                for right in [false,true] {
                    let x:Double=right ? 432:208
                    let color:Color=mob ? Color(red:0.91,green:0.92,blue:0.93) : right ? Color(red:0.94,green:0.27,blue:0.30) : Color(red:0.18,green:0.72,blue:0.90)
                    var path=Path()
                    if mob {
                        path.move(to:CGPoint(x:x-35,y:59)); path.addQuadCurve(to:CGPoint(x:x+36,y:59),control:CGPoint(x:x,y:38))
                        path.addCurve(to:CGPoint(x:x+37,y:259),control1:CGPoint(x:x+58,y:104),control2:CGPoint(x:x+46,y:232))
                        path.addQuadCurve(to:CGPoint(x:x-40,y:252),control:CGPoint(x:x,y:292))
                        path.addCurve(to:CGPoint(x:x-35,y:59),control1:CGPoint(x:x-57,y:199),control2:CGPoint(x:x-55,y:110)); path.closeSubpath()
                    } else { path=Path(roundedRect:CGRect(x:x-39,y:53,width:78,height:214),cornerRadius:34) }
                    context.addFilter(.shadow(color:.black.opacity(0.14),radius:8,x:0,y:6))
                    context.fill(path,with:.color(color)); context.addFilter(.shadow(color:.clear,radius:0))
                    context.stroke(path,with:.color(.black.opacity(0.12)),lineWidth:1)
                    shoulder(right ? "ZR":"ZL",x,27)
                    shoulder(right ? "R":"L",x,48)
                    if right {
                        circle("+",x-21,79,8,"+")
                        circle("X",x,105,12); circle("Y",x-23,129,12); circle("A",x+23,129,12); circle("B",x,153,12)
                        stick("R3",x,202,input.right)
                        circle("Home",x-20,244,9,"⌂")
                    } else {
                        circle("−",x+21,79,8,"−")
                        stick("L3",x,122,input.left)
                        circle("↑",x,178,10); circle("←",x-21,200,10); circle("→",x+21,200,10); circle("↓",x,222,10)
                        circle("Capture",x+20,246,8,"□")
                    }
                }
                for right in [false,true] {
                    let x:Double=right ? 377:263
                    for (index,name) in ["SL","SR"].enumerated() {
                        let pressed=input.buttons.contains(name)
                        rounded(CGRect(x:x-4,y:Double(134+index*35),width:8,height:22),3,pressed ? Palette.accent:Color(white:0.75))
                    }
                }
                text(mob ? "M6 HD":"JOY-CON",320,156,Palette.secondary,11)
                text("L",208,295,Palette.secondary,10); text("R",432,295,Palette.secondary,10)
            } else {
                var body=Path()
                body.move(to:CGPoint(x:205,y:61)); body.addQuadCurve(to:CGPoint(x:435,y:61),control:CGPoint(x:320,y:26))
                body.addCurve(to:CGPoint(x:502,y:246),control1:CGPoint(x:487,y:79),control2:CGPoint(x:504,y:198))
                body.addQuadCurve(to:CGPoint(x:454,y:270),control:CGPoint(x:505,y:286))
                body.addLine(to:CGPoint(x:393,y:212)); body.addQuadCurve(to:CGPoint(x:247,y:212),control:CGPoint(x:320,y:233))
                body.addLine(to:CGPoint(x:186,y:270)); body.addQuadCurve(to:CGPoint(x:138,y:246),control:CGPoint(x:135,y:286))
                body.addCurve(to:CGPoint(x:205,y:61),control1:CGPoint(x:136,y:198),control2:CGPoint(x:153,y:79)); body.closeSubpath()
                context.addFilter(.shadow(color:.black.opacity(0.18),radius:10,x:0,y:8))
                context.fill(body,with:.linearGradient(Gradient(colors:[Color(white:0.25),Color(white:0.14)]),startPoint:CGPoint(x:320,y:60),endPoint:CGPoint(x:320,y:265)))
                context.addFilter(.shadow(color:.clear,radius:0)); context.stroke(body,with:.color(.black.opacity(0.3)),lineWidth:1)
                shoulder("ZL",218,27,"LT"); shoulder("ZR",422,27,"RT")
                shoulder("L",218,49,"LB"); shoulder("R",422,49,"RB")
                stick("L3",218,115,input.left); stick("R3",374,192,input.right)
                circle("Y",430,91,13,nil,.yellow); circle("X",405,116,13,nil,.cyan)
                circle("B",455,116,13,nil,.red); circle("A",430,141,13,nil,.green)
                circle("↑",266,165,11); circle("←",244,187,11); circle("→",288,187,11); circle("↓",266,209,11)
                circle("Home",320,86,16,kind == "xbox" ? "X":"⌂")
                circle("−",290,126,9,"▣"); circle("+",350,126,9,"☰"); circle("Capture",320,160,8,"↑")
            }
        }
        .accessibilityElement(children:.ignore)
        .accessibilityLabel("手柄实时图，按下：" + (input.buttons.isEmpty ? "无":input.buttons.sorted().joined(separator:"、")))
    }
}

struct StickPlot: View {
    let title: String
    let point: CGPoint
    var provider:(()->CGPoint)? = nil
    var body: some View {
        HStack(spacing:16) {
            LiveStickScope(provider:provider ?? {point})
            .frame(width:82,height:82).accessibilityLabel("\(title)，X \(point.x)，Y \(point.y)")
            VStack(alignment:.leading,spacing:7) {
                Text(title).font(.system(size:13,weight:.semibold))
                Text(String(format:"X  %+.3f\nY  %+.3f",point.x,point.y)).font(.system(size:12,design:.monospaced)).foregroundStyle(Palette.secondary).lineSpacing(3)
            }
            Spacer(minLength:0)
        }
    }
}
