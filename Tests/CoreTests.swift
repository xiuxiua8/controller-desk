import Foundation
@main struct CoreTests {
    static func main() throws {
        func check(_ condition:Bool,_ name:String) { precondition(condition,name); print("PASS \(name)") }
        check(normalized("02:00:00:00:00:01")==normalized("02-00-00-00-00-01"),"address identity")
        let report = Data(#"{"SPBluetoothDataType":[{"device_connected":[{"Xbox Wireless Controller":{"device_address":"02:00:00:00:00:01","device_services":"BLE"}}],"device_not_connected":[{"Joy-Con (R)":{"device_address":"02:00:00:00:00:02"}}]}]}"#.utf8)
        let parsed = try InventoryParser.systemBluetooth(report)
        check(parsed.verified && parsed.paired.count == 2, "first-run inventory survives unavailable Bluetooth helper")
        check(parsed.online == ["020000000001"] && parsed.lowEnergy == parsed.online, "offline paired devices are never marked connected")
        let id="020000000001"
        let online=ConnectionRules.online(system:[],hid:[id])
        check(online.contains(id),"live HID survives a Bluetooth false negative")
        var snapshot=Inventory(online:online,verified:true)
        check(!ConnectionRules.mayRePair(id:id,inventory:snapshot),"never re-pair an online controller")
        snapshot.online=[]; snapshot.verified=false
        check(!ConnectionRules.mayRePair(id:id,inventory:snapshot),"unknown state never permits unpair")
        snapshot.verified=true
        check(ConnectionRules.mayRePair(id:id,inventory:snapshot),"verified offline allows explicit repair")
        let left=Device(name:"Joy-Con (L)",address:"02-00-00-00-00-01")
        let right=Device(name:"Joy-Con (R)",address:"02-00-00-00-00-02")
        let pair=try RegistrationRules.makeGroup(devices:[right,left],kind:"mobapad")
        check(pair.kind=="mobapad" && pair.devices.map(\.side)==["L","R"],"new user can register a correctly ordered Joy-Con pair")
        let single=try RegistrationRules.makeGroup(devices:[right],kind:"joycon")
        check(single.devices.count==1,"a standalone Joy-Con can be registered")
        for invalid in [[left,left],[left,Device(name:"Joy-Con (L)",address:"02-00-00-00-00-03")],[]] {
            var refused=false
            do { _=try RegistrationRules.makeGroup(devices:invalid,kind:"joycon") } catch {refused=true}
            check(refused,"invalid or duplicate Joy-Con group is rejected")
        }
        var invalidXbox=false
        do { _=try RegistrationRules.makeGroup(devices:[left,right],kind:"xbox") } catch {invalidXbox=true}
        check(invalidXbox,"independent controllers cannot be combined accidentally")
        let samples=(0..<120).map { i in Vector3([0.67+sin(Double(i))*0.1,-0.96,0.08]) }
        let bias=try RestCalibration.bias(samples:samples,gravity:Array(repeating:1,count:120))
        check(abs(bias.y+0.96)<0.001,"stationary bias retains sign and units")
        let corrected=Vector3([1,-2,0.5])-bias
        check(corrected.y < -1 && corrected.y > -1.1,"bias subtraction is symmetric")
        var rejected=false
        do { _=try RestCalibration.bias(samples:(0..<120).map { Vector3([Double($0%2)*10,0,0]) },gravity:Array(repeating:1,count:120)) } catch { rejected=true }
        check(rejected,"moving controller cannot be calibrated")
        rejected=false
        do { _=try RestCalibration.bias(samples:samples,gravity:Array(repeating:0,count:120)) } catch { rejected=true }
        check(rejected,"invalid accelerometer rejects calibration")
        let start=Date()
        do { _=try runProcess("/bin/sleep",["10"],timeout:0.2); fatalError("timeout did not fire") } catch {}
        check(Date().timeIntervalSince(start)<3,"blocked Bluetooth child has a bounded lifetime")
        let (status,data)=try runProcess("/bin/echo",["ok"])
        check(status==0 && String(data:data,encoding:.utf8)=="ok\n","process result is verified")
    }
}
