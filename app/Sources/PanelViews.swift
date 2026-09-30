import AppKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var quickSnippets: QuickSnippetStore
    @ObservedObject var shortcuts: ShortcutManager
    @ObservedObject var model: PanelModel

    var body: some View {
        screen
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .tint(Brand.accent)
    }

    @ViewBuilder private var screen: some View {
        switch model.current {
        case .categories:
            HomeScreen(store: store, quickSnippets: quickSnippets, shortcuts: shortcuts, model: model)

        case .category(let id):
            FolderScreen(store: store, shortcuts: shortcuts, model: model, folderID: id)

        case .subcategory(let folderID, let subfolderID):
            SubfolderScreen(store: store, shortcuts: shortcuts, model: model, folderID: folderID, subfolderID: subfolderID)

        case .newCategory:
            NameEditorScreen(heading: "New Folder", label: "Folder name", initial: "", saveTitle: "Create",
                             onSave: { name in
                                 if let id = store.addCategory(name) { model.replaceTop(.category(id)) }
                             }, onCancel: model.pop)

        case .renameCategory(let id):
            NameEditorScreen(heading: "Rename Folder", label: "Folder name",
                             initial: store.category(id)?.title ?? "", saveTitle: "Save",
                             onSave: { name in store.renameCategory(id, to: name); model.pop() },
                             onCancel: model.pop)

        case .newSubcategory(let folderID):
            NameEditorScreen(heading: "New Subfolder", label: "Subfolder name", initial: "", saveTitle: "Create",
                             onSave: { name in
                                 if let id = store.addSubcategory(name, to: folderID) {
                                     model.replaceTop(.subcategory(folderID, id))
                                 }
                             }, onCancel: model.pop)

        case .renameSubcategory(let folderID, let subfolderID):
            NameEditorScreen(heading: "Rename Subfolder", label: "Subfolder name",
                             initial: store.subcategory(folderID, subfolderID)?.title ?? "", saveTitle: "Save",
                             onSave: { name in
                                 store.renameSubcategory(folderID, subfolderID, to: name)
                                 model.pop()
                             }, onCancel: model.pop)

        case .snippetEditor(let folderID, let subfolderID, let snippetID):
            let existing = snippetID.flatMap { store.snippet($0, in: folderID, subfolderID) }
            SnippetEditorScreen(
                heading: existing == nil ? "New Snippet" : "Edit Snippet",
                location: locationText(folderID, subfolderID),
                initialTitle: existing?.title ?? "",
                initialText: existing?.text ?? "",
                onSave: { title, text in
                    store.saveSnippet(id: existing?.id, title: title, text: text, in: folderID, subfolderID)
                    model.pop()
                },
                onDelete: existing.map { snippet -> () -> Void in
                    return {
                        confirmDelete("Delete “\(snippet.title)”?", detail: "This snippet will be permanently removed.") {
                            store.deleteSnippet(snippet.id, in: folderID, subfolderID)
                            model.pop()
                        }
                    }
                },
                onCancel: model.pop)

        case .shortcut:
            ShortcutRecorderScreen(
                heading: "Quick Menu Shortcut",
                subject: nil,
                explanation: "Press this shortcut in any app to open your snippets in a menu right where your pointer is.",
                current: model.shortcut,
                model: model,
                onApply: model.applyShortcut,
                onRemove: nil,
                onRestoreDefault: { model.applyShortcut(Shortcut.fallback) })

        case .itemShortcut(let target):
            ShortcutRecorderScreen(
                heading: "Keyboard Shortcut",
                subject: describeTarget(target, quickSnippets: quickSnippets),
                explanation: explanation(for: target),
                current: shortcuts.shortcut(for: target),
                model: model,
                onApply: { shortcut in
                    shortcuts.assign(shortcut, to: target) { describeTarget($0, quickSnippets: quickSnippets) }
                },
                onRemove: { shortcuts.remove(target) },
                onRestoreDefault: nil)

        case .shortcutList:
            ShortcutListScreen(quickSnippets: quickSnippets, shortcuts: shortcuts, model: model)

        case .about:
            AboutScreen(model: model)

        case .support:
            SupportScreen(model: model)
        }
    }

    private func locationText(_ folderID: UUID, _ subfolderID: UUID?) -> String {
        var parts = [store.category(folderID)?.title ?? ""]
        if let subfolderID, let sub = store.subcategory(folderID, subfolderID) { parts.append(sub.title) }
        return parts.joined(separator: " › ")
    }

    private func explanation(for target: ShortcutTarget) -> String {
        switch target {
        case .folder: return "Press this shortcut in any app to open this folder in \(Brand.name)."
        case .subfolder: return "Press this shortcut in any app to open this subfolder in \(Brand.name)."
        case .snippet: return "Press this shortcut in any app to copy this snippet instantly."
        case .quickSnippet: return "Press this shortcut in any app to open this Quick Snippet."
        }
    }
}

// MARK: - Home

private struct HomeScreen: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var quickSnippets: QuickSnippetStore
    @ObservedObject var shortcuts: ShortcutManager
    @ObservedObject var model: PanelModel

    private var addOptions: [AddOption] {
        [
            AddOption(title: "New Folder", systemImage: "folder.badge.plus") { model.push(.newCategory) },
            AddOption(title: "New Quick Snippet", systemImage: "square.and.pencil") { newQuickSnippet() },
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: Brand.name) {
                AddButton(options: addOptions)
                MoreMenu(model: model)
                CloseButton(model: model)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    StatusBanners(store: store)
                    if store.categories.isEmpty && quickSnippets.notes.isEmpty && store.loadError == nil {
                        EmptyState(systemImage: "square.stack.3d.up",
                                   title: "Welcome to \(Brand.name)",
                                   message: "Create a folder for the replies you use again and again, or a Quick Snippet for text you need right now.",
                                   actions: addOptions)
                    }
                    if !store.categories.isEmpty {
                        SectionTitle("Folders")
                        LazyVStack(spacing: 2) {
                            ForEach(store.categories) { folder in
                                folderRow(folder)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    if !quickSnippets.notes.isEmpty {
                        SectionTitle("Quick Snippets")
                        LazyVStack(spacing: 2) {
                            ForEach(quickSnippets.notes) { note in
                                quickSnippetRow(note)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 6)
            }
            PanelFooter(model: model)
        }
    }

    private func folderRow(_ folder: Category) -> some View {
        let target = ShortcutTarget.folder(folder.title)
        return ListRow(title: folder.title,
                       subtitle: summary(folder),
                       systemImage: "folder.fill",
                       shortcut: shortcuts.shortcut(for: target)) { model.push(.category(folder.id)) }
            .contextMenu {
                Button("Rename…") { model.push(.renameCategory(folder.id)) }
                Button("Keyboard Shortcut…") { model.push(.itemShortcut(target)) }
                Divider()
                Button("Delete…", role: .destructive) {
                    confirmDelete("Delete “\(folder.title)”?",
                                  detail: "This folder and everything in it will be permanently removed.") {
                        store.deleteCategory(folder.id)
                    }
                }
            }
    }

    private func quickSnippetRow(_ note: QuickSnippet) -> some View {
        let target = ShortcutTarget.quickSnippet(note.id)
        return ListRow(title: note.displayTitle,
                       subtitle: note.preview,
                       systemImage: "note.text",
                       iconColor: .secondary,
                       shortcut: shortcuts.shortcut(for: target),
                       showsChevron: false) { model.openQuickSnippet(note.id) }
            .contextMenu {
                Button("Open") { model.openQuickSnippet(note.id) }
                Button("Copy") {
                    copyToClipboard(note.text)
                    HUD.show("Copied: \(note.displayTitle)")
                }
                Button("Keyboard Shortcut…") { model.push(.itemShortcut(target)) }
                Divider()
                Button("Delete…", role: .destructive) {
                    confirmDelete("Delete “\(note.displayTitle)”?", detail: "This Quick Snippet will be permanently removed.") {
                        quickSnippets.delete(note.id)
                        shortcuts.remap { $0 == target ? nil : $0 }
                    }
                }
            }
    }

    private func newQuickSnippet() {
        let id = quickSnippets.add()
        model.openQuickSnippet(id)
    }

    private func summary(_ folder: Category) -> String {
        var parts = [countText(folder.snippetCount, "snippet")]
        if !folder.subcategories.isEmpty { parts.append(countText(folder.subcategories.count, "subfolder")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Folders

private struct FolderScreen: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var shortcuts: ShortcutManager
    @ObservedObject var model: PanelModel
    let folderID: UUID

    var body: some View {
        if let folder = store.category(folderID) {
            VStack(spacing: 0) {
                PanelHeader(title: folder.title, backTitle: Brand.name, onBack: model.pop) {
                    AddButton(options: [
                        AddOption(title: "Add Snippet", systemImage: "text.badge.plus") {
                            model.push(.snippetEditor(category: folderID, subcategory: nil, snippet: nil))
                        },
                        AddOption(title: "Add Subfolder", systemImage: "folder.badge.plus") {
                            model.push(.newSubcategory(folderID))
                        },
                    ])
                    .disabled(!store.canEdit)
                    CloseButton(model: model)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusBanners(store: store)
                        if folder.subcategories.isEmpty && folder.snippets.isEmpty {
                            EmptyState(systemImage: "tray",
                                       title: "This folder is empty",
                                       message: "Use the + button to add a snippet or a subfolder.")
                        }
                        if !folder.subcategories.isEmpty {
                            SectionTitle("Subfolders")
                            LazyVStack(spacing: 2) {
                                ForEach(folder.subcategories) { sub in
                                    subfolderRow(folder, sub)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        if !folder.snippets.isEmpty {
                            SectionTitle("Snippets")
                            SnippetList(store: store, shortcuts: shortcuts, model: model, snippets: folder.snippets,
                                        folderID: folderID, subfolderID: nil)
                        }
                    }
                    .padding(.vertical, 6)
                }
                PanelFooter(model: model)
            }
        } else {
            Color.clear.onAppear { model.reset() }
        }
    }

    private func subfolderRow(_ folder: Category, _ sub: Subcategory) -> some View {
        let target = ShortcutTarget.subfolder(folder.title, sub.title)
        return ListRow(title: sub.title,
                       subtitle: countText(sub.snippets.count, "snippet"),
                       systemImage: "folder",
                       shortcut: shortcuts.shortcut(for: target)) { model.push(.subcategory(folderID, sub.id)) }
            .contextMenu {
                Button("Rename…") { model.push(.renameSubcategory(folderID, sub.id)) }
                Button("Keyboard Shortcut…") { model.push(.itemShortcut(target)) }
                Divider()
                Button("Delete…", role: .destructive) {
                    confirmDelete("Delete “\(sub.title)”?",
                                  detail: "This subfolder and all of its snippets will be permanently removed.") {
                        store.deleteSubcategory(folderID, sub.id)
                    }
                }
            }
    }
}

private struct SubfolderScreen: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var shortcuts: ShortcutManager
    @ObservedObject var model: PanelModel
    let folderID: UUID
    let subfolderID: UUID

    var body: some View {
        if let folder = store.category(folderID), let sub = store.subcategory(folderID, subfolderID) {
            VStack(spacing: 0) {
                PanelHeader(title: sub.title, backTitle: folder.title, onBack: model.pop) {
                    AddButton(options: [
                        AddOption(title: "Add Snippet", systemImage: "text.badge.plus") {
                            model.push(.snippetEditor(category: folderID, subcategory: subfolderID, snippet: nil))
                        },
                    ])
                    .disabled(!store.canEdit)
                    CloseButton(model: model)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusBanners(store: store)
                        if sub.snippets.isEmpty {
                            EmptyState(systemImage: "tray",
                                       title: "No snippets yet",
                                       message: "Use the + button to add your first snippet here.")
                        } else {
                            SnippetList(store: store, shortcuts: shortcuts, model: model, snippets: sub.snippets,
                                        folderID: folderID, subfolderID: subfolderID)
                        }
                    }
                    .padding(.vertical, 6)
                }
                PanelFooter(model: model)
            }
        } else {
            Color.clear.onAppear { model.reset() }
        }
    }
}

private struct SnippetList: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var shortcuts: ShortcutManager
    @ObservedObject var model: PanelModel
    let snippets: [Snippet]
    let folderID: UUID
    let subfolderID: UUID?

    var body: some View {
        LazyVStack(spacing: 2) {
            ForEach(snippets) { snippet in
                let target = store.target(folderID, subfolderID, snippet: snippet.id)
                SnippetRow(snippet: snippet,
                           copied: model.copiedSnippetID == snippet.id,
                           shortcut: target.flatMap(shortcuts.shortcut(for:)),
                           onCopy: { model.copy(snippet) },
                           onEdit: edit(snippet))
                    .contextMenu {
                        Button("Copy") { model.copy(snippet) }
                        Button("Edit…", action: edit(snippet))
                        if let target {
                            Button("Keyboard Shortcut…") { model.push(.itemShortcut(target)) }
                        }
                        Divider()
                        Button("Delete…", role: .destructive) {
                            confirmDelete("Delete “\(snippet.title)”?", detail: "This snippet will be permanently removed.") {
                                store.deleteSnippet(snippet.id, in: folderID, subfolderID)
                            }
                        }
                    }
            }
        }
        .padding(.horizontal, 8)
    }

    private func edit(_ snippet: Snippet) -> () -> Void {
        { model.push(.snippetEditor(category: folderID, subcategory: subfolderID, snippet: snippet.id)) }
    }
}

// MARK: - Editors

private struct NameEditorScreen: View {
    let heading: String
    let label: String
    let initial: String
    let saveTitle: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: heading) { EmptyView() }
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(.callout.weight(.medium))
                TextField("", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { if !trimmed.isEmpty { onSave(trimmed) } }
            }
            .padding(.horizontal, 16)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button(saveTitle) { onSave(trimmed) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
            .padding(16)
            Spacer()
        }
        .onAppear {
            name = initial
            DispatchQueue.main.async { focused = true }
        }
    }
}

private struct SnippetEditorScreen: View {
    let heading: String
    let location: String
    let initialTitle: String
    let initialText: String
    let onSave: (String, String) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var title = ""
    @State private var text = ""
    @FocusState private var titleFocused: Bool

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: heading) { EmptyView() }
            VStack(alignment: .leading, spacing: 14) {
                Label(location, systemImage: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Title").font(.callout.weight(.medium))
                    TextField("", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFocused)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Text to copy").font(.callout.weight(.medium))
                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .textBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.secondary.opacity(0.35)))
                        .frame(minHeight: 180, maxHeight: .infinity)
                }

                HStack {
                    if let onDelete {
                        Button(role: .destructive, action: onDelete) { Text("Delete") }
                    }
                    Spacer()
                    Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                    Button("Save") { onSave(title, text) }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                }
                Text("Press ⌘Return to save.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onAppear {
            title = initialTitle
            text = initialText
            if initialTitle.isEmpty { DispatchQueue.main.async { titleFocused = true } }
        }
    }
}

// MARK: - Keyboard shortcuts

private struct ShortcutRecorderScreen: View {
    let heading: String
    let subject: String?
    let explanation: String
    let current: Shortcut?
    @ObservedObject var model: PanelModel
    /// Returns a message when the shortcut can't be used.
    let onApply: (Shortcut) -> String?
    let onRemove: (() -> Void)?
    let onRestoreDefault: (() -> String?)?

    @State private var recording = false
    @State private var message: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: heading, backTitle: "Back", onBack: { stop(); model.pop() }) {
                CloseButton(model: model)
            }
            VStack(alignment: .leading, spacing: 14) {
                if let subject {
                    Text(subject)
                        .font(.headline)
                        .lineLimit(2)
                }
                Text(explanation)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(recording ? "Type your new shortcut" : (current?.display ?? "No shortcut"))
                    .font(.system(size: recording || current == nil ? 15 : 24, weight: .semibold, design: .rounded))
                    .foregroundColor(recording ? Brand.accent : (current == nil ? .secondary : .primary))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(recording ? Brand.accent : Color.secondary.opacity(0.25),
                                      lineWidth: recording ? 2 : 1))

                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button(recording ? "Cancel" : (current == nil ? "Record Shortcut" : "Change Shortcut")) {
                        recording ? stop() : start()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    if let onRemove, current != nil {
                        Button("Remove") { onRemove() }.disabled(recording)
                    }
                    if let onRestoreDefault {
                        Button("Restore Default") { message = onRestoreDefault() }
                            .disabled(recording || current == Shortcut.fallback)
                    }
                }

                Text("Use Control (⌃), Option (⌥) or Command (⌘), optionally with Shift (⇧), together with a letter, number or function key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            Spacer()
        }
        .onDisappear { stop() }
    }

    private func start() {
        message = nil
        recording = true
        model.pauseShortcuts(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53 && flags.isEmpty { // Esc
            stop()
            return
        }
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= Shortcut.controlKey }
        if flags.contains(.option) { modifiers |= Shortcut.optionKey }
        if flags.contains(.command) { modifiers |= Shortcut.cmdKey }
        if flags.contains(.shift) { modifiers |= Shortcut.shiftKey }
        guard let shortcut = Shortcut.make(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers) else {
            message = "That combination can't be used. Include Control, Option or Command, plus a letter, number or function key."
            return
        }
        stop()
        message = onApply(shortcut)
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording {
            recording = false
            model.pauseShortcuts(false)
        }
    }
}

private struct ShortcutListScreen: View {
    @ObservedObject var quickSnippets: QuickSnippetStore
    @ObservedObject var shortcuts: ShortcutManager
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Keyboard Shortcuts", backTitle: Brand.name, onBack: model.pop) {
                CloseButton(model: model)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Quick menu")
                    ListRow(title: "Open the quick menu", subtitle: "Shows all your snippets at the pointer",
                            systemImage: "menubar.arrow.down.rectangle", shortcut: model.shortcut) {
                        model.push(.shortcut)
                    }
                    .padding(.horizontal, 8)

                    SectionTitle("Folders, snippets and Quick Snippets")
                    if shortcuts.bindings.isEmpty {
                        Text("Right-click any folder, subfolder, snippet or Quick Snippet and choose Keyboard Shortcut… to give it its own shortcut.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 18)
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(shortcuts.bindings, id: \.target) { binding in
                                ListRow(title: describeTarget(binding.target, quickSnippets: quickSnippets),
                                        subtitle: kind(binding.target),
                                        systemImage: icon(binding.target),
                                        shortcut: shortcuts.shortcut(for: binding.target)) {
                                    model.push(.itemShortcut(binding.target))
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 6)
            }
            PanelFooter(model: model)
        }
    }

    private func kind(_ target: ShortcutTarget) -> String {
        switch target {
        case .folder: return "Opens the folder"
        case .subfolder: return "Opens the subfolder"
        case .snippet: return "Copies the snippet"
        case .quickSnippet: return "Opens the Quick Snippet"
        }
    }

    private func icon(_ target: ShortcutTarget) -> String {
        switch target {
        case .folder: return "folder.fill"
        case .subfolder: return "folder"
        case .snippet: return "text.alignleft"
        case .quickSnippet: return "note.text"
        }
    }
}

// MARK: - About and Support

private struct AboutScreen: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "About", backTitle: Brand.name, onBack: model.pop) {
                CloseButton(model: model)
            }
            ScrollView {
                VStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                        .padding(.top, 8)
                    VStack(spacing: 4) {
                        Text(Brand.name).font(.system(size: 24, weight: .bold))
                        Text("Version \(Updater.currentVersion)").foregroundColor(.secondary)
                    }
                    Text(Brand.tagline)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Text("\(Brand.name) keeps the replies you write again and again organized in folders, ready to copy with a click or a keyboard shortcut. Your snippets are stored only on this Mac, and \(Brand.name) never reads anything else you copy.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                    VStack(spacing: 8) {
                        Button("Check for Updates…", action: model.checkForUpdates)
                        Button("Release Notes") { NSWorkspace.shared.open(Brand.releasesURL) }
                    }
                    .padding(.top, 4)

                    Divider().padding(.vertical, 4)
                    VStack(spacing: 2) {
                        Text("Made by \(Brand.author)").font(.callout.weight(.medium))
                        Text("© 2026 \(Brand.author)").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            PanelFooter(model: model)
        }
    }
}

private struct SupportScreen: View {
    @ObservedObject var model: PanelModel
    @State private var copiedInfo = false

    private var systemInfo: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(Brand.name) \(Updater.currentVersion) · macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Support", backTitle: Brand.name, onBack: model.pop) {
                CloseButton(model: model)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SupportCard(title: "User Guide",
                                text: "Step-by-step help for installing \(Brand.name), organizing snippets and setting up shortcuts.",
                                buttonTitle: "Open User Guide") { NSWorkspace.shared.open(Brand.guideURL) }
                    SupportCard(title: "Report a Problem",
                                text: "Something not working as expected? Tell us what happened and we'll look into it.",
                                buttonTitle: "Report a Problem") { NSWorkspace.shared.open(Brand.reportProblemURL) }
                    SupportCard(title: "Ask a Question or Suggest a Feature",
                                text: "Questions and ideas are always welcome.",
                                buttonTitle: "Get in Touch") { NSWorkspace.shared.open(Brand.askQuestionURL) }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Include this in your message").font(.callout.weight(.medium))
                        HStack {
                            Text(systemInfo)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            Spacer()
                            Button(copiedInfo ? "Copied" : "Copy") {
                                copyToClipboard(systemInfo)
                                copiedInfo = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copiedInfo = false }
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Common questions").font(.headline)
                        FAQ(question: "The keyboard shortcut doesn't work.",
                            answer: "Another app may be using the same combination. Choose a different one under ••• → Keyboard Shortcuts…")
                        FAQ(question: "Where are my snippets saved?",
                            answer: "On this Mac only. Choose ••• → Show Library in Finder to see the file or back it up.")
                        FAQ(question: "How do I update?",
                            answer: "\(Brand.name) checks automatically. When an update is available, click Update at the bottom of this panel.")
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            PanelFooter(model: model)
        }
    }
}

private struct SupportCard: View {
    let title: String
    let text: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.callout.weight(.semibold))
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(buttonTitle, action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }
}

private struct FAQ: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(question).font(.callout.weight(.medium))
            Text(answer)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
