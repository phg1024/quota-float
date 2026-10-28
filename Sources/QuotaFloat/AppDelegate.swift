import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: NSPanel!
    private var status: NSStatusItem!
    private var summaryItems: [NSMenuItem] = []
    private let model = QuotaModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let hosting = QuotaHostingView(rootView: QuotaView(model: model))
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 18
        hosting.layer?.masksToBounds = true
        panel = makePanel(content: hosting)
        status = makeStatusItem()
        model.onUpdate = { [weak self, weak hosting] in
            guard let self, let hosting else { return }
            self.updateStatus()
            DispatchQueue.main.async { self.fitPanel(to: hosting) }
        }
        show()
        model.start()
        model.onUpdate?()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
    }

    private func makePanel(content: NSView) -> NSPanel {
        let panel = QuotaPanel(contentRect: NSRect(x: 0, y: 0, width: 294, height: 280),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = content
        panel.setFrameAutosaveName(positionAutosaveName)
        if !panel.setFrameUsingName(positionAutosaveName), let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 320, y: screen.visibleFrame.maxY - 320))
        }
        return panel
    }

    private func makeStatusItem() -> NSStatusItem {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        summaryItems = QuotaService.allCases.map { _ in
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return item
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show Quota Float", action: #selector(show), keyEquivalent: "")
        menu.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Quota Float", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items where item.action != nil { item.target = self }
        menu.autoenablesItems = false
        status.menu = menu
        return status
    }

    /// Resizes the panel to fit its content while keeping the top edge in place.
    private func fitPanel(to hosting: NSView) {
        let height = hosting.fittingSize.height
        var frame = panel.frame
        frame.origin.y += frame.height - height
        frame.size.height = height
        panel.setFrame(frame, display: true)
    }

    private func updateStatus() {
        guard let button = status.button else { return }
        let sections = QuotaService.allCases.map { (service: $0, section: model[$0]) }
        button.image = statusGaugeImage(for: sections)
        let lines = sections.map { statusSummary($0.service, $0.section) }
        button.toolTip = lines.joined(separator: "\n")
        button.setAccessibilityLabel("Quota. " + lines.joined(separator: ". "))
        for (item, line) in zip(summaryItems, lines) { item.title = line }
    }

    // Also called while the panel is being created (restoring its saved frame), before `panel` is assigned.
    func windowDidMove(_ notification: Notification) {
        (notification.object as? NSWindow)?.saveFrame(usingName: positionAutosaveName)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }

    @objc private func show() {
        NSApp.unhide(nil)
        panel.orderFrontRegardless()
    }
    @objc private func refresh() { model.refresh() }
    @objc private func quit() { NSApp.terminate(nil) }
}
