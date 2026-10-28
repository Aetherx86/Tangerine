import Foundation
import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public override init() {
        super.init()
    }
    private var statusItem: NSStatusItem?
    private var dropZoneWindow: NSWindow?
    private var settingsWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApplication.shared.servicesProvider = self
        NSUpdateDynamicServices()

        setupStatusItem()
        EventMonitor.shared.start()
        FolderWatcherService.shared.start()
    }

    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let style = SettingsStore.shared.menuBarIconStyle
        item.button?.image = IconProvider.menuBarImage(style: style)
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Tangerine — Instant File Tools & Conversions"

        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "Tangerine", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "Tangerine",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let dropZoneItem = NSMenuItem(title: "Open Drop Zone / Simulator…", action: #selector(openDropZone), keyEquivalent: "d")
        dropZoneItem.target = self
        menu.addItem(dropZoneItem)

        let convertFinderItem = NSMenuItem(title: "Convert Finder Selection", action: #selector(convertFinderSelection), keyEquivalent: "c")
        convertFinderItem.keyEquivalentModifierMask = [.command, .option]
        convertFinderItem.target = self
        menu.addItem(convertFinderItem)

        let summonMenu = NSMenuItem(title: "Summon Wheel at Cursor", action: nil, keyEquivalent: "")
        let subMenu = NSMenu()
        let convItem = NSMenuItem(title: "Convert Formats (Shift)", action: #selector(summonConvert), keyEquivalent: "")
        convItem.target = self
        let toolsItem = NSMenuItem(title: "File Tools (Command)", action: #selector(summonTools), keyEquivalent: "")
        toolsItem.target = self
        let actItem = NSMenuItem(title: "File Actions (Control)", action: #selector(summonActions), keyEquivalent: "")
        actItem.target = self
        subMenu.addItem(convItem)
        subMenu.addItem(toolsItem)
        subMenu.addItem(actItem)
        summonMenu.submenu = subMenu
        menu.addItem(summonMenu)

        menu.addItem(NSMenuItem.separator())

        let shelfItem = NSMenuItem(title: "Toggle Floating Shelf", action: #selector(toggleShelf), keyEquivalent: "s")
        shelfItem.target = self
        menu.addItem(shelfItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Tangerine", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    public func menuWillOpen(_ menu: NSMenu) {
        if AXIsProcessTrusted() {
            EventMonitor.shared.start()
        }
    }

    public func updateIconStyle() {
        let style = SettingsStore.shared.menuBarIconStyle
        statusItem?.button?.image = IconProvider.menuBarImage(style: style)
    }

    @objc private func openDropZone() {
        if dropZoneWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Tangerine Drop Zone"
            window.center()
            window.contentView = NSHostingView(rootView: DropZoneView())
            self.dropZoneWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        dropZoneWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Tangerine Settings"
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView())
            self.settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleShelf() {
        let manager = FloatingShelfManager.shared
        if manager.isVisible {
            manager.hideShelf()
        } else {
            manager.showShelf()
        }
    }

    @objc private func convertFinderSelection() {
        let urls = EventMonitor.shared.getFinderSelection()
        guard !urls.isEmpty else {
            openDropZone()
            return
        }
        let point = NSEvent.mouseLocation
        RadialWheelController.shared.show(at: point, mode: .convert, urls: urls)
    }

    /// NSServices message handler: Finder context menu "Convert with Tangerine"
    @objc public func convertFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>?) {
        var urls: [URL] = []
        if let items = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            urls.append(contentsOf: items.filter { $0.isFileURL })
        }
        if urls.isEmpty, let paths = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls.append(contentsOf: paths.map { URL(fileURLWithPath: $0) })
        }
        guard !urls.isEmpty else { return }
        let point = NSEvent.mouseLocation
        RadialWheelController.shared.show(at: point, mode: .convert, urls: urls)
    }

    @objc private func summonConvert() {
        summonForFinder(mode: .convert)
    }

    @objc private func summonTools() {
        summonForFinder(mode: .tools)
    }

    @objc private func summonActions() {
        summonForFinder(mode: .actions)
    }

    private func summonForFinder(mode: WheelMode) {
        let urls = EventMonitor.shared.getActiveDraggedOrSelectedURLs()
        let point = NSEvent.mouseLocation
        RadialWheelController.shared.show(at: point, mode: mode, urls: urls)
    }

    @objc private func openPermissions() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            EventMonitor.shared.start()
        } else {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
