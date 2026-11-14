import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var currentURL: URL?

    let webView: WKWebView
    var autoCast: Bool = false
    var onBridgeMessage: (([String: Any]) -> Void)? = nil

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

        let ucc = webView.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: "heartiveCast")
        ucc.add(WeakCastHandler(coordinator: context.coordinator), name: "heartiveCast")

        let targetURL = URL(string: "https://heartive.pages.dev")!
        let request = URLRequest(url: targetURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        uiView.evaluateJavaScript("window.__heartiveAutoCast = \(autoCast ? "true" : "false");", completionHandler: nil)
    }

    class WeakCastHandler: NSObject, WKScriptMessageHandler {
        weak var coordinator: Coordinator?
        init(coordinator: Coordinator) { self.coordinator = coordinator }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "heartiveCast", let body = message.body as? [String: Any] else { return }
            coordinator?.parent.onBridgeMessage?(body)
        }
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

            let js = """
            (function() {
                if (!document.getElementById('heartive-ios-style')) {
                    var style = document.createElement('style');
                    style.id = 'heartive-ios-style';
                    style.innerHTML = `
                        .tabbar { display: none !important; }
                        body { padding-bottom: 0 !important; }
                        #view { padding-bottom: 84px !important; }
                        .heartive-tv-cast-btn {
                            display: inline-flex; align-items: center; gap: 6px;
                            padding: 9px 14px; border-radius: 12px; border: 1px solid rgba(255,165,0,0.5);
                            background: linear-gradient(135deg, rgba(255,165,0,0.22), rgba(255,120,0,0.16));
                            color: #ffb833; font-weight: 700; font-size: 13px; cursor: pointer;
                        }
                    `;
                    document.head.appendChild(style);
                }

                var meta = document.querySelector('meta[name="viewport"]');
                if (meta) {
                    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
                }

                function post(payload) {
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heartiveCast) {
                            window.webkit.messageHandlers.heartiveCast.postMessage(payload);
                        }
                    } catch (e) {}
                }

                function guessTitle() {
                    var el = document.querySelector('#view h1, .hero-title, .detail-title, .title, h1');
                    var t = el ? (el.textContent || '').trim() : '';
                    if (!t && document.title) t = document.title.replace(/\\s*[-|•].*$/, '').trim();
                    return t || '';
                }

                function reportRouteMedia() {
                    var h = window.location.hash || '';
                    var m = h.match(/^#\\/(movie|tv)\\/(\\d+)(?:\\/season\\/(\\d+))?/);
                    if (m) {
                        var payload = {
                            event: 'mediaChanged',
                            type: m[1],
                            id: Number(m[2]),
                            season: m[3] ? Number(m[3]) : 0,
                            episode: 0,
                            title: guessTitle()
                        };
                        window.__heartiveLastMedia = payload;
                        post(payload);
                    } else {
                        window.__heartiveLastMedia = null;
                        post({ event: 'mediaCleared' });
                    }
                }

                if (!window.__heartiveCastHooked) {
                    window.__heartiveCastHooked = true;
                    window.addEventListener('hashchange', function() {
                        setTimeout(reportRouteMedia, 250);
                        setTimeout(reportRouteMedia, 800);
                    });

                    document.addEventListener('click', function(ev) {
                        var epBtn = ev.target && ev.target.closest ? ev.target.closest('[data-play-ep]') : null;
                        if (epBtn) {
                            var parts = String(epBtn.getAttribute('data-play-ep') || '').split(':');
                            var epPayload = {
                                event: window.__heartiveAutoCast ? 'autoPlay' : 'mediaChanged',
                                type: 'tv',
                                id: Number(parts[0] || 0),
                                season: Number(parts[1] || 1),
                                episode: Number(parts[2] || 1),
                                title: guessTitle()
                            };
                            window.__heartiveLastMedia = epPayload;
                            post(epPayload);
                            if (window.__heartiveAutoCast) { ev.preventDefault(); ev.stopPropagation(); }
                            return;
                        }
                        var plBtn = ev.target && ev.target.closest ? ev.target.closest('[data-play]') : null;
                        if (plBtn) {
                            var raw = String(plBtn.getAttribute('data-play') || '').split(':');
                            var mPayload = {
                                event: window.__heartiveAutoCast ? 'autoPlay' : 'mediaChanged',
                                type: raw[0] || 'movie',
                                id: Number(raw[1] || 0),
                                season: 0,
                                episode: 0,
                                title: (plBtn.getAttribute('data-title') || guessTitle())
                            };
                            window.__heartiveLastMedia = mPayload;
                            post(mPayload);
                            if (window.__heartiveAutoCast) { ev.preventDefault(); ev.stopPropagation(); }
                        }
                    }, true);

                    var hookTimer = setInterval(function() {
                        if (window.SM && window.SM.player && window.SM.player.play && !window.SM.player.__castWrapped) {
                            var origPlay = window.SM.player.play.bind(window.SM.player);
                            window.SM.player.play = function(item, opts) {
                                var p = {
                                    event: window.__heartiveAutoCast ? 'autoPlay' : 'mediaChanged',
                                    type: (item && item.type) || 'movie',
                                    id: Number((item && item.id) || 0),
                                    season: Number((opts && opts.season) || 0),
                                    episode: Number((opts && opts.episode) || 0),
                                    title: guessTitle()
                                };
                                window.__heartiveLastMedia = p;
                                post(p);
                                if (window.__heartiveAutoCast) return Promise.resolve();
                                return origPlay(item, opts);
                            };
                            window.SM.player.__castWrapped = true;
                            clearInterval(hookTimer);
                        }
                    }, 250);
                    setTimeout(function() { clearInterval(hookTimer); }, 10000);
                }

                setTimeout(reportRouteMedia, 350);
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
