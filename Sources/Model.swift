import AppKit
import GameController
import SwiftUI

struct InputState {
    var buttons: Set<String> = []
    var left = CGPoint.zero, right = CGPoint.zero
    var lt = 0.0, rt = 0.0
    var gyro = Vector3(), acc = Vector3()
    var sampleCount = 0, rate = 0.0
    var motionLive = false, inputLive = false
    var calibration = "等待数据"
    var battery: [String: Int] = [:]
    var bodyColors: [String: Int] = [:]
    var buttonColors: [String: Int] = [:]
    var liveColors: Set<String> = []
    var sideAcceleration: [String: Vector3] = [:]
    var sideReportHz: [String: Double] = [:]
}
struct InputEvent: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}
@MainActor final class FrameClock:ObservableObject {
    @Published var frame:UInt64=0
}

@MainActor final class ControllerModel: ObservableObject {
    @Published var groups: [DeviceGroup] = []
    @Published var selected = "nintendo" { didSet { UserDefaults.standard.set(selected,forKey:"selectedGroup") } }
    @Published var inventory = Inventory()
    var input = InputState()
    @Published var busy = false
    @Published var message = "按下手柄按键，开始测试。"
    @Published var isError = false
    var events: [InputEvent] = []
    var history: [Vector3] = []
    @Published var motionSide = UserDefaults.standard.string(forKey:"motionSide") ?? "R" { didSet { UserDefaults.standard.set(motionSide,forKey:"motionSide") } }
    var calibrationProgress: Double?
    var bias = Vector3()
    @Published var corrected = (UserDefaults.standard.object(forKey:"showCorrectedMotion") as? Bool) ?? true { didSet { UserDefaults.standard.set(corrected,forKey:"showCorrectedMotion") } }
    @Published var showAdd = false
    @Published var showRepair = false
    @Published var showDetails = false
    var hid = HIDBridge()
    let frames=FrameClock()
    let bluetooth = BluetoothService()
    private var timer: Timer?
    private var operation:Task<Void,Never>?
    private var failedDisconnectIDs: Set<String>?
    @Published private(set) var refreshing = false
    private var ticks = 0
    private var previousButtons: Set<String> = []
    private var lastMotionCount = 0
    private var rateCount = 0
    private var rateTime = ProcessInfo.processInfo.systemUptime
    private var restSamples: [Vector3] = []
    private var restGravity: [Double] = []
    private var calibrationStart: Double?
    private var calibrationAddress: String?
    private var biases: [String: Vector3] = [:]
    private var cachedColors: [String: [String: Int]] = UserDefaults.standard.dictionary(forKey:"controllerColors") as? [String:[String:Int]] ?? [:]
    var current: DeviceGroup { groups.first { $0.id == selected } ?? groups[0] }
    var connectedCount: Int { current.devices.filter { isOnline($0) }.count }
    var allOnline: Bool { connectedCount == current.devices.count && !current.devices.isEmpty }
    var anyOnline: Bool { connectedCount > 0 }
    var candidateDevices: [Device] {
        let known = Set(groups.flatMap(\.devices).map(\.id))
        return inventory.paired.filter { !known.contains($0.id) &&
            ["controller","joy-con","gamepad","dualsense","dualshock","pro controller"].contains(where: $0.name.lowercased().contains) }
    }
    var configURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Controller Desk/devices.json")
    }
    init() {
        if let data = try? Data(contentsOf: configURL), let saved = try? JSONDecoder().decode([DeviceGroup].self, from: data), !saved.isEmpty {
            groups = saved
        } else if let url = Bundle.main.url(forResource: "controllers", withExtension: "json"),
                  let data = try? Data(contentsOf: url), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = obj["groups"] as? [String: [String: Any]] {
            for key in ["nintendo","mobile_pad","xbox"] {
                guard let item = items[key], let devices = item["devices"] as? [[String: String]] else { continue }
                groups.append(.init(id: key, name: key == "mobile_pad" ? "Mobapad M6 HD" : key == "xbox" ? "Xbox" : "Nintendo Joy-Con",
                                    subtitle: key == "mobile_pad" ? "第三方 · 左右双手柄" : key == "xbox" ? "Xbox Wireless Controller" : "原装 · 左右双手柄",
                                    kind: key == "mobile_pad" ? "mobapad" : key == "xbox" ? "xbox" : "joycon",
                                    devices: devices.compactMap { d in guard let a=d["address"], let n=d["name"] else { return nil }; return Device(name:n,address:a) }))
            }
        }
        if groups.isEmpty { groups = [.init(id: "empty", name: "Controller Desk", subtitle: "添加设备开始使用", kind: "generic", devices: [])] }
        selected=UserDefaults.standard.string(forKey:"selectedGroup") ?? "nintendo"
        if !groups.contains(where: { $0.id == selected }) { selected = groups[0].id }
        GCController.shouldMonitorBackgroundEvents = true
        _ = GCController.controllers()
        hid.start()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        refresh()
    }
    func isOnline(_ device: Device) -> Bool {
        if inventory.online.contains(device.id) { return true }
        return hid.snapshots().contains { row in
            normalized(row["address"] as? String ?? "") == device.id &&
                ProcessInfo.processInfo.systemUptime - (row["last"] as? Double ?? 0) < 2
        }
    }
    func choose(_ id: String) {
        guard id != selected else { return }
        selected=id; input=InputState(); history=[]; events=[]; previousButtons=[]
        resetSampling()
        message="按下手柄按键，开始测试。"; isError=false
    }
    private func resetSampling() {
        calibrationStart=nil; calibrationProgress=nil; restSamples=[]; restGravity=[]
        lastMotionCount=0; rateCount=0; rateTime=ProcessInfo.processInfo.systemUptime
        bias=Vector3()
    }
    func changeSide() { resetSampling(); history=[] }
    func refresh() {
        guard !refreshing, !busy else { return }
        refreshing=true
        Task {
            inventory = await bluetooth.inventory()
            if let ids=failedDisconnectIDs, inventory.verified, ids.isDisjoint(with:inventory.online) {
                failedDisconnectIDs=nil; isError=false; message="这组手柄已断开，配对记录保留。"
            }
            refreshing=false
        }
    }
    func perform(disconnect: Bool = false) {
        guard !busy else { return }
        busy=true; isError=false; failedDisconnectIDs=nil
        let target=current
        message=disconnect ? "正在断开这组手柄…" : "正在连接 \(target.name)，请按手柄同步键。"
        operation=Task {
            do {
                inventory = try await bluetooth.manageGroup(target, disconnectOnly: disconnect) { [weak self] text in
                    self?.message=text
                }
                message=disconnect ? "这组手柄已断开。" : "\(target.name) 已连接。其他手柄保持原有连接。"
            } catch is CancellationError {
                message="已停止等待。已经连接的手柄会保留。"; isError=false
                inventory=await bluetooth.inventory()
            } catch {
                isError=true; message=error.localizedDescription
                if disconnect { failedDisconnectIDs=Set(target.devices.map(\.id)) }
                inventory=await bluetooth.inventory()
            }
            busy=false
            operation=nil
        }
    }
    func cancelConnection() { operation?.cancel(); message="正在停止等待…" }
    func poll() {
        ticks += 1
        if ticks % 360 == 0 { refresh() }
        let now=ProcessInfo.processInfo.systemUptime
        let rows=hid.snapshots().filter { row in current.devices.contains { $0.id == normalized(row["address"] as? String ?? "") } }
        var next=InputState()
        for device in current.devices {
            if let color=cachedColors[device.id] { next.bodyColors[device.side]=color["body"]; next.buttonColors[device.side]=color["buttons"] }
        }
        for row in rows where row["hasColor"] as? Bool == true {
            let side=(row["right"] as? Bool ?? false) ? "R":"L"
            let colors=["body":row["bodyColor"] as? Int ?? 0,"buttons":row["buttonColor"] as? Int ?? 0]
            let address=normalized(row["address"] as? String ?? "")
            next.bodyColors[side]=colors["body"]; next.buttonColors[side]=colors["buttons"]; next.liveColors.insert(side)
            if cachedColors[address] != colors { cachedColors[address]=colors; UserDefaults.standard.set(cachedColors,forKey:"controllerColors") }
        }
        for row in rows where now-(row["last"] as? Double ?? 0) < 1.5 {
            next.inputLive=true
            next.buttons.formUnion(row["buttons"] as? [String] ?? [])
            let right=row["right"] as? Bool ?? false
            let st=row["stick"] as? [Double] ?? [0,0]
            if st.count==2 { if right { next.right=CGPoint(x:st[0],y:st[1]) } else { next.left=CGPoint(x:st[0],y:st[1]) } }
            next.battery[right ? "R" : "L"]=row["battery"] as? Int ?? 0
            next.sideAcceleration[right ? "R":"L"]=Vector3(row["acc"] as? [Double] ?? [])
        }
        for row in rows {
            let side=(row["right"] as? Bool ?? false) ? "R":"L"
            next.sideReportHz[side]=now-(row["last"] as? Double ?? 0)<1 ? (row["reportHz"] as? Double ?? 0):0
        }
        next.lt=next.buttons.contains("ZL") ? 1:0; next.rt=next.buttons.contains("ZR") ? 1:0
        if !current.isJoyCon {
            let expected=current.kind == "xbox" ? GCController.controllers().filter { $0.extendedGamepad is GCXboxGamepad || ($0.vendorName ?? "").lowercased().contains("xbox") } : GCController.controllers().filter { !($0.extendedGamepad is GCXboxGamepad) && !($0.vendorName ?? "").contains("Joy-Con") }
            let matchingGroups=groups.filter { !$0.isJoyCon && $0.kind == current.kind && $0.devices.contains(where: isOnline) }
            if anyOnline, expected.count==1, matchingGroups.count==1, let controller=expected.first, let pad=controller.extendedGamepad {
                next.inputLive=true
                let buttons:[String:GCControllerButtonInput?] = ["A":pad.buttonA,"B":pad.buttonB,"X":pad.buttonX,"Y":pad.buttonY,
                    "L":pad.leftShoulder,"R":pad.rightShoulder,"ZL":pad.leftTrigger,"ZR":pad.rightTrigger,
                    "+":pad.buttonMenu,"−":pad.buttonOptions,"Home":pad.buttonHome,"L3":pad.leftThumbstickButton,"R3":pad.rightThumbstickButton,
                    "↑":pad.dpad.up,"↓":pad.dpad.down,"←":pad.dpad.left,"→":pad.dpad.right]
                for (name,value) in buttons where value?.isPressed == true { next.buttons.insert(name) }
                if let xbox=pad as? GCXboxGamepad, xbox.buttonShare?.isPressed == true { next.buttons.insert("Capture") }
                next.left=CGPoint(x:Double(pad.leftThumbstick.xAxis.value),y:Double(pad.leftThumbstick.yAxis.value))
                next.right=CGPoint(x:Double(pad.rightThumbstick.xAxis.value),y:Double(pad.rightThumbstick.yAxis.value))
                next.lt=Double(pad.leftTrigger.value); next.rt=Double(pad.rightTrigger.value)
                if let motion=controller.motion, motion.hasRotationRate {
                    let g=motion.rotationRate,a=motion.acceleration
                    next.gyro=Vector3([g.x*180 / .pi,g.y*180 / .pi,g.z*180 / .pi]); next.acc=Vector3([a.x,a.y,a.z])
                    next.motionLive=true; next.calibration="GameController"
                }
            }
        }
        let motionRow=rows.first { ($0["right"] as? Bool ?? false) == (motionSide == "R") }
        if let row=motionRow, now-(row["motionLast"] as? Double ?? 0)<1.5 {
            next.acc=Vector3(row["acc"] as? [Double] ?? [])
            next.gyro=Vector3(row["gyro"] as? [Double] ?? [])
            next.sampleCount=row["count"] as? Int ?? 0
            next.calibration=row["calibration"] as? String ?? "默认比例"
            next.motionLive=next.sampleCount>0
            let address=normalized(row["address"] as? String ?? "")
            bias=biases[address] ?? Vector3()
            if next.sampleCount != lastMotionCount {
                if let start=calibrationStart {
                    if calibrationAddress != address { cancelCalibration("连接已改变，请重新校准。") }
                    else {
                        restSamples.append(next.gyro); restGravity.append(next.acc.magnitude)
                        calibrationProgress=min(1,(now-start)/4)
                        if now-start>=4 { finishCalibration(address) }
                    }
                }
                history.append(corrected ? next.gyro-bias : next.gyro)
                if history.count>360 { history.removeFirst(history.count-360) }
                lastMotionCount=next.sampleCount
            }
            if now-rateTime>=1 {
                next.rate=Double(max(0,next.sampleCount-rateCount))/(now-rateTime)
                rateCount=next.sampleCount; rateTime=now
            } else { next.rate=input.rate }
        } else if calibrationStart != nil { cancelCalibration("体感数据已中断，请重新连接后校准。") }
        let newlyPressed=next.buttons.subtracting(previousButtons)
        if !newlyPressed.isEmpty {
            events.insert(.init(text:newlyPressed.sorted().joined(separator:" + ")),at:0)
            if events.count>40 { events.removeLast(events.count-40) }
        }
        previousButtons=next.buttons
        input=next
        if ticks % 6 == 0 { frames.frame &+= 1 }
    }
    func calibrate() {
        guard input.motionLive else { return }
        let side=current.devices.first { $0.side == motionSide }
        guard let side else { return }
        calibrationAddress=side.id; calibrationStart=ProcessInfo.processInfo.systemUptime
        restSamples=[]; restGravity=[]; calibrationProgress=0
        message="请保持手柄静止，正在采样 4 秒…"; isError=false
    }
    func finishCalibration(_ address: String) {
        do {
            let value=try RestCalibration.bias(samples:restSamples,gravity:restGravity)
            biases[address]=value; bias=value; corrected=true; history=[]
            message="静止校准完成。仅用于本应用的体感测试。"; isError=false
        } catch { message=error.localizedDescription; isError=true }
        calibrationStart=nil; calibrationProgress=nil
    }
    func cancelCalibration(_ reason: String) { calibrationStart=nil; calibrationProgress=nil; isError=true; message=reason }
    func clearBias() {
        if let d=current.devices.first(where: { $0.side==motionSide }) { biases.removeValue(forKey:d.id) }
        bias=Vector3(); history=[]; message="已恢复出厂校准数据。"; isError=false
    }
    func add(_ devices: [Device], kind: String) {
        do {
            let known=Set(groups.flatMap(\.devices).map(\.id))
            guard devices.allSatisfy({ !known.contains($0.id) }) else { throw AppFailure("部分设备已经添加，请刷新列表。") }
            let group=try RegistrationRules.makeGroup(devices:devices,kind:kind)
            let next=groups.filter { $0.id != "empty" }+[group]
            try FileManager.default.createDirectory(at:configURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            let data=try JSONEncoder().encode(next); try data.write(to:configURL,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:configURL.path)
            groups=next; showAdd=false; choose(group.id); isError=false
        } catch { isError=true; message="无法保存设备：\(error.localizedDescription)" }
    }
    func exportDiagnostics() {
        let now=ProcessInfo.processInfo.systemUptime
        let raw=hid.snapshots().filter { row in current.devices.contains { $0.id==normalized(row["address"] as? String ?? "") } }.map { row -> [String:Any] in
            ["side":(row["right"] as? Bool ?? false) ? "R":"L","reports":row["reportCount"] ?? 0,"reportHz":row["reportHz"] ?? 0,"motionSamples":row["count"] ?? 0,"inputAgeMs":(now-(row["last"] as? Double ?? now))*1000,"motionAgeMs":(now-(row["motionLast"] as? Double ?? now))*1000,"acc":row["acc"] ?? [],"gyro":row["gyro"] ?? []]
        }
        let object:[String:Any] = ["app":"Controller Desk 1.1","date":ISO8601DateFormatter().string(from:Date()),"rawInput":raw,
            "device":current.name,"connected":connectedCount,"systemVerified":inventory.verified,
            "inputLive":input.inputLive,"motionLive":input.motionLive,"sampleCount":input.sampleCount,
            "sampleRate":input.rate,"gyroDegreesPerSecond":input.gyro.values,"accelerationG":input.acc.values,"localBias":bias.values,
            "triggers":["left":input.lt,"right":input.rt],"buttons":input.buttons.sorted(),"preview":FastControllerView.current?.diagnostics() ?? [:],"message":message]
        // Capture timing before the modal save dialog affects the render run loop.
        let panel=NSSavePanel(); panel.nameFieldStringValue="Controller Desk Diagnostics.json"; panel.allowedContentTypes=[.json]
        guard panel.runModal() == .OK, let url=panel.url else { return }
        do { try JSONSerialization.data(withJSONObject:object,options:[.prettyPrinted,.sortedKeys]).write(to:url,options:.atomic) }
        catch { message="导出失败：\(error.localizedDescription)"; isError=true }
    }
}
