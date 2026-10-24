import AppKit
import SwiftUI
import CoreBluetooth

final class AppDelegate: NSObject, NSApplicationDelegate, CBCentralManagerDelegate {
    private var bluetooth: CBCentralManager?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { true }
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.activate(ignoringOtherApps:true)
        // Request this app's Bluetooth permission directly, before spawning helpers.
        bluetooth = CBCentralManager(delegate:self,queue:nil,options:[CBCentralManagerOptionShowPowerAlertKey:false])
    }
    func centralManagerDidUpdateState(_ central:CBCentralManager) {}
}
@main struct ControllerDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup("Controller Desk") { RootView() }
            .defaultSize(width:1180,height:850)
            .windowStyle(.hiddenTitleBar)
            .commands {
                CommandGroup(replacing:.newItem) {}
                CommandGroup(replacing:.appInfo) {
                    Button("关于Controller Desk") { NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Controller Desk",.applicationVersion:"1.1.1",.credits:NSAttributedString(string:"本地手柄管理与实时测试\nSwiftUI · GameController · HID")]) }
                }
            }
    }
}
