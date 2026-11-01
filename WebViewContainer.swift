import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var currentURL: URL?
    
    let webView: WKWebView
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.bounces = true
        webView.backgroundColor = UIColor(red: 0.035, green: 0.035, blue: 0.051, alpha: 1.0)
        webView.isOpaque = false
        webView.allowsBackForwardNavigationGestures = true
        
        let targetURL = URL(string: "https://heartivelovestv.pages.dev")!
        let request = URLRequest(url: targetURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            parent.currentURL = webView.url
            
            // Seamlessly hide duplicate web navigation bar so the native bottom bar is the single clean bar
            let js = """
            (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                    .tabbar { display: none !important; }
                    body { padding-bottom: 0 !important; }
                    #view { padding-bottom: 24px !important; }
                `;
                document.head.appendChild(style);
                
                var meta = document.querySelector('meta[name="viewport"]');
                if (meta) {
                    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
