import AppKit
import ServiceManagement

// QuickSnip never reads the clipboard. It only writes a snippet to it
// when you choose one.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SnippetStore!
    private var quickSnippets: QuickSnippetStore!
    private var shortcuts: ShortcutManager!
    private var notepads: NotepadWindows!
    private var model: PanelModel!
    private var panel: SidePanelController!
    private var updater: Updater!
    private var statusItem: NSStatusItem!

    private static let mainHotKeyID: UInt32 = 1
    private let preview = ProcessInfo.processInfo.environment["QUICKSNIP_PREVIEW"]

    private enum Keys {
        static let launchedBefore = "createdExampleFile"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
        static let removedSamples = "removedSampleSnippets"
        static let lastVersion = "lastVersion"
        static let reenableOpenAtLogin = "reenableOpenAtLogin"
    }

    // MARK: Start up

    func applicationDidFinishLaunching(_ notification: Notification) {
        if renameLegacyAppIfNeeded() { return }

        let defaults = UserDefaults.standard
        SnippetStore.moveLegacyLibrary()
        store = SnippetStore()
        quickSnippets = QuickSnippetStore()
        shortcuts = ShortcutManager()
        notepads = NotepadWindows(store: quickSnippets)

        let firstLaunch = !defaults.bool(forKey: Keys.launchedBefore)
        if firstLaunch {
            if !store.fileExists { store.createEmptyLibrary() }
            defaults.set(true, forKey: Keys.launchedBefore)
        }
        store.reload()
        if !defaults.bool(forKey: Keys.removedSamples) {
            store.removeSampleSnippets()
            defaults.set(true, forKey: Keys.removedSamples)
        }
        store.updateLibraryNotes()

        let previousVersion = defaults.string(forKey: Keys.lastVersion)
        defaults.set(Updater.currentVersion, forKey: Keys.lastVersion)
        let justUpdated = previousVersion != nil && previousVersion != Updater.currentVersion

        if defaults.bool(forKey: Keys.reenableOpenAtLogin) {
            try? SMAppService.mainApp.register()
            defaults.removeObject(forKey: Keys.reenableOpenAtLogin)
        }

        model = PanelModel(shortcut: savedShortcut())
        model.applyShortcut = { [weak self] shortcut in self?.applyMainShortcut(shortcut) }
        model.pauseShortcuts = { [weak self] paused in self?.pauseShortcuts(paused) }
        model.isOpenAtLogin = { SMAppService.mainApp.status == .enabled }
        model.setOpenAtLogin = { [weak self] enabled in self?.setOpenAtLogin(enabled) }
        model.openQuickSnippet = { [weak self] id in self?.notepads.open(id) }

        store.remapShortcuts = { [weak self] transform in self?.shortcuts.remap(transform) }
        shortcuts.mainShortcut = { [weak self] in self?.model.shortcut ?? Shortcut.fallback }
        shortcuts.perform = { [weak self] target in self?.perform(target) }

        panel = SidePanelController(store: store, quickSnippets: quickSnippets, shortcuts: shortcuts, model: model)
        updater = Updater(model: model)
        updater.start()
        if ProcessInfo.processInfo.environment["QUICKSNIP_PREVIEW_UPDATE"] != nil {
            model.update = .available(version: "9.9.9") // used to capture a preview image of the update footer
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "scissors", accessibilityDescription: Brand.name) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "✂︎"
            }
            button.toolTip = Brand.name
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let mainOK = registerMainHotKey(model.shortcut)
        let failed = shortcuts.registerAll()
        if !mainOK || !failed.isEmpty {
            HUD.show("Some keyboard shortcuts are used by another app. Choose new ones under ••• → Keyboard Shortcuts.", seconds: 4)
        }

        let problem = store.loadError != nil || !store.problems.isEmpty
        if firstLaunch || problem || preview != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showPanelForLaunch() }
        } else if justUpdated {
            HUD.show("\(Brand.name) has been updated to version \(Updater.currentVersion)", seconds: 3)
        } else {
            HUD.show("\(Brand.name) is ready · \(model.shortcut.display) opens your snippets", seconds: 2.5)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        quickSnippets?.saveNow()
    }

    private func showPanelForLaunch() {
        guard let preview, preview != "home" else {
            panel.show()
            return
        }
        // Used to capture preview images of the app's pages.
        let first = store.categories.first(where: { !$0.subcategories.isEmpty }) ?? store.categories.first
        switch preview {
        case "folder", "add":
            panel.show()
            if let first { model.push(.category(first.id)) }
        case "subfolder":
            panel.show()
            if let first, let sub = first.subcategories.first {
                model.stack = [.categories, .category(first.id), .subcategory(first.id, sub.id)]
            }
        case "about":
            panel.show()
            model.push(.about)
        case "support":
            panel.show()
            model.push(.support)
        case "shortcuts":
            panel.show()
            model.push(.shortcutList)
        case "notepad":
            panel.show()
            if let note = quickSnippets.notes.first { notepads.open(note.id) }
        default:
            panel.show()
        }
    }

    /// Earlier versions were called "Snippet Menu". Renames the app in place
    /// and reopens it. Returns true when the app is about to reopen.
    private func renameLegacyAppIfNeeded() -> Bool {
        let appURL = Bundle.main.bundleURL
        guard appURL.lastPathComponent == "Snippet Menu.app" else { return false }
        let newURL = appURL.deletingLastPathComponent().appendingPathComponent("\(Brand.name).app")
        let fm = FileManager.default
        guard !appURL.path.contains("/AppTranslocation/"),
              !fm.fileExists(atPath: newURL.path),
              fm.isWritableFile(atPath: appURL.deletingLastPathComponent().path) else { return false }

        let wasOpenAtLogin = SMAppService.mainApp.status == .enabled
        if wasOpenAtLogin { try? SMAppService.mainApp.unregister() }
        do {
            try fm.moveItem(at: appURL, to: newURL)
        } catch {
            if wasOpenAtLogin { try? SMAppService.mainApp.register() }
            return false
        }
        UserDefaults.standard.set(wasOpenAtLogin, forKey: Keys.reenableOpenAtLogin)
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", newURL.path]
        try? relaunch.run()
        DispatchQueue.main.async { NSApp.terminate(nil) }
        return true
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

    // MARK: Keyboard shortcut actions

    private func perform(_ target: ShortcutTarget) {
        store.reloadIfChanged()
        switch target {
        case .folder(let name):
            guard let folder = store.categories.first(where: { $0.title == name }) else {
                return HUD.show("The folder “\(name)” no longer exists")
            }
            panel.show()
            model.stack = [.categories, .category(folder.id)]

        case .subfolder(let folderName, let subName):
            guard let folder = store.categories.first(where: { $0.title == folderName }),
                  let sub = folder.subcategories.first(where: { $0.title == subName }) else {
                return HUD.show("The subfolder “\(subName)” no longer exists")
            }
            panel.show()
            model.stack = [.categories, .category(folder.id), .subcategory(folder.id, sub.id)]

        case .snippet(let folderName, let subName, let title):
            let folder = store.categories.first { $0.title == folderName }
            let snippets = subName.map { name in folder?.subcategories.first { $0.title == name }?.snippets ?? [] }
                ?? folder?.snippets ?? []
            guard let snippet = snippets.first(where: { $0.title == title }) else {
                return HUD.show("The snippet “\(title)” no longer exists")
            }
            model.copy(snippet)

        case .quickSnippet(let id):
            panel.hide()
            notepads.open(id)
        }
    }

    // MARK: Quick menu

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
            menu.addItem(disabledItem("Your library couldn't be loaded"))
        } else if store.categories.allSatisfy({ $0.snippetCount == 0 }) && quickSnippets.notes.isEmpty {
            menu.addItem(disabledItem("No snippets yet"))
        } else {
            for folder in store.categories where folder.snippetCount > 0 {
                let submenu = NSMenu(title: folder.title)
                submenu.autoenablesItems = false
                for sub in folder.subcategories where !sub.snippets.isEmpty {
                    let subItem = NSMenuItem(title: sub.title, action: nil, keyEquivalent: "")
                    subItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                    subItem.submenu = NSMenu(title: sub.title)
                    sub.snippets.forEach { subItem.submenu?.addItem(snippetItem($0)) }
                    submenu.addItem(subItem)
                }
                if submenu.numberOfItems > 0 && !folder.snippets.isEmpty { submenu.addItem(.separator()) }
                folder.snippets.forEach { submenu.addItem(snippetItem($0)) }

                let item = NSMenuItem(title: folder.title, action: nil, keyEquivalent: "")
                item.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                item.submenu = submenu
                menu.addItem(item)
            }
            if !quickSnippets.notes.isEmpty {
                let submenu = NSMenu(title: "Quick Snippets")
                for note in quickSnippets.notes {
                    let item = NSMenuItem(title: note.displayTitle, action: #selector(openQuickSnippet(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = note.id
                    submenu.addItem(item)
                }
                let item = NSMenuItem(title: "Quick Snippets", action: nil, keyEquivalent: "")
                item.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: nil)
                item.submenu = submenu
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        if case .available(let version) = model.update {
            let update = NSMenuItem(title: "Update Available (Version \(version))…", action: #selector(openPanel), keyEquivalent: "")
            update.target = self
            menu.addItem(update)
        }
        let newNote = NSMenuItem(title: "New Quick Snippet", action: #selector(newQuickSnippet), keyEquivalent: "")
        newNote.target = self
        menu.addItem(newNote)
        let manage = NSMenuItem(title: "Open \(Brand.name)…", action: #selector(openPanel), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)
        return menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
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

    @objc private func openQuickSnippet(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        DispatchQueue.main.async { self.notepads.open(id) }
    }

    @objc private func newQuickSnippet() {
        let id = quickSnippets.add()
        DispatchQueue.main.async { self.notepads.open(id) }
    }

    @objc private func openPanel() {
        DispatchQueue.main.async { self.panel.show() }
    }

    // MARK: Main keyboard shortcut

    private func savedShortcut() -> Shortcut {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Keys.shortcutKeyCode) != nil,
              let saved = Shortcut.make(keyCode: UInt32(defaults.integer(forKey: Keys.shortcutKeyCode)),
                                        carbonModifiers: UInt32(defaults.integer(forKey: Keys.shortcutModifiers)))
        else { return Shortcut.fallback }
        return saved
    }

    private func registerMainHotKey(_ shortcut: Shortcut) -> Bool {
        HotKey.register(id: Self.mainHotKeyID, shortcut) { [weak self] in self?.showQuickMenuAtMouse() }
    }

    private func applyMainShortcut(_ shortcut: Shortcut) -> String? {
        if let other = shortcuts.bindings.first(where: {
            Shortcut.make(keyCode: $0.keyCode, carbonModifiers: $0.modifiers) == shortcut
        }) {
            return "\(shortcut.display) is already used for “\(describeTarget(other.target, quickSnippets: quickSnippets))”. Please choose a different shortcut."
        }
        guard registerMainHotKey(shortcut) else {
            _ = registerMainHotKey(model.shortcut)
            return "\(shortcut.display) is already used by another app. Please choose a different shortcut."
        }
        model.shortcut = shortcut
        UserDefaults.standard.set(Int(shortcut.keyCode), forKey: Keys.shortcutKeyCode)
        UserDefaults.standard.set(Int(shortcut.carbonModifiers), forKey: Keys.shortcutModifiers)
        return nil
    }

    private func pauseShortcuts(_ paused: Bool) {
        if paused {
            HotKey.unregister(id: Self.mainHotKeyID)
            shortcuts.unregisterAll()
        } else {
            _ = registerMainHotKey(model.shortcut)
            shortcuts.registerAll()
        }
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
            alert.informativeText = "You can set it in System Settings → General → Login Items: click + under “Open at Login” and choose \(Brand.name)."
            alert.alertStyle = .warning
            alert.runModal()
        }
        model.objectWillChange.send()
    }
}
