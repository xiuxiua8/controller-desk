import SwiftUI
import WebKit

struct VectorControllerPreview: NSViewRepresentable {
    var resourceName="xbox-preview"
    let provider:()->InputState
    final class Coordinator:NSObject,WKNavigationDelegate {
        var provider:()->InputState={InputState()}
        var previous=""
        var ready=false
        var inFlight=false
        var timer:Timer?
        deinit { timer?.invalidate() }
        func start(_ view:WKWebView) {
            timer=Timer(timeInterval:1.0/60,repeats:true) { [weak self,weak view] _ in
                MainActor.assumeIsolated { if let self,let view { self.update(view) } }
            }
            RunLoop.main.add(timer!,forMode:.common)
        }
        func update(_ view:WKWebView) {
            guard ready,!inFlight else { return }
            let input=provider()
            let object:[String:Any] = ["buttons":input.buttons.sorted(),"left":[input.left.x,input.left.y],"right":[input.right.x,input.right.y],"lt":input.lt,"rt":input.rt,"acceleration":input.sideAcceleration.mapValues { $0.values }]
            guard let data=try? JSONSerialization.data(withJSONObject:object,options:.sortedKeys),let text=String(data:data,encoding:.utf8),text != previous else { return }
            previous=text;inFlight=true
            view.evaluateJavaScript("window.updateController(\(text))") { [weak self] _,error in
                self?.inFlight=false
                if let error { NSLog("Controller preview update error: %@",error.localizedDescription) }
            }
        }
        func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
            ready=true
            update(webView)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context:Context) -> WKWebView {
        let config=WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view=WKWebView(frame:.zero,configuration:config)
        view.setValue(false,forKey:"drawsBackground")
        view.navigationDelegate=context.coordinator
        context.coordinator.provider=provider
        context.coordinator.start(view)
        if let url=Bundle.main.url(forResource:resourceName,withExtension:"html"),let html=try? String(contentsOf:url,encoding:.utf8) {
            view.loadHTMLString(html,baseURL:nil)
        }
        return view
    }
    func updateNSView(_ view:WKWebView,context:Context) {
        context.coordinator.provider=provider
    }
    static func dismantleNSView(_ view:WKWebView,coordinator:Coordinator) {
        coordinator.timer?.invalidate();coordinator.ready=false
    }
}
