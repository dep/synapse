import SwiftUI
import WebKit

struct MiniBrowserPaneView: View {
    @EnvironmentObject var appState: AppState
    @State private var urlString: String = ""
    @State private var currentURL: URL? = nil
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Control bar
            HStack(spacing: 8) {
                // Back button
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)
                .help("Go Back")
                
                // Forward button
                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
                .help("Go Forward")
                
                // Address bar
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                        .foregroundStyle(SynapseTheme.textMuted)
                    
                TextField("Enter URL", text: $urlString, onCommit: navigateToURL)
                    .font(.system(size: 12, design: .rounded))
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(SynapseTheme.panelElevated, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(SynapseTheme.border, lineWidth: 1)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SynapseTheme.panelElevated)
            
            Divider()
                .background(SynapseTheme.border)
            
            // Web view
            if let url = currentURL {
                MiniBrowserWebView(
                    url: url,
                    onURLChange: { newURL in
                        urlString = newURL?.absoluteString ?? ""
                        currentURL = newURL
                    },
                    onLoadingChange: { loading in
                        isLoading = loading
                    },
                    onCanGoBackChange: { canBack in
                        canGoBack = canBack
                    },
                    onCanGoForwardChange: { canForward in
                        canGoForward = canForward
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 32))
                        .foregroundStyle(SynapseTheme.textMuted)
                    
                    Text("Enter a URL to start browsing")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(SynapseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SynapseTheme.panel)
            }
        }
        .background(SynapseTheme.panel)
        .onAppear {
            loadInitialURL()
        }
    }
    
    private func loadInitialURL() {
        // Try to load startup URL from settings, otherwise use last visited URL
        let startupURL = appState.settings.browserStartupURL
        if !startupURL.isEmpty, let url = URL(string: startupURL) {
            urlString = startupURL
            currentURL = url
        } else {
            // Default to a blank state
            urlString = ""
            currentURL = nil
        }
    }
    
    private func navigateToURL() {
        var input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme is present
        if !input.isEmpty && !input.hasPrefix("http://") && !input.hasPrefix("https://") {
            input = "https://" + input
        }
        
        if let url = URL(string: input), !input.isEmpty {
            currentURL = url
            urlString = input
        }
    }
    
    private func goBack() {
        // Handled by WebView via notification
        NotificationCenter.default.post(name: .browserGoBack, object: nil)
    }
    
    private func goForward() {
        // Handled by WebView via notification
        NotificationCenter.default.post(name: .browserGoForward, object: nil)
    }
}

// MARK: - WebView Coordinator

class MiniBrowserWebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: MiniBrowserWebView
    
    init(_ parent: MiniBrowserWebView) {
        self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.onLoadingChange(true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.onLoadingChange(false)
        parent.onURLChange(webView.url)
        updateNavigationState(webView)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        parent.onLoadingChange(false)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        parent.onLoadingChange(false)
    }
    
    private func updateNavigationState(_ webView: WKWebView) {
        parent.onCanGoBackChange(webView.canGoBack)
        parent.onCanGoForwardChange(webView.canGoForward)
    }
}

// MARK: - WebView Representable

struct MiniBrowserWebView: NSViewRepresentable {
    let url: URL
    let onURLChange: (URL?) -> Void
    let onLoadingChange: (Bool) -> Void
    let onCanGoBackChange: (Bool) -> Void
    let onCanGoForwardChange: (Bool) -> Void
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        
        // Set up notification observers for back/forward navigation
        NotificationCenter.default.addObserver(
            forName: .browserGoBack,
            object: nil,
            queue: .main
        ) { _ in
            if webView.canGoBack {
                webView.goBack()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .browserGoForward,
            object: nil,
            queue: .main
        ) { _ in
            if webView.canGoForward {
                webView.goForward()
            }
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Only load if URL has changed and is different from current
        if let currentURL = nsView.url, currentURL != url {
            nsView.load(URLRequest(url: url))
        } else if nsView.url == nil {
            nsView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> MiniBrowserWebViewCoordinator {
        MiniBrowserWebViewCoordinator(self)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let browserGoBack = Notification.Name("browserGoBack")
    static let browserGoForward = Notification.Name("browserGoForward")
}
