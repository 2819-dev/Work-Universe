import AppKit
import ServiceManagement

// This app never reads the clipboard. It only writes a snippet to it
// when you click one.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let folderURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Snippet Menu", isDirectory: true)
    static let fileURL = folderURL.appendingPathComponent("snippets.txt")

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var result = ParseResult()
    private var loadError: String?        // the file can't be used at all
    private var shortcut: Shortcut?       // currently registered
    private var shortcutProblem: String?

    // MARK: Start up

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Snippets") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "✂︎"
            }
            button.toolTip = "Snippets"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        let firstRunKey = "createdExampleFile"
        if !UserDefaults.standard.bool(forKey: firstRunKey) {
            if !FileManager.default.fileExists(atPath: Self.fileURL.path) { _ = writeExampleFile() }
            UserDefaults.standard.set(true, forKey: firstRunKey)
        }

        reload()
        if loadError != nil || !result.problems.isEmpty || shortcutProblem != nil {
            showProblems()
        } else {
            HUD.show("Snippets ready · \(shortcut?.display ?? "") opens the menu", seconds: 2.5)
        }
    }

    // MARK: Reading the file

    private func reload() {
        loadError = nil
        result = ParseResult()
        let path = Self.fileURL.path

        if !FileManager.default.fileExists(atPath: path) {
            loadError = "Couldn't find your snippets file.\n\nIt should be at:\n\(path)\n\nChoose “Create example snippets file” from the ✂︎ menu to make a new one."
        } else if let content = try? String(contentsOf: Self.fileURL, encoding: .utf8) {
            result = SnippetParser.parse(content)
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                loadError = "Your snippets file is empty."
            } else if result.snippetCount == 0 {
                loadError = "No snippets found in your snippets file.\n\nEach snippet needs a line starting with ### (three hashes and a space) under a # Category line."
            }
        } else {
            loadError = "Couldn't read your snippets file. Make sure it's saved as plain text.\n\nIt's at:\n\(path)"
        }

        // Keyboard shortcut: from the file if given, otherwise Control+Option+S.
        shortcutProblem = nil
        var wanted = Shortcut.fallback
        if let setting = result.shortcut {
            if let parsed = Shortcut.parse(setting) {
                wanted = parsed
            } else {
                shortcutProblem = "The shortcut “\(setting)” wasn't understood, so \(Shortcut.fallback.display) is used instead. Write it like: Shortcut: control+option+s"
            }
        }
        if wanted != shortcut {
            if HotKey.register(wanted, action: { [weak self] in self?.showMenuAtMouse() }) {
                shortcut = wanted
            } else {
                shortcut = nil
                shortcutProblem = "The shortcut \(wanted.display) couldn't be turned on. Another app may be using it. Try a different one."
            }
        }
    }

    private func showProblems() {
        var parts: [String] = []
        if let loadError { parts.append(loadError) }
        if !result.problems.isEmpty {
            parts.append("Some snippets have mistakes (the others still work):\n• " + result.problems.joined(separator: "\n• "))
        }
        if let shortcutProblem { parts.append(shortcutProblem) }
        if parts.isEmpty {
            HUD.show("Snippets loaded")
        } else {
            showAlert("Snippet Menu: problem", parts.joined(separator: "\n\n"))
        }
    }

    // MARK: Building the menu

    // Called every time the menu opens, so it always shows the latest file.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        reload()
        menu.removeAllItems()

        if loadError != nil {
            menu.addItem(disabledItem("⚠️ Snippets couldn't be loaded"))
            menu.addItem(actionItem("Show details…", #selector(showProblemsAction)))
            if !FileManager.default.fileExists(atPath: Self.fileURL.path) {
                menu.addItem(actionItem("Create example snippets file", #selector(createExampleAction)))
            }
        } else {
            for category in result.categories {
                let items = categoryItems(category)
                guard !items.isEmpty else { continue }
                let submenu = NSMenu(title: category.title)
                submenu.autoenablesItems = false
                items.forEach(submenu.addItem)
                let item = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
                item.submenu = submenu
                menu.addItem(item)
            }
            if !result.problems.isEmpty || shortcutProblem != nil {
                menu.addItem(.separator())
                menu.addItem(actionItem("⚠️ Some problems found. Show details…", #selector(showProblemsAction)))
            }
        }

        menu.addItem(.separator())
        if let shortcut { menu.addItem(disabledItem("Shortcut: \(shortcut.display)")) }
        menu.addItem(actionItem("Edit snippets…", #selector(editSnippets)))
        menu.addItem(actionItem("Show snippets file in Finder", #selector(revealSnippets)))
        menu.addItem(actionItem("Reload snippets", #selector(reloadAction)))
        menu.addItem(.separator())
        let login = actionItem("Open at Login", #selector(toggleOpenAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(actionItem("Quit Snippet Menu", #selector(quit)))
    }

    private func categoryItems(_ category: Category) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        for sub in category.subcategories where !sub.snippets.isEmpty {
            let submenu = NSMenu(title: sub.title)
            submenu.autoenablesItems = false
            sub.snippets.map(snippetItem).forEach(submenu.addItem)
            let item = NSMenuItem(title: sub.title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            items.append(item)
        }
        if !items.isEmpty && !category.snippets.isEmpty { items.append(.separator()) }
        items += category.snippets.map(snippetItem)
        return items
    }

    private func snippetItem(_ snippet: Snippet) -> NSMenuItem {
        let item = actionItem(snippet.title, #selector(copySnippet(_:)))
        item.representedObject = snippet
        item.toolTip = snippet.text.count > 300 ? String(snippet.text.prefix(300)) + "…" : snippet.text
        return item
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: Actions

    private func showMenuAtMouse() {
        let previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        // Hand focus back so ⌘V pastes into the app you were using.
        if let previousApp, previousApp != NSRunningApplication.current {
            previousApp.activate(options: [])
        }
    }

    @objc private func copySnippet(_ sender: NSMenuItem) {
        guard let snippet = sender.representedObject as? Snippet else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
        HUD.show("Copied: \(snippet.title)")
    }

    @objc private func editSnippets() {
        if !FileManager.default.fileExists(atPath: Self.fileURL.path) {
            showAlert("No snippets file yet", "Choose “Create example snippets file” from the ✂︎ menu first.")
            return
        }
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        NSWorkspace.shared.open([Self.fileURL], withApplicationAt: textEdit,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func revealSnippets() {
        if FileManager.default.fileExists(atPath: Self.fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([Self.fileURL])
        } else {
            try? FileManager.default.createDirectory(at: Self.folderURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(Self.folderURL)
        }
    }

    @objc private func reloadAction() {
        reload()
        showProblems()
    }

    @objc private func showProblemsAction() {
        showProblems()
    }

    @objc private func createExampleAction() {
        if writeExampleFile() {
            reload()
            HUD.show("Example snippets file created")
            editSnippets()
        }
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showAlert("Couldn't change “Open at Login”",
                      "You can set it by hand: open System Settings → General → Login Items, click + under “Open at Login”, and choose Snippet Menu from Applications.\n\n(\(error.localizedDescription))")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: Helpers

    private func writeExampleFile() -> Bool {
        do {
            guard let example = Bundle.main.url(forResource: "example-snippets", withExtension: "txt") else {
                throw CocoaError(.fileNoSuchFile)
            }
            try FileManager.default.createDirectory(at: Self.folderURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: example, to: Self.fileURL)
            return true
        } catch {
            showAlert("Couldn't create the snippets file", error.localizedDescription)
            return false
        }
    }

    private func showAlert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.runModal()
    }
}
