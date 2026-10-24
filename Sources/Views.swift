import SwiftUI
import AppKit

enum Palette {
    private static func adaptive(_ light:(Double,Double,Double),_ dark:(Double,Double,Double))->Color {
        Color(nsColor:NSColor(name:nil) { appearance in
            let v=appearance.bestMatch(from:[.aqua,.darkAqua]) == .darkAqua ? dark:light
            return NSColor(srgbRed:v.0,green:v.1,blue:v.2,alpha:1)
        })
    }
    static let accent=adaptive((0.76,0.43,0.29),(0.84,0.57,0.43))
    static let background=adaptive((0.973,0.965,0.945),(0.153,0.153,0.141))
    static let sidebar=adaptive((0.938,0.926,0.899),(0.129,0.129,0.121))
    static let card=adaptive((0.993,0.987,0.968),(0.184,0.184,0.168))
    static let secondary=Color.secondary
    static let line=adaptive((0.86,0.85,0.81),(0.27,0.27,0.24))
}
struct Card<Content:View>:View {
    var title:String?=nil
    @ViewBuilder var content:Content
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            if let title { Text(title).font(.system(size:15,weight:.medium)) }
            content
        }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
            .background(Palette.card,in:RoundedRectangle(cornerRadius:18))
    }
}
struct StatusPill:View {
    let text:String
    let active:Bool
    var body:some View {
        HStack(spacing:7) { Circle().fill(active ? Palette.accent:Color.secondary.opacity(0.4)).frame(width:6,height:6);Text(text) }
            .font(.system(size:12)).foregroundStyle(.secondary)
    }
}
struct RootView:View {
    @StateObject var model=ControllerModel()
    @State private var tab=0
    @State private var addedDeviceIDs: Set<String> = []
    @State private var addedKind="joycon"
    var body:some View {
        HStack(spacing:0) {
            sidebar.frame(width:236)
            Rectangle().fill(Palette.line.opacity(0.55)).frame(width:1)
            VStack(spacing:0) {
                header
                ScrollView {
                    LiveFramePanel(clock:model.frames,key:{renderKey}) {
                        Group {
                            if model.current.devices.isEmpty {
                                ContentUnavailableView {
                                    Label("添加你的手柄",systemImage:"gamecontroller")
                                } description: {
                                    Text("先在 macOS 配对，再选择设备。Joy-Con 左右两只可以一起加入。")
                                } actions: {
                                    Button("添加手柄") { model.showAdd=true; model.refresh() }.controlSize(.large)
                                }.frame(minHeight:440)
                            } else if tab==0 { inputPage } else { motionPage }
                        }
                            .padding(.horizontal,36).padding(.top,12).padding(.bottom,28)
                    }
                }
                if model.busy || model.isError || model.calibrationProgress != nil { footer }
            }.frame(minWidth:740)
        }.frame(minWidth:1000,minHeight:760)
        .background(Palette.background).tint(Palette.accent)
        .sheet(isPresented:$model.showAdd) { addSheet }
        .sheet(isPresented:$model.showDetails) {
            VStack(alignment:.leading,spacing:20) {
                HStack { Text("设备详情").font(.system(size:24,weight:.semibold));Spacer();Button("完成") { model.showDetails=false }.keyboardShortcut(.defaultAction) }
                ScrollView { LiveFramePanel(clock:model.frames,key:{"\(model.input.sideReportHz)|\(model.input.bodyColors)|\(model.inventory.online)"}) {detailsPage} }
            }.padding(28).frame(width:620,height:650).background(Palette.background)
        }
        .alert("连接到 Mac",isPresented:$model.showRepair) { Button("知道了",role:.cancel) {} } message: {
            Text("先点连接，再按手柄同步键。Joy-Con 左右两只都长按 SYNC 到滚灯；Xbox 长按顶部配对键。应用会处理这一组的旧配对，其他手柄保持连接。平时按普通按键唤醒即可。")
        }
    }
    var sidebar:some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(alignment:.center,spacing:12) {
                Image(systemName:"gamecontroller").font(.system(size:26,weight:.light)).foregroundStyle(Palette.accent)
                Text("Controller\nDesk").font(.system(size:21,weight:.medium)).lineSpacing(0)
            }.padding(.horizontal,26).padding(.top,34).padding(.bottom,40)
            ForEach(model.groups.filter { !$0.devices.isEmpty }) { group in
                let selected=model.selected==group.id
                let online=group.devices.filter {model.isOnline($0)}.count
                Button {model.choose(group.id)} label: {
                    HStack(spacing:14) {
                        ControllerGlyph(joycon:group.isJoyCon).frame(width:31,height:29)
                        VStack(alignment:.leading,spacing:7) {
                            Text(group.name).font(.system(size:14,weight:.medium)).lineLimit(2)
                            HStack(spacing:6) {
                                Circle().fill(online>0 ? Palette.accent:Color.secondary.opacity(0.3)).frame(width:5,height:5)
                                Text(online==group.devices.count && online>0 ? "已连接":online>0 ? "已连接 \(online)/\(group.devices.count)":"未连接").font(.system(size:11)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength:0)
                    }.padding(.horizontal,16).padding(.vertical,18)
                        .foregroundStyle(selected ? Color.primary:Color.secondary)
                        .background(selected ? Palette.card:Color.clear,in:RoundedRectangle(cornerRadius:14))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(model.busy)
                    .contextMenu {
                        Button("连接到 Mac") {model.choose(group.id);model.perform()}
                        Button("断开连接") {model.choose(group.id);model.perform(disconnect:true)}.disabled(online==0)
                        Button("设备详情") {model.choose(group.id);model.showDetails=true}
                    }.padding(.horizontal,12).padding(.bottom,6)
            }
            Spacer()
            Button {model.showAdd=true;model.refresh()} label: {
                Label("添加手柄",systemImage:"plus").font(.system(size:13)).padding(12)
            }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.horizontal,20).padding(.bottom,24).disabled(model.busy)
        }.frame(maxHeight:.infinity).background(Palette.sidebar)
    }
    var header:some View {
        VStack(alignment:.leading,spacing:28) {
            HStack(spacing:16) {
                Text(model.current.devices.isEmpty ? "连接你的手柄" : model.current.name).font(.system(size:28,weight:.semibold)).tracking(-0.5)
                Spacer()
                if !model.current.devices.isEmpty {
                Button {model.perform()} label: {
                    HStack(spacing:8) {
                        if model.busy {ProgressView().controlSize(.small)}
                        else {Image(systemName:model.allOnline ? "checkmark":"link")}
                        Text(model.busy ? "正在连接":model.allOnline ? "已连接":model.anyOnline ? "补全连接":"连接到 Mac")
                    }.font(.system(size:14,weight:.medium)).padding(.horizontal,7).padding(.vertical,4)
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy || model.current.devices.isEmpty || model.allOnline)
                Menu {
                    Button("断开连接") {model.perform(disconnect:true)}.disabled(!model.anyOnline || model.busy)
                    Button("设备详情") {model.showDetails=true}
                    Divider()
                    Button("刷新连接状态") {model.refresh()}
                    Button("连接说明") {model.showRepair=true}
                    Button("导出诊断…") {model.exportDiagnostics()}
                } label:{Image(systemName:"ellipsis").font(.system(size:17,weight:.medium))}.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width:26).help("手柄选项")
                }
            }
            if !model.current.devices.isEmpty {
            HStack(spacing:0) {
                ForEach(0..<2) { index in
                    Button {tab=index} label: {
                        Text(index==0 ? "输入测试":"体感测试").font(.system(size:13,weight:tab==index ? .semibold:.regular))
                            .padding(.horizontal,19).padding(.vertical,10)
                            .background(tab==index ? Palette.card:Color.clear,in:RoundedRectangle(cornerRadius:9))
                            .foregroundStyle(tab==index ? Color.primary:Color.secondary)
                    }.buttonStyle(.plain)
                }
                Spacer()
                if model.busy {Button("停止等待") {model.cancelConnection()}.buttonStyle(.plain).foregroundStyle(Palette.accent)}
            }
            }
        }.padding(.horizontal,36).padding(.top,34).padding(.bottom,18)
    }
    var inputPage:some View {
        VStack(spacing:14) {
            HStack(spacing:18) {
                Spacer()
                ForEach(model.input.battery.keys.sorted(),id:\.self) { side in
                    Text("\(side)  \(model.input.battery[side] ?? 0)%").font(.system(size:11,design:.monospaced)).foregroundStyle(.secondary)
                }
            }.frame(height:16)
            Group {
                if model.current.kind=="mobapad" { VectorControllerPreview(resourceName:"mobapad-preview",provider:{model.input}) }
                else if model.current.kind=="joycon" {FastYuzuPreview(provider:{model.input})}
                else if model.current.kind=="xbox" {VectorControllerPreview(provider:{model.input})}
                else {ControllerDrawing(kind:model.current.kind,input:model.input)}
            }.frame(height:400)
            Text(model.input.buttons.isEmpty ? " ":model.input.buttons.sorted().joined(separator:"   "))
                .font(.system(size:13,weight:.medium,design:.monospaced)).foregroundStyle(Palette.accent).frame(height:24)
            HStack(spacing:40) {
                RealtimeTrigger(title:model.current.kind=="xbox" ? "LT":"ZL",provider:{model.input.lt})
                RealtimeTrigger(title:model.current.kind=="xbox" ? "RT":"ZR",provider:{model.input.rt})
            }.frame(height:40).padding(24).background(Palette.card,in:RoundedRectangle(cornerRadius:16))
        }
    }
    var renderKey:String {
        let s=model.input
        let values=tab==1 ? s.gyro.values+s.acc.values:[Double(s.left.x),Double(s.left.y),Double(s.right.x),Double(s.right.y),s.lt,s.rt]
        return "\(tab)|\(model.selected)|\(model.motionSide)|\(model.corrected)|\(s.inputLive)|\(s.motionLive)|\(values.map{($0*100).rounded()/100})|\(s.buttons.sorted())|\(s.bodyColors)|\(s.battery)|\(model.events.first?.id.uuidString ?? "")|\(Int(s.rate))|\(model.calibrationProgress.map{Int($0*20)} ?? -1)|\(model.bias.values)|\(model.inventory.online.sorted())"
    }
    var motionPage: some View {
        VStack(alignment:.leading,spacing:18) {
            if model.current.kind == "xbox" {
                Card {
                    Image(systemName:"gyroscope").font(.system(size:34)).foregroundStyle(.secondary).padding(.top,15)
                    Text("这款 Xbox 手柄没有陀螺仪").font(.system(size:19,weight:.semibold))
                    Text("可以在「输入测试」测试按键、摇杆和模拟扳机。选择 Joy-Con 或 Mobapad M6 HD，即可测试体感。").font(.system(size:13)).foregroundStyle(.secondary).lineSpacing(5)
                }
            } else {
                Card {
                    HStack {
                        VStack(alignment:.leading,spacing:5) {
                            Text("陀螺仪").font(.system(size:15,weight:.semibold))
                            Text(model.input.motionLive ? "\(model.input.calibration) · \(Int(model.input.rate)) samples/s":"等待体感数据，请连接手柄")
                                .font(.system(size:11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.current.isJoyCon {
                            Picker("测试哪只手柄",selection:$model.motionSide) { Text("左手柄").tag("L"); Text("右手柄").tag("R") }
                                .pickerStyle(.segmented).labelsHidden().frame(width:156).onChange(of:model.motionSide) { _,_ in model.changeSide() }
                        }
                    }
                    let values=(model.corrected ? model.input.gyro-model.bias:model.input.gyro).values
                    HStack(spacing:12) {
                        ForEach(0..<3) { i in
                            VStack(alignment:.leading,spacing:9) {
                                HStack { Circle().fill(axisColors[i]).frame(width:6,height:6); Text(["X 轴","Y 轴","Z 轴"][i]).font(.system(size:11)).foregroundStyle(.secondary) }
                                HStack(alignment:.firstTextBaseline,spacing:4) { Text(model.input.motionLive ? String(format:"%+.2f",values[i]):"--").font(.system(size:24,weight:.medium,design:.monospaced)); Text("°/s").font(.system(size:10)).foregroundStyle(.secondary) }
                            }.frame(maxWidth:.infinity,alignment:.leading).padding(14).background(Palette.background,in:RoundedRectangle(cornerRadius:10))
                        }
                    }
                    LiveMotionScope(provider:{model.history}).frame(height:150)
                    HStack(spacing:15) {
                        Text("最近 6 秒 · 自动缩放").font(.system(size:10)).foregroundStyle(.secondary)
                        Spacer()
                        Toggle("显示静止校准结果",isOn:$model.corrected).toggleStyle(.checkbox).font(.system(size:11))
                    }
                }
                HStack(alignment:.top,spacing:16) {
                    Card(title:"静止校准") {
                        Text("将选中的手柄放稳在桌面上，保持 4 秒。校准会扣除本次测试测得的陀螺仪零点偏移。").font(.system(size:12)).foregroundStyle(.secondary).lineSpacing(4)
                        if let progress=model.calibrationProgress { ProgressView(value:progress).tint(Palette.accent) }
                        HStack {
                            Button(model.calibrationProgress == nil ? "开始静止校准":"正在采样…") { model.calibrate() }.disabled(!model.input.motionLive || model.calibrationProgress != nil)
                            Button("重置") { model.clearBias() }.disabled(model.calibrationProgress != nil)
                        }
                        Text("仅影响本应用测试，不修改游戏设置或手柄固件。").font(.system(size:10)).foregroundStyle(.secondary)
                    }
                    Card(title:"加速度") {
                        ForEach(0..<3) { i in
                            HStack { Text(["X","Y","Z"][i]); Spacer(); Text(model.input.motionLive ? String(format:"%+.3f G",model.input.acc.values[i]):"-- G").monospacedDigit() }.font(.system(size:12)).foregroundStyle(.secondary)
                        }
                        Divider()
                        HStack { Text("合力"); Spacer(); Text(String(format:"%.3f G",model.input.acc.magnitude)).monospacedDigit() }.font(.system(size:12,weight:.medium))
                        Text("静置时合力通常接近 1 G。").font(.system(size:10)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    var axisColors: [Color] { [Palette.accent,Color.orange,Color.indigo] }
    var detailsPage:some View {
        VStack(alignment:.leading,spacing:20) {
            Card {
                ForEach(model.current.devices) { device in
                    HStack(spacing:14) {
                        VStack(alignment:.leading,spacing:5) {
                            Text(device.name).font(.system(size:14,weight:.medium))
                            Text(device.address.uppercased().replacingOccurrences(of:"-",with:":")).font(.system(size:11,design:.monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        Spacer();StatusPill(text:model.isOnline(device) ? "已连接":"未连接",active:model.isOnline(device))
                    }.padding(.vertical,6)
                }
                if model.current.isJoyCon {
                    Divider()
                    ForEach(model.input.sideReportHz.keys.sorted(),id:\.self) { side in
                        HStack {Text(side+" 输入频率");Spacer();Text(String(format:"%.0f Hz",model.input.sideReportHz[side] ?? 0)).monospacedDigit()}.font(.system(size:12)).foregroundStyle(.secondary)
                    }
                    HStack { colorStatus("L");Spacer();colorStatus("R") }
                }
            }
            DisclosureGroup("连接帮助") {
                Text("刚在其他主机使用过时，先点击连接，再按 SYNC 到闪灯。应用只处理当前一组手柄，已连接的一半会保留。平时按普通按键唤醒即可。").font(.system(size:13)).foregroundStyle(.secondary).lineSpacing(5).padding(.top,10)
            }
            DisclosureGroup("开源与来源") {
                VStack(alignment:.leading,spacing:12) {
                    Text("Controller Desk · GPL-3.0-or-later").font(.system(size:13,weight:.medium))
                    Text("Joy-Con 绘图来自 Yuzu/Eden，保留原始矢量坐标。M6 HD 根据官网参考图重绘为独立矢量区域。Xbox 图稿来自 Al. Lopez 的 MIT Gamepad Asset Pack。").font(.system(size:12)).foregroundStyle(.secondary).lineSpacing(5)
                    Button("查看许可证") {if let url=Bundle.main.url(forResource:"GPL-3.0",withExtension:"txt") {NSWorkspace.shared.open(url)}}
                }.padding(.top,12)
            }
        }
    }
    func colorStatus(_ side:String)->some View {
        HStack(spacing:7) {
            Circle().fill(model.input.bodyColors[side].map(rgbColor) ?? .gray).frame(width:9,height:9)
            Text(side+" "+(model.input.bodyColors[side].map{String(format:"#%06X",$0)} ?? "尚未读取"))
        }.font(.system(size:11,design:.monospaced)).foregroundStyle(.secondary)
    }
    var footer:some View {
        HStack(spacing:12) {
            Image(systemName:model.isError ? "exclamationmark.circle":"arrow.triangle.2.circlepath").foregroundStyle(Palette.accent)
            Text(model.message).font(.system(size:12)).foregroundStyle(.secondary).lineLimit(2)
            Spacer()
            if model.isError {Button("打开系统蓝牙") {NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.BluetoothSettings")!)}}
        }.padding(.horizontal,36).padding(.vertical,16)
    }
    var addSheet: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack { Text("添加手柄").font(.system(size:23,weight:.semibold)); Spacer(); Button { model.showAdd=false } label:{ Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
            Text("先在 macOS 完成首次配对，再选择类型及对应设备。跨主机重连仍需手动按 SYNC。").font(.system(size:13)).foregroundStyle(.secondary).lineSpacing(5)
            Picker("手柄类型",selection:$addedKind) {
                Text("Nintendo Joy-Con").tag("joycon")
                Text("Mobapad M6 HD").tag("mobapad")
                Text("Xbox").tag("xbox")
                Text("其他手柄").tag("generic")
            }
            if model.refreshing && model.candidateDevices.isEmpty {
                HStack { ProgressView().controlSize(.small); Text("正在读取已配对手柄…").foregroundStyle(.secondary) }.frame(maxWidth:.infinity,minHeight:100)
            } else if model.candidateDevices.isEmpty {
                ContentUnavailableView("没有其他已配对手柄",systemImage:"gamecontroller",description:Text("首次连接时，请先在 macOS 完成蓝牙配对。"))
            } else {
                ScrollView {
                    ForEach(model.candidateDevices) { device in
                        Toggle(isOn:Binding(get:{addedDeviceIDs.contains(device.id)},set:{ selected in
                            if selected {addedDeviceIDs.insert(device.id)} else {addedDeviceIDs.remove(device.id)}
                        })) {
                            VStack(alignment:.leading,spacing:4) {
                                Text(device.name)
                                Text(device.address.uppercased()).font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
                            }
                        }.toggleStyle(.checkbox).padding(12).frame(maxWidth:.infinity,alignment:.leading)
                            .background(Palette.background,in:RoundedRectangle(cornerRadius:10))
                    }
                }.frame(maxHeight:260)
            }
            if model.isError {Text(model.message).font(.system(size:12)).foregroundStyle(Palette.accent)}
            HStack {
                Button("蓝牙设置") { NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.BluetoothSettings")!) }
                Button("刷新") { model.refresh() }
                Spacer()
                Button("添加选中设备") {
                    model.add(model.candidateDevices.filter {addedDeviceIDs.contains($0.id)},kind:addedKind)
                }.buttonStyle(.borderedProminent).disabled(addedDeviceIDs.isEmpty)
            }
        }.padding(28).frame(width:540)
    }
}
struct ControllerGlyph: View {
    let joycon: Bool
    var body: some View {
        if joycon {
            HStack(spacing:4) {
                ForEach(0..<2) { i in
                    RoundedRectangle(cornerRadius:5).stroke(lineWidth:1.6).frame(width:10,height:25)
                        .overlay(Circle().frame(width:3,height:3).offset(y:i==0 ? -4:4))
                }
            }
        } else { Image(systemName:"gamecontroller").resizable().scaledToFit() }
    }
}
struct CachedLivePanel<Content:View>: View, Equatable {
    let key: String
    @ViewBuilder var content: () -> Content
    static func == (lhs:Self,rhs:Self) -> Bool { lhs.key==rhs.key }
    var body: some View { content() }
}
struct LiveFramePanel<Content:View>: View {
    @ObservedObject var clock:FrameClock
    let key:()->String
    @ViewBuilder var content:()->Content
    var body: some View {
        let _=clock.frame
        CachedLivePanel(key:key(),content:content).equatable()
    }
}
