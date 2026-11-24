import Cocoa
import WebKit
import Carbon

// Borderless windows can't take keyboard input unless they say so.
class Panel: NSPanel { override var canBecomeKey: Bool { true } }

// The thin strip on top: drag it to move the window.
class DragStrip: NSView {
    override func mouseDown(with e: NSEvent) { window?.performDrag(with: e) }
    // bounds, not the dirty rect: since macOS 14 views are not clipped, so filling r painted over the whole window
    override func draw(_ r: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        // grabber pill so it's obvious where to drag
        NSColor.tertiaryLabelColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: bounds.midX - 20, y: bounds.midY - 2.5, width: 40, height: 5), xRadius: 2.5, yRadius: 2.5).fill()
    }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    static let strip: CGFloat = 14
    // A floating window instead of a popover so it can be dragged anywhere (drag the thin strip on top).
    let panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 600 + strip),
                      styleMask: [.borderless], backing: .buffered, defer: false)
    let menu = NSMenu()
    var hotKey: EventHotKeyRef?

    func applicationDidFinishLaunching(_ n: Notification) {
        // Edit menu so Cmd+X/C/V/A work inside the web view
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        NSApp.mainMenu = NSMenu()
        NSApp.mainMenu!.addItem(editItem)

        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 440, height: 600))
        web.load(URLRequest(url: URL(string: "https://www.desmos.com/calculator")!,
                            cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60))
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 600 + Self.strip))
        box.addSubview(web)
        box.addSubview(DragStrip(frame: NSRect(x: 0, y: 600, width: 440, height: Self.strip)))
        box.wantsLayer = true
        box.layer!.cornerRadius = 10
        box.layer!.masksToBounds = true
        panel.contentView = box
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none  // open/close instantly; the fade felt laggy
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let b = statusItem.button!
        b.image = NSImage(systemSymbolName: "function", accessibilityDescription: "Desmos")
        b.target = self
        b.action = #selector(clicked)
        b.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Reading other apps' focus needs Accessibility permission; ask once.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        // Never let a slow app stall the check (default AX timeout is ~6s).
        AXUIElementSetMessagingTimeout(Self.systemWide, 0.1)
        // Clicks in other apps: close unless the click put the keyboard cursor into a text input.
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            // Menu bar icon clicks also land here; leave those to clicked().
            if let b = self.statusItem.button, let w = b.window,
               w.convertToScreen(b.convert(b.bounds, to: nil)).contains(NSEvent.mouseLocation) { return }
            // Chrome and Electron apps hide their focus from the Accessibility API, so also treat
            // a click made with the I-beam (text) cursor as "clicked into text".
            let onText = Self.cursorIsIBeam()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {  // let the other app move focus first
                if !(onText || Self.focusIsTextInput()) { self.panel.orderOut(nil) }
            }
        }

        // Drag from anywhere: hold Cmd and drag any spot, or plain-drag the empty middle of Desmos's dark header.
        // (Plain drags elsewhere must stay with the page: they pan the graph and select text.)
        // shortcut: header gap is hard-coded from Desmos's current layout, re-measure if their header changes
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in
            guard let self, e.window === self.panel else { return e }
            let p = e.locationInWindow
            let headerGap = p.y > 555 && p.y <= 600 && p.x > 240 && p.x < 400
            guard e.modifierFlags.contains(.command) || headerGap else { return e }
            self.panel.performDrag(with: e)
            return nil
        }

        // Cmd+Option+D anywhere toggles the calculator (Carbon hotkey: no extra permission, swallows the keys).
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { delegate.toggle() }
            return noErr
        }, 1, &spec, nil, nil)
        RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(cmdKey | optionKey),
                                     EventHotKeyID(signature: OSType(0x44534D42), id: 1),
                                     GetApplicationEventTarget(), 0, &hotKey)
    }

    static let systemWide = AXUIElementCreateSystemWide()

    // shortcut: matches the system I-beam by size and hot spot; apps drawing their own text cursor won't match
    static func cursorIsIBeam() -> Bool {
        guard let c = NSCursor.currentSystem else { return false }
        return c.hotSpot == NSCursor.iBeam.hotSpot && c.image.size == NSCursor.iBeam.image.size
    }

    static func focusIsTextInput() -> Bool {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
              let ref else { return false }
        return isTextInput(ref as! AXUIElement)
    }

    static func isTextInput(_ el: AXUIElement) -> Bool {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
        if let r = role as? String, [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(r) { return true }
        // contenteditable / custom editors: an editable value with a caret
        var settable: DarwinBoolean = false
        var range: CFTypeRef?
        return AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable) == .success && settable.boolValue
            && AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &range) == .success
    }

    // Window centered just under the menu bar icon, kept on screen.
    func placeUnderIcon() {
        guard let b = statusItem.button, let w = b.window else { return }
        let icon = w.convertToScreen(b.convert(b.bounds, to: nil))
        var f = panel.frame
        f.origin = NSPoint(x: icon.midX - f.width / 2, y: icon.minY - f.height - 4)
        if let vis = w.screen?.visibleFrame { f.origin.x = min(max(f.origin.x, vis.minX), vis.maxX - f.width) }
        panel.setFrame(f, display: false)
    }

    @objc func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button!.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle()
        }
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            placeUnderIcon()  // always opens at the default spot; a drag only lasts until it closes
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
