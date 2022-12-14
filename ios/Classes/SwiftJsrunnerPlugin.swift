import Flutter
import WebKit
import UIKit

public class SwiftJsrunnerPlugin: NSObject, FlutterPlugin {
    private let configuration: WKWebViewConfiguration = WKWebViewConfiguration()
    private let webView: WKWebView
    private let channel: FlutterMethodChannel
    private var restrictedSchemes = [String]()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "jsrunner", binaryMessenger: registrar.messenger())
        let instance = SwiftJsrunnerPlugin(withChannel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let method = CallMethod(rawValue: call.method) else { return }
        
        switch method {
        case .setOptions: setupOptions(call, result: result)
        case .evalJavascript: evalJavascript(call, result: result)
        case .loadHTML: loadHTML(call, result: result)
        case .loadUrl: loadUrl(call, result: result)
        case .callJS: callJS(call, result: result)
        case .respondToNative: respondToNative(call, result: result)
        }
    }
    
    init(withChannel channel: FlutterMethodChannel) {
        self.channel = channel
        webView = WKWebView(frame: CGRect(x: -1, y: -1, width: 1, height: 1), configuration: configuration)
        
        super.init()
        
        initWebView()
    }
    
    private func initWebView() {
        if #available(iOS 9.0, *) {
            configuration.allowsPictureInPictureMediaPlayback = false
            configuration.requiresUserActionForMediaPlayback = true
        }
        
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = .all
        }
        
        configuration.allowsInlineMediaPlayback = true
        
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        configuration.preferences = preferences
        
        configuration.userContentController.add(self, name: "native")
        webView.isHidden = true
        webView.navigationDelegate = self
    }
}

enum CallMethod: String {
    case setOptions = "setOptions"
    case evalJavascript = "evalJavascript"
    case loadHTML = "loadHTML"
    case loadUrl = "loadUrl"
    case callJS = "callJS"
    case respondToNative = "respondToNative"
}

extension SwiftJsrunnerPlugin: WKScriptMessageHandler, WKNavigationDelegate {
    
    private func setupOptions(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        defer { result(nil) }
        guard let arguments = call.arguments as? [String: Any] else { return }
        
        if let restrictedSchemes = arguments["restrictedSchemes"] as? [String] {
            self.restrictedSchemes = restrictedSchemes
        }
    }
    
    private func callJS(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let arguments = call.arguments as? [String: Any],
            let request = arguments["request"] as? String
        else { return result(nil) }
        
        validateWebView()
        
        let script = "window.callJS(\(request))"
        
        webView.evaluateJavaScript(script) { value, err in
            if let value = value {
                print("result \(value)")
            }
            
            if let err = err {
                print("error \(err)")
            }
            
            result(nil)
        }
    }
    
    private func respondToNative(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let arguments = call.arguments as? [String: Any],
            let response = arguments["response"] as? String
        else { return result(nil) }
        
        validateWebView()
        
        let script = "window.respondToNative(\(response))"
        
        webView.evaluateJavaScript(script) { value, err in
            if let value = value {
                print("result \(value)")
            }
            
            if let err = err {
                print("error \(err)")
            }
            
            result(nil)
        }
    }
    
    private func evalJavascript(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let arguments = call.arguments as? [String: Any],
            let script = arguments["script"] as? String
        else { return result(nil) }
        
        validateWebView()
        
        webView.evaluateJavaScript(script) { value, err in
            if let value = value {
                print("result \(value)")
            }
            
            if let err = err {
                print("error \(err)")
            }
            
            result(nil)
        }
    }
    
    private func loadHTML(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        defer { result(nil) }
        guard
            let arguments = call.arguments as? [String: Any],
            let html = arguments["html"] as? String
        else { return }
        
        validateWebView()
        
        if let baseUrlString = arguments["baseUrl"] as? String {
            webView.loadHTMLString(html, baseURL: URL(string: baseUrlString))
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    private func loadUrl(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        defer { result(nil) }
        guard
            let arguments = call.arguments as? [String: Any],
            let urlString = arguments["url"] as? String,
            let url = URL(string: urlString)
        else { return }
        
        validateWebView()
        
        webView.load(URLRequest(url: url))
    }
    
    private func validateWebView() {
        if webView.superview == nil {
            UIApplication.shared.keyWindow?.addSubview(webView)
        }
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        
        if let data = body.data(using: .utf8),
           let jsonObj = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
            channel.invokeMethod("didReceiveMessage", arguments: ["name": message.name, "data": jsonObj])
        } else {
            channel.invokeMethod("didReceiveMessage", arguments: ["name": message.name, "data": body])
        }
    }
    
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(decidePolicyForRequest(navigationAction.request))
    }
    
    private func decidePolicyForRequest(_ request: URLRequest) -> WKNavigationActionPolicy {
        if let url = request.url {
            let link = url.absoluteString
            
            // restrict schemes
            for l in restrictedSchemes {
                if link.contains(l) {
                    return .cancel
                }
            }
        }
        
        return .allow
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        channel.invokeMethod("stateChanged", arguments: ["type": "didStart", "url": webView.url!.absoluteString])
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        channel.invokeMethod("stateChanged", arguments: ["type": "didFinish", "url": webView.url!.absoluteString])
    }
}






