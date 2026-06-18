import Cocoa
import WebKit
import Security

// MARK: - App Configuration Helper
struct AppConfig {
    static let urlKey = "OnlyOneFriendURL"
    static let passcodeKey = "OnlyOneFriendPasscode"
    
    static var isConfigured: Bool {
        return UserDefaults.standard.string(forKey: urlKey) != nil &&
               UserDefaults.standard.string(forKey: passcodeKey) != nil
    }
    
    static func save(url: String, passcode: String) {
        UserDefaults.standard.set(url, forKey: urlKey)
        UserDefaults.standard.set(passcode, forKey: passcodeKey)
        UserDefaults.standard.synchronize()
    }
    
    static func reset() {
        UserDefaults.standard.removeObject(forKey: urlKey)
        UserDefaults.standard.removeObject(forKey: passcodeKey)
        UserDefaults.standard.synchronize()
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate {
        return NSApp.delegate as! AppDelegate
    }
    
    var window: NSWindow!
    var mainViewController: MainViewController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the main window
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1024, height: 768),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "OnlyOneFriend"
        window.minSize = NSSize(width: 800, height: 600)
        window.center()
        window.delegate = self
        
        // Setup Root View Controller
        mainViewController = MainViewController()
        window.contentViewController = mainViewController
        
        // Setup Menu Bar
        setupMenuBar()
        
        // Show Window
        window.makeKeyAndOrderFront(nil)
        
        // Set app name in dock
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Do not auto-lock on window focus change to avoid asking for passcode when switching windows
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
            // Lock the app only when the window was closed/hidden and is reopened
            if AppConfig.isConfigured {
                mainViewController.lockApp()
            }
        }
        return true
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide the window instead of destroying it to keep the session alive in memory
        window.orderOut(nil)
        if AppConfig.isConfigured {
            mainViewController.lockApp()
        }
        return false // Return false so the system doesn't close/destroy the window
    }
    
    // MARK: - Menu Setup
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // Standard App items
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        
        // Custom Actions
        let logoutItem = NSMenuItem(title: "Log Out of Facebook...", action: #selector(logoutPressed), keyEquivalent: "")
        logoutItem.target = self
        appMenu.addItem(logoutItem)
        
        let changePasscodeItem = NSMenuItem(title: "Change Lock Passcode...", action: #selector(changePasscodePressed), keyEquivalent: "")
        changePasscodeItem.target = self
        appMenu.addItem(changePasscodeItem)
        
        let resetItem = NSMenuItem(title: "Reset App (Clear URL & Passcode)...", action: #selector(resetConfigurationPressed), keyEquivalent: "")
        resetItem.target = self
        appMenu.addItem(resetItem)
        
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit Menu (crucial for keyboard shortcuts like Copy/Paste)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func resetConfigurationPressed() {
        let alert = NSAlert()
        alert.messageText = "Reset App Configuration?"
        alert.informativeText = "This will clear your OnlyOneFriend URL and your Lock passcode. The app will restart into Setup mode."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AppConfig.reset()
            mainViewController.showSetupScreen()
        }
    }
    
    @objc func logoutPressed() {
        let alert = NSAlert()
        alert.messageText = "Log Out of Facebook?"
        alert.informativeText = "This will clear your Facebook session and log you out of the web interface. You will need to log back in next time."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Log Out")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let dataStore = WKWebsiteDataStore.default()
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                    DispatchQueue.main.async {
                        self.mainViewController.webView.load(URLRequest(url: URL(string: "about:blank")!))
                        if let configURL = UserDefaults.standard.string(forKey: AppConfig.urlKey),
                           let url = URL(string: configURL) {
                            self.mainViewController.webView.load(URLRequest(url: url))
                        }
                    }
                }
            }
        }
    }
    
    @objc func changePasscodePressed() {
        let alert = NSAlert()
        alert.messageText = "Change Lock Passcode"
        alert.informativeText = "Enter your current passcode, then set a new passcode."
        alert.alertStyle = .informational
        
        let currentPassField = NSSecureTextField(frame: NSRect(x: 0, y: 50, width: 200, height: 24))
        currentPassField.placeholderString = "Current Passcode"
        let newPassField = NSSecureTextField(frame: NSRect(x: 0, y: 25, width: 200, height: 24))
        newPassField.placeholderString = "New Passcode"
        let confirmPassField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        confirmPassField.placeholderString = "Confirm New Passcode"
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        container.addSubview(currentPassField)
        container.addSubview(newPassField)
        container.addSubview(confirmPassField)
        
        alert.accessoryView = container
        alert.addButton(withTitle: "Change Passcode")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let savedPasscode = UserDefaults.standard.string(forKey: AppConfig.passcodeKey) ?? ""
            if currentPassField.stringValue != savedPasscode {
                showSimpleAlert(message: "Incorrect Current Passcode", info: "The current passcode you entered was incorrect. Passcode was not changed.")
                return
            }
            if newPassField.stringValue.isEmpty {
                showSimpleAlert(message: "Error", info: "New passcode cannot be empty.")
                return
            }
            if newPassField.stringValue != confirmPassField.stringValue {
                showSimpleAlert(message: "Error", info: "New passcodes do not match.")
                return
            }
            
            UserDefaults.standard.set(newPassField.stringValue, forKey: AppConfig.passcodeKey)
            UserDefaults.standard.synchronize()
            showSimpleAlert(message: "Success", info: "Your lock passcode has been successfully changed.")
        }
    }
    
    private func showSimpleAlert(message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.runModal()
    }
}

// MARK: - Main View Controller (Manages Setup, Lock, and WebView)
class MainViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
    
    // View States
    enum AppState {
        case setup
        case locked
        case unlocked
    }
    
    var currentState: AppState = .setup
    
    // UI Elements
    var visualEffectView: NSVisualEffectView!
    var setupContainer: NSView!
    var lockContainer: NSView!
    var webView: WKWebView!
    
    // Setup Fields
    var setupUrlField: NSTextField!
    var setupPasscodeField: NSSecureTextField!
    var setupConfirmPasscodeField: NSSecureTextField!
    var setupErrorLabel: NSTextField!
    
    // Lock Fields
    var lockPasscodeField: NSSecureTextField!
    var lockErrorLabel: NSTextField!
    
    override func loadView() {
        // Root container view
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768))
        view.wantsLayer = true
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Setup WebView
        setupWebViewInstance()
        
        // 2. Setup Glassmorphic Overlay (Visual Effect View)
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        view.addSubview(visualEffectView)
        stretchToFit(visualEffectView, in: view)
        
        // 3. Build Setup UI Screen
        buildSetupUI()
        
        // 4. Build Lock UI Screen
        buildLockUI()
        
        // 5. Initialize State
        if AppConfig.isConfigured {
            showLockScreen()
        } else {
            showSetupScreen()
        }
    }
    
    // MARK: - WebView Setup
    private func setupWebViewInstance() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        // Inject Custom CSS & JS script to hide header, left sidebar (chats), and right sidebar (chat info)
        let jsSource = """
        (function() {
            // 1. Try to inject a standard CSS stylesheet (handles immediate elements)
            try {
                var style = document.createElement('style');
                style.type = 'text/css';
                style.innerHTML = 'div[role="navigation"], div[role="banner"], nav[role="navigation"], aside[role="complementary"], header, div[aria-label="Facebook"], div[aria-label="Chats"], div[aria-label="Conversations"], div[aria-label="Conversation Information"], div[aria-label="Thread details"] { display: none !important; } div[role="main"], main, div.main { width: 100vw !important; max-width: 100vw !important; min-width: 100vw !important; height: 100vh !important; max-height: 100vh !important; flex-grow: 1 !important; left: 0 !important; top: 0 !important; margin-top: 0 !important; padding-top: 0 !important; }';
                document.head.appendChild(style);
            } catch (e) {
                console.log("CSS injection blocked, relying on JS style overrides.");
            }

            // 2. JS MutationObserver for CSP-proof DOM style overrides
            function applyOverrides() {
                // Hide top bar (Facebook main header)
                var topBars = document.querySelectorAll('div[role="banner"], header, div[aria-label="Facebook"]');
                topBars.forEach(function(el) {
                    el.style.setProperty('display', 'none', 'important');
                });

                // Find main chat container
                var main = document.querySelector('div[role="main"], main');
                if (main) {
                    // Only hide sidebars if we are actually on the messages view (keeps login & restore views fully functional)
                    var isMessagesPage = window.location.href.includes('/messages');
                    if (isMessagesPage && main.parentElement) {
                        var siblings = main.parentElement.children;
                        for (var i = 0; i < siblings.length; i++) {
                            var sib = siblings[i];
                            if (sib !== main) {
                                sib.style.setProperty('display', 'none', 'important');
                            }
                        }
                    }

                    // Expand main conversation area to take full screen
                    main.style.setProperty('width', '100vw', 'important');
                    main.style.setProperty('max-width', '100vw', 'important');
                    main.style.setProperty('min-width', '100vw', 'important');
                    main.style.setProperty('height', '100vh', 'important');
                    main.style.setProperty('max-height', '100vh', 'important');
                    main.style.setProperty('left', '0', 'important');
                    main.style.setProperty('top', '0', 'important');
                    main.style.setProperty('margin', '0', 'important');
                    el.style.setProperty('padding', '0', 'important');

                    // Reset top offsets of all parent elements of the main chat area (removes empty top area)
                    var current = main;
                    while (current && current !== document.body) {
                        current.style.setProperty('padding-top', '0', 'important');
                        current.style.setProperty('margin-top', '0', 'important');
                        current.style.setProperty('top', '0', 'important');
                        current = current.parentElement;
                    }
                }
                document.body.style.setProperty('padding-top', '0', 'important');
                document.body.style.setProperty('margin-top', '0', 'important');
            }

            // Run overrides immediately and on key load events
            applyOverrides();
            window.addEventListener('DOMContentLoaded', applyOverrides);
            window.addEventListener('load', applyOverrides);
            
            // Observe DOM changes (Crucial for React rendering updates)
            var observer = new MutationObserver(function(mutations) {
                applyOverrides();
            });
            observer.observe(document.documentElement, {
                childList: true,
                subtree: true
            });
        })();
        """
        
        let userScript = WKUserScript(source: jsSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // Set standard desktop user agent to load web messenger client
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        webView.alphaValue = 0.0
        
        view.addSubview(webView)
        stretchToFit(webView, in: view)
    }
    
    // MARK: - Setup UI Building
    private func buildSetupUI() {
        setupContainer = NSView()
        setupContainer.wantsLayer = true
        setupContainer.layer?.cornerRadius = 16
        setupContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.7).cgColor
        setupContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        setupContainer.layer?.borderWidth = 1
        visualEffectView.addSubview(setupContainer)
        
        // Center constraints
        setupContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            setupContainer.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
            setupContainer.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            setupContainer.widthAnchor.constraint(equalToConstant: 460),
            setupContainer.heightAnchor.constraint(equalToConstant: 380)
        ])
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 15
        setupContainer.addSubview(stack)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: setupContainer.topAnchor, constant: 30),
            stack.leadingAnchor.constraint(equalTo: setupContainer.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: setupContainer.trailingAnchor, constant: -40),
            stack.bottomAnchor.constraint(equalTo: setupContainer.bottomAnchor, constant: -30)
        ])
        
        // Emoji Lock Icon
        let iconLabel = NSTextField(labelWithString: "🔒")
        iconLabel.font = NSFont.systemFont(ofSize: 40)
        stack.addArrangedSubview(iconLabel)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "OnlyOneFriend Setup")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 22)
        titleLabel.textColor = .labelColor
        stack.addArrangedSubview(titleLabel)
        
        // Description
        let descLabel = NSTextField(labelWithString: "Configure the single conversation thread URL and a security passcode to unlock this app.")
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        stack.addArrangedSubview(descLabel)
        
        // URL Input
        setupUrlField = NSTextField()
        setupUrlField.bezelStyle = .roundedBezel
        setupUrlField.placeholderString = "Focused Chat URL (e.g. facebook.com/messages/...)"
        setupUrlField.translatesAutoresizingMaskIntoConstraints = false
        setupUrlField.widthAnchor.constraint(equalToConstant: 360).isActive = true
        stack.addArrangedSubview(setupUrlField)
        
        // Passcode Input
        setupPasscodeField = NSSecureTextField()
        setupPasscodeField.bezelStyle = .roundedBezel
        setupPasscodeField.placeholderString = "Set Passcode"
        setupPasscodeField.translatesAutoresizingMaskIntoConstraints = false
        setupPasscodeField.widthAnchor.constraint(equalToConstant: 360).isActive = true
        stack.addArrangedSubview(setupPasscodeField)
        
        // Confirm Passcode Input
        setupConfirmPasscodeField = NSSecureTextField()
        setupConfirmPasscodeField.bezelStyle = .roundedBezel
        setupConfirmPasscodeField.placeholderString = "Confirm Passcode"
        setupConfirmPasscodeField.translatesAutoresizingMaskIntoConstraints = false
        setupConfirmPasscodeField.widthAnchor.constraint(equalToConstant: 360).isActive = true
        stack.addArrangedSubview(setupConfirmPasscodeField)
        
        // Error Label
        setupErrorLabel = NSTextField(labelWithString: "")
        setupErrorLabel.textColor = .systemRed
        setupErrorLabel.font = NSFont.systemFont(ofSize: 12)
        setupErrorLabel.alignment = .center
        setupErrorLabel.isHidden = true
        stack.addArrangedSubview(setupErrorLabel)
        
        // Save Button
        let saveButton = NSButton(title: "Save & Lock", target: self, action: #selector(saveSetupPressed))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Enter key submits
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.widthAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(saveButton)
    }
    
    // MARK: - Lock UI Building
    private func buildLockUI() {
        lockContainer = NSView()
        lockContainer.wantsLayer = true
        lockContainer.layer?.cornerRadius = 16
        lockContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.7).cgColor
        lockContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        lockContainer.layer?.borderWidth = 1
        visualEffectView.addSubview(lockContainer)
        
        // Center constraints
        lockContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lockContainer.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
            lockContainer.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            lockContainer.widthAnchor.constraint(equalToConstant: 400),
            lockContainer.heightAnchor.constraint(equalToConstant: 280)
        ])
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 15
        lockContainer.addSubview(stack)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: lockContainer.topAnchor, constant: 30),
            stack.leadingAnchor.constraint(equalTo: lockContainer.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: lockContainer.trailingAnchor, constant: -40),
            stack.bottomAnchor.constraint(equalTo: lockContainer.bottomAnchor, constant: -30)
        ])
        
        // Lock Icon
        let iconLabel = NSTextField(labelWithString: "🔒")
        iconLabel.font = NSFont.systemFont(ofSize: 48)
        stack.addArrangedSubview(iconLabel)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "OnlyOneFriend")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 22)
        titleLabel.textColor = .labelColor
        stack.addArrangedSubview(titleLabel)
        
        // Passcode Input
        lockPasscodeField = NSSecureTextField()
        lockPasscodeField.bezelStyle = .roundedBezel
        lockPasscodeField.placeholderString = "Enter Passcode"
        lockPasscodeField.translatesAutoresizingMaskIntoConstraints = false
        lockPasscodeField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        stack.addArrangedSubview(lockPasscodeField)
        
        // Error Label
        lockErrorLabel = NSTextField(labelWithString: "")
        lockErrorLabel.textColor = .systemRed
        lockErrorLabel.font = NSFont.systemFont(ofSize: 12)
        lockErrorLabel.alignment = .center
        lockErrorLabel.isHidden = true
        stack.addArrangedSubview(lockErrorLabel)
        
        // Unlock Button
        let unlockButton = NSButton(title: "Unlock", target: self, action: #selector(unlockPressed))
        unlockButton.bezelStyle = .rounded
        unlockButton.keyEquivalent = "\r" // Enter key submits
        unlockButton.translatesAutoresizingMaskIntoConstraints = false
        unlockButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        stack.addArrangedSubview(unlockButton)
    }
    
    // MARK: - UI State Transitions
    func showSetupScreen() {
        currentState = .setup
        visualEffectView.alphaValue = 1.0
        visualEffectView.isHidden = false
        setupContainer.isHidden = false
        lockContainer.isHidden = true
        webView.alphaValue = 0.0
        
        setupUrlField.stringValue = ""
        setupPasscodeField.stringValue = ""
        setupConfirmPasscodeField.stringValue = ""
        setupErrorLabel.isHidden = true
        setupErrorLabel.stringValue = ""
    }
    
    func showLockScreen() {
        currentState = .locked
        visualEffectView.alphaValue = 1.0
        visualEffectView.isHidden = false
        setupContainer.isHidden = true
        lockContainer.isHidden = false
        webView.alphaValue = 0.0
        
        lockPasscodeField.stringValue = ""
        lockErrorLabel.isHidden = true
        lockErrorLabel.stringValue = ""
        
        // Request keyboard focus immediately on the passcode field
        DispatchQueue.main.async {
            self.lockPasscodeField.window?.makeFirstResponder(self.lockPasscodeField)
        }
    }
    
    func lockApp() {
        guard currentState == .unlocked else { return }
        showLockScreen()
    }
    
    func unlockApp() {
        currentState = .unlocked
        
        // Fade out overlay and fade in WebView
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            self.visualEffectView.animator().alphaValue = 0.0
            self.webView.animator().alphaValue = 1.0
        }, completionHandler: {
            self.visualEffectView.isHidden = true
        })
        
        // Load the configured URL if webView is not loaded yet
        if let configURL = UserDefaults.standard.string(forKey: AppConfig.urlKey),
           let url = URL(string: configURL) {
            // Check if current URL matches. If empty/blank, load it.
            if webView.url == nil || webView.url?.absoluteString == "about:blank" {
                webView.load(URLRequest(url: url))
            }
        }
    }
    
    // MARK: - Actions
    @objc func saveSetupPressed() {
        let url = setupUrlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let passcode = setupPasscodeField.stringValue
        let confirmPasscode = setupConfirmPasscodeField.stringValue
        
        if url.isEmpty {
            showSetupError("URL cannot be empty.")
            shakeView(setupContainer)
            return
        }
        
        guard let parsedURL = URL(string: url),
              (parsedURL.host?.contains("messenger.com") == true || parsedURL.host?.contains("facebook.com") == true) else {
            showSetupError("Please enter a valid messenger.com or facebook.com URL.")
            shakeView(setupContainer)
            return
        }
        
        if extractThreadID(from: url) == nil {
            showSetupError("Please specify a complete conversation URL (e.g. /t/12345...)")
            shakeView(setupContainer)
            return
        }
        
        if passcode.isEmpty {
            showSetupError("Passcode cannot be empty.")
            shakeView(setupContainer)
            return
        }
        
        if passcode != confirmPasscode {
            showSetupError("Passcodes do not match.")
            shakeView(setupContainer)
            return
        }
        
        // Save config and lock
        AppConfig.save(url: url, passcode: passcode)
        showLockScreen()
    }
    
    @objc func unlockPressed() {
        let enteredPasscode = lockPasscodeField.stringValue
        let savedPasscode = UserDefaults.standard.string(forKey: AppConfig.passcodeKey) ?? ""
        
        if enteredPasscode == savedPasscode {
            unlockApp()
        } else {
            lockErrorLabel.stringValue = "Invalid passcode. Try again."
            lockErrorLabel.isHidden = false
            shakeView(lockContainer)
            lockPasscodeField.stringValue = ""
        }
    }
    
    private func showSetupError(_ text: String) {
        setupErrorLabel.stringValue = text
        setupErrorLabel.isHidden = false
    }
    
    // MARK: - Shake Animation
    private func shakeView(_ view: NSView) {
        let numberOfShakes = 3
        let duration = 0.3
        let vigourOfShake: CGFloat = 0.05
        
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = duration
        
        var values = [CGFloat]()
        for i in 0..<numberOfShakes {
            let progress = CGFloat(i) / CGFloat(numberOfShakes)
            let vig = vigourOfShake * (1.0 - progress)
            values.append(-view.frame.size.width * vig)
            values.append(view.frame.size.width * vig)
        }
        values.append(0)
        animation.values = values
        
        view.layer?.add(animation, forKey: "shake")
    }
    
    // MARK: - WebKit Navigation Delegate
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        // Allow non-http/https URL schemes (e.g. javascript:, about:, data:, blob:) to execute locally inside WebKit
        if let scheme = url.scheme?.lowercased(), scheme != "http" && scheme != "https" {
            decisionHandler(.allow)
            return
        }
        
        let urlString = url.absoluteString
        
        // 1. Allow initial/blank/reset states
        if urlString == "about:blank" || urlString.isEmpty {
            decisionHandler(.allow)
            return
        }
        
        // 2. Allow authentication/security flow (Messenger/Facebook login, dialogs, checkpoints)
        if urlString.contains("messenger.com/login") || 
           urlString.contains("facebook.com/login") || 
           urlString.contains("facebook.com/oauth") ||
           urlString.contains("messenger.com/desktop") ||
           urlString.contains("facebook.com/checkpoint") ||
           urlString.contains("facebook.com/dialog") {
            decisionHandler(.allow)
            return
        }
        
        // 3. Match against configured target URL and thread ID
        if let configURL = UserDefaults.standard.string(forKey: AppConfig.urlKey),
           let targetID = extractThreadID(from: configURL) {
            
            // Allow if navigating specifically within the configured conversation thread
            if urlString.contains("/t/\(targetID)") {
                decisionHandler(.allow)
                return
            }
            
            // Handle redirects to general facebook/messenger pages
            if navigationAction.targetFrame?.isMainFrame == true {
                let isFacebookHome = urlString == "https://www.facebook.com/" || 
                                     urlString == "https://www.facebook.com" || 
                                     urlString.contains("facebook.com/home")
                                     
                let isDifferentThread = (urlString.contains("/messages/t/") || 
                                         urlString.contains("/messages/e2ee/t/") || 
                                         urlString.contains("messenger.com/t/")) &&
                                         !urlString.contains("/t/\(targetID)")
                                         
                let isGeneralMessages = urlString.hasSuffix("facebook.com/messages") || 
                                       urlString.hasSuffix("facebook.com/messages/") ||
                                       urlString.hasSuffix("messenger.com") ||
                                       urlString.hasSuffix("messenger.com/")
                
                if isFacebookHome || isDifferentThread || isGeneralMessages {
                    print("Intercepted and redirecting main frame to target thread URL: \(configURL)")
                    if let targetURL = URL(string: configURL) {
                        webView.load(URLRequest(url: targetURL))
                        decisionHandler(.cancel)
                        return
                    }
                }
            }
            
            // Block navigation to any other conversation thread ID
            if urlString.contains("messenger.com/t/") || 
               urlString.contains("facebook.com/messages/t/") || 
               urlString.contains("facebook.com/messages/e2ee/t/") {
                print("Blocked navigation attempt to different conversation: \(urlString)")
                decisionHandler(.cancel)
                return
            }
        }
        
        // 4. Block general navigation on messenger.com or facebook.com/messages (e.g. sidebar tabs/links to home/requests/settings)
        if urlString.contains("messenger.com") || urlString.contains("facebook.com/messages") {
            // Allow standard asset loading/API requests (type .other)
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
                return
            }
            
            // If it's a direct user click to a different messenger page, block it
            if navigationAction.navigationType == .linkActivated {
                print("Blocked navigation to general Messenger page: \(urlString)")
                decisionHandler(.cancel)
                return
            }
        }
        
        // 5. Open external links in user's default browser (Safari, Chrome, etc.)
        if navigationAction.navigationType == .linkActivated {
            print("Redirecting link activation to default browser: \(urlString)")
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    // MARK: - Helpers
    private func extractThreadID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let pathComponents = url.pathComponents
        
        if let tIndex = pathComponents.firstIndex(of: "t"), tIndex + 1 < pathComponents.count {
            return pathComponents[tIndex + 1]
        }
        
        if let range = urlString.range(of: "/t/") {
            let afterT = urlString[range.upperBound...]
            let idString = afterT.prefix(while: { $0.isNumber || $0.isLetter || $0 == "-" || $0 == "_" })
            if !idString.isEmpty {
                return String(idString)
            }
        }
        return nil
    }
    
    private func stretchToFit(_ subview: NSView, in parent: NSView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: parent.topAnchor),
            subview.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            subview.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])
    }
    
    // MARK: - WebKit UI Delegate (File Uploads & Media Permissions)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        
        openPanel.beginSheetModal(for: self.view.window!) { response in
            if response == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let host = origin.host.lowercased()
        if host.contains("facebook.com") || host.contains("messenger.com") {
            decisionHandler(.grant)
        } else {
            decisionHandler(.deny)
        }
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }
}

// MARK: - App Bootstrapping
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
