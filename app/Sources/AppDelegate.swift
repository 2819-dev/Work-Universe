import AppKit
import ServiceManagement

// This app never reads the clipboard. It only writes a snippet to it
// when you choose one.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SnippetStore()
    private var model: PanelModel!
    private var panel: SidePanelController!
    private var statusItem: NSStatusItem!

    private enum Keys {
        static let launchedBefore = "createdExampleFile"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
    }

    // MARK: Start up

    func applicationDidFinishLaunching(_ notification: Notification) {
        let firstLaunch = !UserDefaults.standard.bool(forKey: Keys.launchedBefore)
        if firstLaunch {
            if !store.fileExists { store.createStarterLibrary() }
            UserDefaults.standard.set(true, forKey: Keys.launchedBefore)
        }
        store.reload()

        model = PanelModel(shortcut: savedShortcut())
        model.applyShortcut = { [weak self] shortcut in self?.applyShortcut(shortcut) ?? false }
        model.pauseShortcut = { [weak self] paused in
            guard let self else { return }
            if paused { HotKey.unregister() } else { _ = self.registerHotKey(self.model.shortcut) }
        }
        model.isOpenAtLogin = { SMAppService.mainApp.status == .enabled }
        model.setOpenAtLogin = { [weak self] enabled in self?.setOpenAtLogin(enabled) }
        panel = SidePanelController(store: store, model: model)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Snippet Menu") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "✂︎"
            }
            button.toolTip = "Snippet Menu"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if !registerHotKey(model.shortcut) {
            HUD.show("The shortcut \(model.shortcut.display) is in use by another app. Choose a new one in Snippet Menu.", seconds: 4)
        }

        let problem = store.loadError != nil || !store.problems.isEmpty
        if firstLaunch || problem || ProcessInfo.processInfo.environment["SNIPPETMENU_SHOW_PANEL"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showPanelForLaunch() }
        } else {
            HUD.show("Snippet Menu is ready · \(model.shortcut.display) opens your snippets", seconds: 2.5)
        }
    }

    private func showPanelForLaunch() {
        panel.show()
        // Used to capture preview images of a category page.
        if ProcessInfo.processInfo.environment["SNIPPETMENU_SHOW_PANEL"] == "category",
           let first = store.categories.first(where: { !$0.subcategories.isEmpty }) ?? store.categories.first {
            model.push(.category(first.id))
        }
    }

    // MARK: Menu bar icon

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            panel.hide()
            let menu = quickMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
        } else {
            panel.toggle()
        }
    }

    // MARK: Quick menu (keyboard shortcut)

    private func showQuickMenuAtMouse() {
        panel.hide()
        let previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        quickMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        // Hand focus back so ⌘V pastes into the app you were using.
        if let previousApp, previousApp != NSRunningApplication.current, !panel.isVisible {
            previousApp.activate(options: [])
        }
    }

    private func quickMenu() -> NSMenu {
        store.reloadIfChanged()
        let menu = NSMenu()
        menu.autoenablesItems = false

        if store.loadError != nil {
            let item = NSMenuItem(title: "Your snippets couldn't be loaded", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else if store.categories.allSatisfy({ $0.snippetCount == 0 }) {
            let item = NSMenuItem(title: "No snippets yet", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for category in store.categories where category.snippetCount > 0 {
                let submenu = NSMenu(title: category.title)
                submenu.autoenablesItems = false
                for sub in category.subcategories where !sub.snippets.isEmpty {
                    let subItem = NSMenuItem(title: sub.title, action: nil, keyEquivalent: "")
                    subItem.submenu = NSMenu(title: sub.title)
                    sub.snippets.forEach { subItem.submenu?.addItem(snippetItem($0)) }
                    submenu.addItem(subItem)
                }
                if submenu.numberOfItems > 0 && !category.snippets.isEmpty { submenu.addItem(.separator()) }
                category.snippets.forEach { submenu.addItem(snippetItem($0)) }

                let item = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
                item.submenu = submenu
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let manage = NSMenuItem(title: "Manage Snippets…", action: #selector(openPanel), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)
        return menu
    }

    private func snippetItem(_ snippet: Snippet) -> NSMenuItem {
        let item = NSMenuItem(title: snippet.title, action: #selector(copySnippet(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = snippet
        item.toolTip = snippet.text.count > 300 ? String(snippet.text.prefix(300)) + "…" : snippet.text
        return item
    }

    @objc private func copySnippet(_ sender: NSMenuItem) {
        guard let snippet = sender.representedObject as? Snippet else { return }
        model.copy(snippet)
    }

    @objc private func openPanel() {
        DispatchQueue.main.async { self.panel.show() }
    }

    // MARK: Keyboard shortcut

    private func savedShortcut() -> Shortcut {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Keys.shortcutKeyCode) != nil,
              let saved = Shortcut.make(keyCode: UInt32(defaults.integer(forKey: Keys.shortcutKeyCode)),
                                        carbonModifiers: UInt32(defaults.integer(forKey: Keys.shortcutModifiers)))
        else { return Shortcut.fallback }
        return saved
    }

    private func registerHotKey(_ shortcut: Shortcut) -> Bool {
        HotKey.register(shortcut) { [weak self] in self?.showQuickMenuAtMouse() }
    }

    private func applyShortcut(_ shortcut: Shortcut) -> Bool {
        guard registerHotKey(shortcut) else {
            _ = registerHotKey(model.shortcut)
            return false
        }
        model.shortcut = shortcut
        UserDefaults.standard.set(Int(shortcut.keyCode), forKey: Keys.shortcutKeyCode)
        UserDefaults.standard.set(Int(shortcut.carbonModifiers), forKey: Keys.shortcutModifiers)
        return true
    }

    // MARK: Open at Login

    private func setOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "“Open at Login” couldn't be changed."
            alert.informativeText = "You can set it in System Settings → General → Login Items: click + under “Open at Login” and choose Snippet Menu."
            alert.alertStyle = .warning
            alert.runModal()
        }
        refreshPanel()
    }

    // Refreshes the panel so the Open at Login checkmark is current.
    private func refreshPanel() {
        model.objectWillChange.send()
    }
}
