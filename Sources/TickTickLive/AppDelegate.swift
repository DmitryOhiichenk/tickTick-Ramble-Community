import AppKit
import Combine
import SwiftUI

/// Regular app window: normal level, standard close / minimize / zoom buttons over a transparent title bar.
final class MainWindow: NSWindow, NSWindowDelegate {
    var onEscape: (() -> Void)?
    /// Red close button and ⌘W. The app decides whether to hide right away or ask first.
    var onCloseRequest: (() -> Void)?

    init(rootView: some View) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 680),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        title = "TickTick Live"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        // Fixed-width window: the green button zooms instead of going full screen.
        collectionBehavior = [.fullScreenNone]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        tabbingMode = .disallowed
        minSize = NSSize(width: 420, height: 680)
        maxSize = NSSize(width: 420, height: 780)
        delegate = self

        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = [.minSize, .maxSize]
        contentView = hosting
    }

    override func cancelOperation(_ sender: Any?) { onEscape?() }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCloseRequest?()
        return false
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var app = AppState(settings: settings)
    private let hotkeys = HotkeyManager()
    private var panel: MainWindow!
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()
        // Session logs were removed; clean up files left by earlier builds.
        try? FileManager.default.removeItem(at: AppState.supportDirectory.appendingPathComponent("Logs"))

        panel = MainWindow(rootView: RootView().environmentObject(app).environmentObject(settings))
        panel.onEscape = { [weak self] in self?.app.escapePressed() }
        panel.onCloseRequest = { [weak self] in self?.app.closeTapped() }
        panel.setFrameAutosaveName("TickTickLiveMainPanel")
        if !panel.setFrameUsingName("TickTickLiveMainPanel") { centerOnActiveScreen() }

        app.hideWindow = { [weak self] in self?.hidePanel() }

        hotkeys.onPressed = { [weak self] in self?.hotkeyPressed() }
        settings.$hotkey
            .sink { [weak self] combo in
                guard let self, !self.settings.isRecordingHotkey else { return }
                self.hotkeys.register(combo)
            }
            .store(in: &cancellables)
        settings.$isRecordingHotkey
            .dropFirst()
            .sink { [weak self] recording in
                guard let self else { return }
                if recording { self.hotkeys.unregister() } else { self.hotkeys.register(self.settings.hotkey) }
            }
            .store(in: &cancellables)
        settings.$appearance
            .sink { appearance in
                switch appearance {
                case .system: NSApp.appearance = nil
                case .light: NSApp.appearance = NSAppearance(named: .aqua)
                case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
            .store(in: &cancellables)
        settings.$showInMenuBar
            .sink { [weak self] show in self?.updateStatusItem(show) }
            .store(in: &cancellables)
        settings.$language
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rebuildMenu()
                    self?.installMainMenu()
                }
            }
            .store(in: &cancellables)

        showPanel()
    }

    /// Clicking the Dock icon or opening the app again brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        app.windowWillHide()
    }

    // MARK: - Window

    private var windowOnScreen: Bool { panel.isVisible && !panel.isMiniaturized && !NSApp.isHidden }

    private func showPanel() {
        app.refreshMicStatus()
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        if panel.isMiniaturized { panel.deminiaturize(nil) }
        if !panel.isVisible && NSScreen.screens.allSatisfy({ !$0.visibleFrame.intersects(panel.frame) }) {
            centerOnActiveScreen()
        }
        NSApp.unhide(nil)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closing the window: in background mode the app leaves the Dock and stays in the menu bar
    /// (hotkey keeps working, microphone off); otherwise it quits.
    private func hidePanel() {
        app.windowWillHide()
        panel.orderOut(nil)
        if settings.runInBackground {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.terminate(nil)
        }
    }

    private func centerOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }

    // MARK: - Hotkey

    private func hotkeyPressed() {
        if app.screen == .recording {
            app.checkTapped()
            return
        }
        let wasOnScreen = windowOnScreen
        showPanel()
        if app.screen == .start && settings.tokensConfigured && !(wasOnScreen && app.showSettings) {
            app.showSettings = false
            app.startRecording()
        }
    }

    // MARK: - Main menu

    private func installMainMenu() {
        let t = settings.t
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: t(.menuAbout), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = appMenu.addItem(withTitle: t(.menuSettings), action: #selector(menuSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: t(.menuHide), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = appMenu.addItem(withTitle: t(.menuHideOthers), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: t(.menuShowAll), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: t(.menuQuit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: t(.menuEdit))
        edit.addItem(withTitle: t(.menuUndo), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: t(.menuRedo), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: t(.menuCut), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: t(.menuCopy), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: t(.menuPaste), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: t(.menuSelectAll), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: t(.menuWindow))
        window.addItem(withTitle: t(.menuMinimize), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: t(.menuZoom), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        window.addItem(withTitle: t(.menuClose), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(.separator())
        window.addItem(withTitle: t(.menuBringAllToFront), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowItem.submenu = window
        main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = window
    }

    // MARK: - Menu bar

    private func updateStatusItem(_ show: Bool) {
        if show {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "TickTick Live")
                image?.isTemplate = true
                item.button?.image = image
                statusItem = item
            }
            rebuildMenu()
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func rebuildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.addItem(item(settings.t(.menuOpen), #selector(menuOpen)))
        menu.addItem(item(settings.t(.menuNewRecording), #selector(menuRecord), keyEquivalentFrom: settings.hotkey))
        menu.addItem(item(settings.t(.menuSettings), #selector(menuSettings)))
        menu.addItem(.separator())
        menu.addItem(item(settings.t(.menuQuit), #selector(menuQuit)))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, keyEquivalentFrom combo: KeyCombo? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let combo { item.toolTip = combo.display }
        return item
    }

    @objc private func menuOpen() { showPanel() }

    @objc private func menuRecord() {
        showPanel()
        if app.screen != .recording { app.showSettings = false; app.startRecording() }
    }

    @objc private func menuSettings() {
        showPanel()
        withAnimation(.easeOut(duration: 0.2)) { app.showSettings = true }
    }

    @objc private func menuQuit() { NSApp.terminate(nil) }
}
