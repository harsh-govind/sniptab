// SnipTab — a scissors icon in the menu bar.
// Left-click it to drag-select an area and capture a screenshot.
// Right-click it for more options.

import Cocoa
import ServiceManagement

/// Turns on "open at login" the first time the app runs; after that the user's choice is kept.
func enableLaunchAtLoginOnFirstRun() {
    let key = "didSetUpLaunchAtLogin"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    UserDefaults.standard.set(true, forKey: key)
    try? SMAppService.mainApp.register()
}

let screenshotsFolder: URL = {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/SnipTab", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}()

// MARK: - Preview card shown after a capture

final class PreviewPanel: NSPanel {
    private var dismissWork: DispatchWorkItem?
    let url: URL

    /// `anchor` is the menu bar icon's frame in screen coordinates; the card drops down below it.
    init(url: URL, image: NSImage, below anchor: NSRect) {
        self.url = url
        let w: CGFloat = 280
        let imgH = min(180, max(80, (w - 20) * image.size.height / max(image.size.width, 1)))
        let h = imgH + 54
        var x = anchor.midX - w / 2
        let y = anchor.minY - h - 6
        if let vf = (NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main)?.visibleFrame {
            x = min(max(x, vf.minX + 8), vf.maxX - w - 8)
        }
        super.init(contentRect: NSRect(x: x, y: y, width: w, height: h),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        bg.material = .popover
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12
        bg.layer?.masksToBounds = true
        contentView = bg

        let iv = NSImageView(frame: NSRect(x: 10, y: 44, width: w - 20, height: imgH))
        iv.image = image
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 6
        iv.layer?.masksToBounds = true
        iv.toolTip = "Click to edit in Preview"
        iv.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(edit)))
        bg.addSubview(iv)

        let buttons: [(String, String, Selector)] = [
            ("Edit", "pencil.tip.crop.circle", #selector(edit)),
            ("Copy", "doc.on.doc", #selector(copyImage)),
            ("Finder", "folder", #selector(reveal)),
            ("Delete", "trash", #selector(trash)),
        ]
        let gap: CGFloat = 6, closeW: CGFloat = 28
        let bw = (w - 20 - closeW - gap * CGFloat(buttons.count)) / CGFloat(buttons.count)
        for (i, b) in buttons.enumerated() {
            let btn = NSButton(title: b.0, target: self, action: b.2)
            btn.image = NSImage(systemSymbolName: b.1, accessibilityDescription: b.0)
            btn.imagePosition = .imageLeading
            btn.bezelStyle = .rounded
            btn.controlSize = .small
            btn.font = .systemFont(ofSize: 11)
            btn.frame = NSRect(x: 10 + CGFloat(i) * (bw + gap), y: 10, width: bw, height: 26)
            bg.addSubview(btn)
        }
        let close = NSButton(title: "", target: self, action: #selector(dismiss))
        close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        close.bezelStyle = .rounded
        close.controlSize = .small
        close.frame = NSRect(x: w - 10 - closeW, y: 10, width: closeW, height: 26)
        bg.addSubview(close)

        scheduleDismiss(after: 8)
    }

    override var canBecomeKey: Bool { false }

    func scheduleDismiss(after s: Double) {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: work)
    }

    @objc func edit() {
        // Opens in Preview, where you can crop further, annotate and export.
        NSWorkspace.shared.open([url],
                                withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"),
                                configuration: NSWorkspace.OpenConfiguration())
        dismiss()
    }
    @objc func copyImage() {
        if let img = NSImage(contentsOf: url) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([img])
        }
        scheduleDismiss(after: 1.5)
    }
    @objc func reveal() { NSWorkspace.shared.activateFileViewerSelecting([url]); dismiss() }
    @objc func trash() { try? FileManager.default.trashItem(at: url, resultingItemURL: nil); dismiss() }
    @objc func dismiss() { dismissWork?.cancel(); orderOut(nil) }
}

// MARK: - App

enum CaptureMode { case area, window, fullScreen }

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var preview: PreviewPanel?
    var capturing = false

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "SnipTab"
        if let button = statusItem.button {
            setIcon("scissors")
            button.toolTip = "SnipTab — click to capture an area, right-click for options"
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        enableLaunchAtLoginOnFirstRun()
    }

    func setIcon(_ symbol: String) {
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "SnipTab")?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
        img?.isTemplate = true   // adapts to light/dark menu bar
        statusItem.button?.image = img
    }

    @objc func statusClicked() {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true || e?.modifierFlags.contains(.option) == true {
            showMenu()
        } else {
            capture(.area)
        }
    }

    // MARK: Menu

    func showMenu() {
        let m = NSMenu()
        func add(_ t: String, _ s: Selector, _ key: String = "", symbol: String? = nil) {
            let i = NSMenuItem(title: t, action: s, keyEquivalent: key)
            i.target = self
            if let symbol { i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            m.addItem(i)
        }
        add("Capture Area", #selector(menuArea), symbol: "crop")
        add("Capture Window", #selector(menuWindow), symbol: "macwindow")
        add("Capture Full Screen", #selector(menuFull), symbol: "display")
        add("Capture Area in 3 s", #selector(menuTimed), symbol: "timer")
        m.addItem(.separator())
        add("Open Screenshots Folder", #selector(openFolder), symbol: "folder")
        add("Launch at Login", #selector(toggleLogin), symbol: "power")
        m.items.last?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        m.addItem(.separator())
        add("Quit SnipTab", #selector(quit), "q")
        // Attach the menu just for this click so left-click keeps capturing directly.
        statusItem.menu = m
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func menuArea() { capture(.area) }
    @objc func menuWindow() { capture(.window) }
    @objc func menuFull() { capture(.fullScreen) }
    @objc func menuTimed() { capture(.area, delay: 3) }
    @objc func openFolder() { NSWorkspace.shared.open(screenshotsFolder) }
    @objc func quit() { NSApp.terminate(nil) }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSSound.beep()
        }
    }

    // MARK: Capture

    func capture(_ mode: CaptureMode, delay: Int = 0) {
        guard !capturing else { return }
        capturing = true
        preview?.dismiss()

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = screenshotsFolder.appendingPathComponent("Snip \(f.string(from: Date())).png")

        var args: [String]
        switch mode {
        case .area: args = ["-i", "-s"]      // drag to select an area
        case .window: args = ["-i", "-W"]    // click a window
        case .fullScreen: args = ["-m"]      // main display
        }
        if delay > 0 { args += ["-T", "\(delay)"] }
        args.append(url.path)

        // Small delay so the menu closes before the capture starts.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = args
            p.terminationHandler = { _ in DispatchQueue.main.async { self.finished(url) } }
            do { try p.run() } catch { self.finished(url) }
        }
    }

    func finished(_ url: URL) {
        capturing = false
        guard FileManager.default.fileExists(atPath: url.path),
              let img = NSImage(contentsOf: url) else { return }   // cancelled with Esc

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])   // ready to paste anywhere

        // Brief checkmark in the menu bar to confirm.
        setIcon("checkmark")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.setIcon("scissors") }

        guard let button = statusItem.button, let win = button.window else { return }
        let anchor = win.convertToScreen(button.convert(button.bounds, to: nil))
        let p = PreviewPanel(url: url, image: img, below: anchor)
        p.orderFrontRegardless()
        preview = p
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
