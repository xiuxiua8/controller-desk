import Foundation
import GameController
GCController.shouldMonitorBackgroundEvents=true
var samples:[[String:Any]]=[]
let start=ProcessInfo.processInfo.systemUptime
let timer=Timer.scheduledTimer(withTimeInterval:1.0/60,repeats:true) { _ in
    for c in GCController.controllers() where c.extendedGamepad is GCXboxGamepad {
        guard let pad=c.extendedGamepad else {continue}
        samples.append(["t":ProcessInfo.processInfo.systemUptime-start,"lt":Double(pad.leftTrigger.value),"rt":Double(pad.rightTrigger.value),"A":pad.buttonA.isPressed,"B":pad.buttonB.isPressed,"X":pad.buttonX.isPressed,"Y":pad.buttonY.isPressed])
    }
}
RunLoop.current.run(until:Date().addingTimeInterval(35))
timer.invalidate()
let url=URL(fileURLWithPath:CommandLine.arguments[1]);try JSONSerialization.data(withJSONObject:samples).write(to:url)
for name in ["lt","rt"] {let values=samples.compactMap{$0[name] as? Double};let partial=values.filter{$0>0.02 && $0<0.98};print("\(name): samples=\(values.count), partial=\(partial.count), min=\(values.min() ?? -1), max=\(values.max() ?? -1)")}
