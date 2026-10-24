import Foundation
import Darwin

func normalized(_ address: String) -> String {
    address.lowercased().filter { "0123456789abcdef".contains($0) }
}

struct Device: Codable, Identifiable, Hashable {
    var name: String
    var address: String
    var id: String { normalized(address) }
    var side: String { name.contains("(L)") ? "L" : name.contains("(R)") ? "R" : "" }
}
struct DeviceGroup: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var subtitle: String
    var kind: String
    var devices: [Device]
    var isJoyCon: Bool { kind == "joycon" || kind == "mobapad" }
}
enum RegistrationRules {
    static func makeGroup(devices: [Device], kind: String) throws -> DeviceGroup {
        guard ["joycon", "mobapad", "xbox", "generic"].contains(kind), !devices.isEmpty else {
            throw AppFailure("请选择设备及手柄类型。")
        }
        guard Set(devices.map(\.id)).count == devices.count,
              devices.allSatisfy({ $0.id.count == 12 && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AppFailure("设备地址无效或重复，请刷新后重试。")
        }
        let paired = kind == "joycon" || kind == "mobapad"
        if paired {
            guard devices.count <= 2, devices.allSatisfy({ !$0.side.isEmpty }),
                  Set(devices.map(\.side)).count == devices.count else {
                throw AppFailure("请选择一只左手柄、一只右手柄，或单独添加其中一只。")
            }
        } else if devices.count != 1 {
            throw AppFailure("这类手柄请一次添加一个设备。")
        }
        let name = kind == "joycon" ? "Nintendo Joy-Con" : kind == "mobapad" ? "Mobapad M6 HD" : kind == "xbox" ? "Xbox" : devices[0].name
        return .init(id: UUID().uuidString, name: name, subtitle: "已登记 · 蓝牙手柄", kind: kind, devices: devices.sorted { $0.side < $1.side })
    }
}
struct Inventory: Sendable {
    var online: Set<String> = []
    var paired: [Device] = []
    var lowEnergy: Set<String> = []
    var verified = false
    var error: String?
}
enum InventoryParser {
    static func systemBluetooth(_ data: Data) throws -> Inventory {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let adapters = object["SPBluetoothDataType"] as? [[String: Any]], !adapters.isEmpty else {
            throw AppFailure("暂时无法读取系统蓝牙状态。")
        }
        var result = Inventory()
        var devices: [String: Device] = [:]
        for adapter in adapters {
            for section in ["device_connected", "device_not_connected"] {
                for item in adapter[section] as? [[String: [String: Any]]] ?? [] {
                    for (name, value) in item {
                        guard let address = value["device_address"] as? String,
                              normalized(address).count == 12 else { continue }
                        let device = Device(name: name, address: address)
                        devices[device.id] = device
                        if section == "device_connected" {
                            result.online.insert(device.id)
                            if (value["device_services"] as? String ?? "").contains("BLE") { result.lowEnergy.insert(device.id) }
                        }
                    }
                }
            }
        }
        result.paired = devices.values.sorted { $0.id < $1.id }
        result.verified = true
        return result
    }
}
enum ConnectionRules {
    static func online(system: Set<String>, hid: Set<String>) -> Set<String> { system.union(hid) }
    static func mayRePair(id: String, inventory: Inventory) -> Bool {
        inventory.verified && !inventory.online.contains(normalized(id))
    }
}
struct AppFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

// Each invocation is bounded. No shell interpolation or system-wide Bluetooth changes.
func runProcess(_ executable: String, _ arguments: [String], timeout: Double = 12) throws -> (Int32, Data) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = arguments
    let output = Pipe(), errors = Pipe()
    task.standardOutput = output
    task.standardError = errors
    try task.run()
    let expiration = DispatchWorkItem {
        if task.isRunning {
            task.terminate()
            DispatchQueue.global().asyncAfter(deadline:.now()+1) {
                if task.isRunning { kill(task.processIdentifier,SIGKILL) }
            }
        }
    }
    DispatchQueue.global().asyncAfter(deadline:.now()+timeout,execute:expiration)
    // Drain stdout while the child is running, including large system_profiler reports.
    let data = output.fileHandleForReading.readDataToEndOfFile()
    // Both tools emit only short errors; discard separately to keep error text out of the UI.
    _ = errors.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    expiration.cancel()
    guard task.terminationReason == .exit else { throw AppFailure("操作超时，请确认手柄已开机并靠近 Mac。") }
    return (task.terminationStatus, data)
}

actor BluetoothService {
    var tool: String { Bundle.main.resourceURL!.appendingPathComponent("blueutil").path }
    func blue(_ arguments: [String], timeout: Double = 12) throws -> (Int32, Data) {
        try runProcess(tool, arguments, timeout: timeout)
    }
    func inventory() -> Inventory {
        var result = Inventory()
        do {
            let (status, data) = try runProcess("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"], timeout: 15)
            guard status == 0 else { throw AppFailure("暂时无法读取系统蓝牙状态。") }
            result = try InventoryParser.systemBluetooth(data)
        } catch { result.error = error.localizedDescription }
        // The HID registry is a second independent source. blueutil can falsely report a live Joy-Con as disconnected.
        if let (status, data) = try? runProcess("/usr/sbin/ioreg", ["-a", "-r", "-c", "IOHIDDevice"]), status == 0,
           let roots = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] {
            func visit(_ entry: [String: Any]) {
                if let serial = entry["SerialNumber"] as? String,
                   let vendor = entry["VendorID"] as? Int, vendor == 0x057e {
                    result.online.insert(normalized(serial))
                }
                for child in entry["IORegistryEntryChildren"] as? [[String: Any]] ?? [] { visit(child) }
            }
            for root in roots { visit(root) }
        }
        // A verified system report already includes connected and saved devices.
        // Avoid blocking first-run UI on IOBluetooth initialization in a helper.
        if !result.verified, let (status, data) = try? blue(["--paired", "--format", "json"], timeout: 3), status == 0,
           let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            let reported: [Device] = items.compactMap {
                guard let a = $0["address"] as? String else { return nil }
                return Device(name: $0["name"] as? String ?? "蓝牙设备", address: a)
            }
            var merged = Dictionary(result.paired.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for device in reported { merged[device.id] = device }
            result.paired = merged.values.sorted { $0.id < $1.id }
        }
        return result
    }
    func waitOnline(_ devices: [Device], desired: Bool, seconds: Double = 5, stableSeconds:Double = 0) async -> Inventory {
        let deadline = Date().addingTimeInterval(seconds)
        var latest = Inventory()
        var stableSince:Date?
        repeat {
            latest = inventory()
            if latest.verified && devices.allSatisfy({ latest.online.contains($0.id) == desired }) {
                if stableSince == nil { stableSince=Date() }
                if Date().timeIntervalSince(stableSince!)>=stableSeconds { return latest }
            } else { stableSince=nil }
            if Task.isCancelled { return latest }
            try? await Task.sleep(for: .milliseconds(600))
        } while Date() < deadline
        return latest
    }
    func manageGroup(_ target: DeviceGroup, disconnectOnly: Bool = false,
                     progress: @escaping @MainActor @Sendable (String) -> Void) async throws -> Inventory {
        let before = inventory()
        guard before.verified else { throw AppFailure(before.error ?? "系统状态尚未确认，请稍后重试。") }
        if disconnectOnly {
            for device in target.devices where before.online.contains(device.id) {
                try Task.checkCancellation()
                await progress("正在断开 \(device.name)…")
                _ = try? blue(["--disconnect", device.address], timeout: 8)
            }
            let result=await waitOnline(target.devices,desired:false,seconds:4)
            guard result.verified else { throw AppFailure("无法确认断开结果，请刷新后重试。") }
            if let still=target.devices.first(where:{result.online.contains($0.id)}) {
                if before.lowEnergy.contains(still.id) {
                    throw AppFailure("\(still.name) 使用 BLE，当前接口未能断开。请在系统蓝牙里点它的详情，再点「断开连接」；无需忽略或重新配对。")
                }
                throw AppFailure("\(still.name) 仍保持连接。请在系统蓝牙中断开，或长按手柄电源键关闭；无需忽略设备。")
            }
            return result
        }
        // Both Joy-Con halves must be waiting while the user presses both SYNC buttons.
        try await withThrowingTaskGroup(of:Void.self) { tasks in
            for device in target.devices where !before.online.contains(device.id) {
                tasks.addTask {
                    let worker=BluetoothService()
                    try await worker.connectDevice(device,progress:progress)
                }
            }
            for try await _ in tasks {}
        }
        try Task.checkCancellation()
        await progress("正在核对最终连接状态…")
        let final = await waitOnline(target.devices, desired: true, seconds: 6, stableSeconds:2)
        guard final.verified else { throw AppFailure("系统连接状态尚未确认，请刷新检查。") }
        let missing = target.devices.filter { !final.online.contains($0.id) }
        guard missing.isEmpty else {
            throw AppFailure("尚未连接：\(missing.map(\.name).joined(separator: "、"))。请再点「补全连接」，并长按这些手柄的 SYNC。已经连接的左右手柄会保留。")
        }
        return final
    }
    private func connectDevice(_ device:Device,progress:@escaping @MainActor @Sendable (String)->Void) async throws {
            try Task.checkCancellation()
            var current = inventory()
            if current.online.contains(device.id) { return }
            await progress("正在连接 \(device.name)。刚用过其他主机？现在长按 SYNC，直到指示灯滚动闪烁。")
            _ = try? blue(["--connect", device.address], timeout: 5)
            current = await waitOnline([device], desired: true, seconds: 3)
            if current.online.contains(device.id) { return }
            try Task.checkCancellation()
            // Only a confirmed offline target may have its stale pairing replaced.
            guard ConnectionRules.mayRePair(id: device.id, inventory: current) else {
                throw AppFailure("连接状态尚未确认，已保留当前配对。请刷新后重试。")
            }
            await progress("等待 \(device.name) 的同步信号。请长按 SYNC 直到闪灯，其他手柄会保持连接。")
            if current.paired.contains(where: { $0.id == device.id }) {
                let (status, _) = try blue(["--unpair", device.address], timeout: 8)
                guard status == 0 else { throw AppFailure("无法更新 \(device.name) 的配对，请重试。") }
            }
            let deadline=Date().addingTimeInterval(55)
            repeat {
                try Task.checkCancellation()
                _ = try? blue(["--pair", device.address], timeout: 18)
                try Task.checkCancellation()
                current = await waitOnline([device], desired: true, seconds: 2)
                if current.online.contains(device.id) { break }
                if current.paired.contains(where:{$0.id==device.id}) {
                    _ = try? blue(["--connect", device.address], timeout: 6)
                    current=await waitOnline([device],desired:true,seconds:2)
                    if current.online.contains(device.id) { break }
                }
                try await Task.sleep(for:.seconds(1))
            } while Date()<deadline
    }
}

struct Vector3: Codable {
    var x = 0.0, y = 0.0, z = 0.0
    init(_ values: [Double] = []) { x = values.count > 0 ? values[0] : 0; y = values.count > 1 ? values[1] : 0; z = values.count > 2 ? values[2] : 0 }
    var values: [Double] { [x,y,z] }
    var magnitude: Double { sqrt(x*x+y*y+z*z) }
    static func - (lhs: Self, rhs: Self) -> Self { .init(zip(lhs.values,rhs.values).map(-)) }
}
struct RestCalibration {
    static func bias(samples: [Vector3], gravity: [Double]) throws -> Vector3 {
        guard samples.count >= 90, gravity.count == samples.count else { throw AppFailure("采样不足，请保持连接后重试。") }
        guard gravity.allSatisfy({ (0.8...1.2).contains($0) }) else { throw AppFailure("请将手柄平放在稳定桌面上，再开始校准。") }
        let means = (0..<3).map { axis in samples.reduce(0) { $0 + $1.values[axis] } / Double(samples.count) }
        for axis in 0..<3 {
            let variance = samples.reduce(0) { $0 + pow($1.values[axis]-means[axis],2) } / Double(samples.count)
            guard sqrt(variance) < 1.0, abs(means[axis]) < 8 else { throw AppFailure("检测到移动，校准未应用。请放稳后重试。") }
        }
        return .init(means)
    }
}
