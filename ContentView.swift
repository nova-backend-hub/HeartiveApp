import SwiftUI
import WebKit

struct CastMedia: Equatable {
    var type: String
    var id: Int
    var season: Int
    var episode: Int
    var title: String
}

final class TvCastController: ObservableObject {
    @Published var tvAddress: String {
        didSet { UserDefaults.standard.set(tvAddress, forKey: "heartive.tvAddress") }
    }
    @Published var autoCastOnPlay: Bool {
        didSet { UserDefaults.standard.set(autoCastOnPlay, forKey: "heartive.autoCast") }
    }
    @Published var isConnected: Bool = false
    @Published var tvName: String = "SmartTV"
    @Published var tvInstalled: Bool = false
    @Published var statusText: String = "Tap Connect TV"
    @Published var toastText: String? = nil
    @Published var volumeLevel: Int? = nil
    @Published var volumeMuted: Bool = false
    @Published var currentMedia: CastMedia? = nil
    @Published var isBusy: Bool = false
    @Published var showTvSheet: Bool = false

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 4
        cfg.timeoutIntervalForResource = 6
        return URLSession(configuration: cfg)
    }()

    init() {
        let saved = UserDefaults.standard.string(forKey: "heartive.tvAddress")
        self.tvAddress = (saved?.isEmpty == false) ? saved! : "192.168.1.115:5400"
        self.autoCastOnPlay = UserDefaults.standard.bool(forKey: "heartive.autoCast")
        checkStatus()
    }

    private var baseUrl: String {
        var s = tvAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = "192.168.1.115:5400" }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            s = "http://" + s
        }
        if let u = URL(string: s), u.port == nil {
            s += ":5400"
        }
        return s.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func showToast(_ text: String) {
        DispatchQueue.main.async {
            self.toastText = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                if self.toastText == text {
                    self.toastText = nil
                }
            }
        }
    }

    func handleWebMessage(_ body: [String: Any]) {
        let event = body["event"] as? String ?? ""
        if event == "mediaCleared" {
            DispatchQueue.main.async { self.currentMedia = nil }
            return
        }
        let type = (body["type"] as? String ?? "movie").lowercased()
        let id = (body["id"] as? NSNumber)?.intValue ?? 0
        let season = (body["season"] as? NSNumber)?.intValue ?? 0
        let episode = (body["episode"] as? NSNumber)?.intValue ?? 0
        let title = (body["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard id > 0 || !title.isEmpty else { return }

        let media = CastMedia(type: type, id: id, season: season, episode: episode, title: title)
        DispatchQueue.main.async {
            self.currentMedia = media
            if event == "autoPlay" {
                self.castMedia(media)
            }
        }
    }

    func checkStatus() {
        guard let url = URL(string: baseUrl + "/api/heartive/status") else {
            statusText = "Invalid TV address"
            return
        }
        isBusy = true
        session.dataTask(with: url) { data, resp, err in
            DispatchQueue.main.async {
                self.isBusy = false
                if let err = err {
                    self.isConnected = false
                    self.statusText = "Offline: \(err.localizedDescription)"
                    return
                }
                guard let data = data,
                      let http = resp as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.isConnected = false
                    self.statusText = "TV did not respond"
                    return
                }
                self.isConnected = (obj["ok"] as? Bool) == true
                self.tvInstalled = (obj["installed"] as? Bool) == true
                if let name = obj["tv_name"] as? String, !name.isEmpty {
                    self.tvName = name
                }
                if let vol = obj["volume"] as? [String: Any] {
                    self.volumeLevel = (vol["level"] as? NSNumber)?.intValue
                    self.volumeMuted = (vol["muted"] as? Bool) == true
                }
                self.statusText = self.isConnected
                    ? "Connected to \(self.tvName)" + (self.tvInstalled ? " • Heartive ready" : "")
                    : "Tap Connect TV"
            }
        }.resume()
    }

    func castMedia(_ media: CastMedia) {
        var payload: [String: Any] = ["action": "play", "type": media.type]
        if media.id > 0 { payload["id"] = media.id }
        if !media.title.isEmpty { payload["title"] = media.title }
        if media.season > 0 { payload["season"] = media.season }
        if media.episode > 0 { payload["episode"] = media.episode }
        let label = media.title.isEmpty ? "#\(media.id)" : media.title
        sendCast(payload: payload, successToast: "Playing \"\(label)\" on TV")
    }

    func castQuery(title: String, type: String = "", season: Int = 0, episode: Int = 0) {
        let q = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        var payload: [String: Any] = ["action": "play", "title": q]
        if !type.isEmpty { payload["type"] = type }
        if season > 0 { payload["season"] = season }
        if episode > 0 { payload["episode"] = episode }
        sendCast(payload: payload, successToast: "Playing \"\(q)\" on TV")
    }

    func sendAction(_ action: String, extra: [String: Any] = [:], toast: String? = nil) {
        var payload: [String: Any] = ["action": action]
        for (k, v) in extra { payload[k] = v }
        sendCast(payload: payload, successToast: toast)
    }

    private func sendCast(payload: [String: Any], successToast: String?) {
        guard let url = URL(string: baseUrl + "/api/heartive/cast"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            showToast("Invalid TV URL")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        session.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async {
                if let err = err {
                    self.isConnected = false
                    self.showToast("TV error: \(err.localizedDescription)")
                    return
                }
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    self.showToast("TV rejected command")
                    return
                }
                self.isConnected = true
                if let data = data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let lvl = (obj["level"] as? NSNumber)?.intValue {
                        self.volumeLevel = lvl
                    }
                    if let muted = obj["muted"] as? Bool {
                        self.volumeMuted = muted
                    }
                }
                if let t = successToast {
                    self.showToast(t)
                }
            }
        }.resume()
    }
}

struct ContentView: View {
    @StateObject private var tv = TvCastController()
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = true
    @State private var currentURL: URL? = nil
    @State private var selectedTab: String = "home"
    @State private var quickTitle: String = ""
    @State private var quickType: String = ""
    @State private var quickSeason: String = ""
    @State private var quickEpisode: String = ""

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
                HStack(spacing: 10) {
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

                    // Connect TV Button
                    Button {
                        tv.checkStatus()
                        tv.showTvSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tv.isConnected ? Color.green : heartiveAccent)
                                .frame(width: 8, height: 8)
                            Image(systemName: "tv.and.mediabox")
                                .font(.system(size: 13, weight: .semibold))
                            Text(tv.isConnected ? "TV Connected" : "Connect TV")
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(tv.isConnected ? Color.green.opacity(0.2) : heartiveAccent.opacity(0.22))
                        .overlay(
                            Capsule().stroke(tv.isConnected ? Color.green.opacity(0.55) : heartiveAccent.opacity(0.6), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }

                    // Surprise Me & Refresh
                    HStack(spacing: 6) {
                        Button {
                            navigate(to: "#/surprise")
                            let js = "window.location.hash = '#/'; setTimeout(() => { const b = document.querySelector('[data-menu=\"surprise\"], #surpriseBtn'); if(b) b.click(); }, 300);"
                            webView.evaluateJavaScript(js, completionHandler: nil)
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 32, height: 32)
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
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(heartiveBg)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: heartiveAccent))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }

                // Embedded Web Application + Floating Watch on TV Pill
                ZStack(alignment: .bottom) {
                    WebViewContainer(
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        isLoading: $isLoading,
                        currentURL: $currentURL,
                        webView: webView,
                        autoCast: tv.autoCastOnPlay,
                        onBridgeMessage: { msg in
                            tv.handleWebMessage(msg)
                        }
                    )

                    if let media = tv.currentMedia {
                        Button {
                            tv.castMedia(media)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "tv.fill")
                                    .font(.system(size: 15, weight: .bold))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Play on TV")
                                        .font(.system(size: 13, weight: .heavy))
                                    Text(media.title.isEmpty ? "\(media.type.uppercased()) #\(media.id)" : media.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(heartiveAccent)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }

                    if let toast = tv.toastText {
                        VStack {
                            Text(toast)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.85))
                                .clipShape(Capsule())
                                .padding(.top, 10)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }

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
        .sheet(isPresented: $tv.showTvSheet) {
            tvRemoteSheet
        }
    }

    private var tvRemoteSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Connection Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle()
                                .fill(tv.isConnected ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)
                            Text(tv.statusText)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            if tv.isBusy { ProgressView() }
                        }

                        Text("TV Address (Couch TV)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)

                        HStack(spacing: 8) {
                            TextField("192.168.1.115:5400", text: $tv.tvAddress)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                .foregroundColor(.white)

                            Button {
                                tv.checkStatus()
                            } label: {
                                Text("Connect")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(heartiveAccent)
                                    .cornerRadius(10)
                            }
                        }

                        Toggle("Auto-cast to TV when pressing Play", isOn: $tv.autoCastOnPlay)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .tint(heartiveAccent)
                    }
                    .padding(14)
                    .background(heartiveSurface)
                    .cornerRadius(16)

                    // Play Selected Page Item
                    if let media = tv.currentMedia {
                        Button {
                            tv.castMedia(media)
                        } label: {
                            HStack {
                                Image(systemName: "play.tv.fill")
                                Text("Play \"\(media.title.isEmpty ? "#\(media.id)" : media.title)\" on TV")
                                    .fontWeight(.bold)
                                Spacer()
                                Image(systemName: "arrow.up.right.circle.fill")
                            }
                            .foregroundColor(.black)
                            .padding(14)
                            .background(heartiveAccent)
                            .cornerRadius(14)
                        }
                    }

                    // Play Any Movie or Show Directly on TV
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Play Any Show or Movie on TV")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)

                        TextField("Movie or Show Title (e.g. The Mentalist)", text: $quickTitle)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        HStack(spacing: 8) {
                            TextField("Season", text: $quickSeason)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                .foregroundColor(.white)

                            TextField("Episode", text: $quickEpisode)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }

                        Button {
                            tv.castQuery(
                                title: quickTitle,
                                type: (Int(quickSeason) ?? 0) > 0 ? "tv" : quickType,
                                season: Int(quickSeason) ?? 0,
                                episode: Int(quickEpisode) ?? 0
                            )
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play Directly in Heartive TV")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundColor(.black)
                            .background(quickTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : heartiveAccent)
                            .cornerRadius(12)
                        }
                        .disabled(quickTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(14)
                    .background(heartiveSurface)
                    .cornerRadius(16)

                    // Playback & Volume Controls on TV
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("TV Player & Volume")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            if let lvl = tv.volumeLevel {
                                Text(tv.volumeMuted ? "Muted" : "Vol \(lvl)%")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack(spacing: 8) {
                            remoteButton(title: "Prev Ep", icon: "backward.end.fill") {
                                tv.sendAction("prev_ep", toast: "Previous episode")
                            }
                            remoteButton(title: "Source", icon: "arrow.triangle.2.circlepath") {
                                tv.sendAction("next_source", toast: "Switching stream source")
                            }
                            remoteButton(title: "Next Ep", icon: "forward.end.fill") {
                                tv.sendAction("next_ep", toast: "Next episode")
                            }
                        }

                        HStack(spacing: 8) {
                            remoteButton(title: "Vol -", icon: "speaker.wave.1.fill") {
                                tv.sendAction("volume", extra: ["key": "volume_down"])
                            }
                            remoteButton(title: "Mute", icon: "speaker.slash.fill") {
                                tv.sendAction("volume", extra: ["key": "mute"])
                            }
                            remoteButton(title: "Vol +", icon: "speaker.wave.3.fill") {
                                tv.sendAction("volume", extra: ["key": "volume_up"])
                            }
                        }

                        remoteButton(title: "Close TV Player", icon: "xmark.circle.fill") {
                            tv.sendAction("close_player", toast: "Closed player on TV")
                        }
                    }
                    .padding(14)
                    .background(heartiveSurface)
                    .cornerRadius(16)
                }
                .padding(16)
            }
            .background(heartiveBg.ignoresSafeArea())
            .navigationTitle("Heartive TV Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { tv.showTvSheet = false }
                        .foregroundColor(heartiveAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func remoteButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.09))
            .cornerRadius(10)
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

