import SwiftUI
import WebKit

struct ContentView: View {
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = true
    @State private var currentURL: URL? = nil
    @State private var selectedTab: String = "home"
    
    // Heartive Theme Colors
    private let heartiveBg = Color(red: 0.035, green: 0.035, blue: 0.051) // #09090d
    private let heartiveAccent = Color(red: 1.0, green: 0.647, blue: 0.0) // Orange #ffa500
    private let heartiveSurface = Color(red: 0.082, green: 0.082, blue: 0.114) // #15151d
    
    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        return WKWebView(frame: .zero, configuration: config)
    }()
    
    var body: some View {
        ZStack {
            heartiveBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Heartive Top Bar
                HStack(spacing: 12) {
                    // Back button if webView can go back
                    if canGoBack {
                        Button {
                            webView.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                    
                    // Brand Logo + Title
                    HStack(spacing: 8) {
                        Image("AppIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .cornerRadius(6)
                        
                        Text("Heartive")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Action Buttons: Surprise Me & Refresh
                    HStack(spacing: 8) {
                        Button {
                            navigate(to: "#/surprise")
                            let js = "window.location.hash = '#/'; setTimeout(() => { const b = document.querySelector('[data-menu=\"surprise\"], #surpriseBtn'); if(b) b.click(); }, 300);"
                            webView.evaluateJavaScript(js, completionHandler: nil)
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        
                        Button {
                            if isLoading {
                                webView.stopLoading()
                            } else {
                                webView.reload()
                            }
                        } label: {
                            Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(heartiveBg)
                
                // Loading bar
                if isLoading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: heartiveAccent))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
                
                // Embedded Web Application
                WebViewContainer(
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isLoading: $isLoading,
                    currentURL: $currentURL,
                    webView: webView
                )
                
                // Native Heartive Mobile Navigation Bar
                HStack(spacing: 0) {
                    tabItem(id: "home", title: "Home", icon: "house.fill", route: "#/")
                    tabItem(id: "movies", title: "Movies", icon: "film", route: "#/movies")
                    tabItem(id: "tv", title: "Series", icon: "tv", route: "#/tv")
                    tabItem(id: "search", title: "Search", icon: "magnifyingglass", route: "#/search")
                    tabItem(id: "list", title: "My List", icon: "bookmark.fill", route: "#/list")
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
                .background(heartiveSurface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.08)), alignment: .top)
            }
        }
    }
    
    private func tabItem(id: String, title: String, icon: String, route: String) -> some View {
        Button {
            selectedTab = id
            navigate(to: route)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(selectedTab == id ? heartiveAccent : Color.gray)
            .frame(maxWidth: .infinity)
        }
    }
    
    private func navigate(to route: String) {
        let js = "window.location.hash = '\(route)';"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
