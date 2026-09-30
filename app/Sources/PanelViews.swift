import AppKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var model: PanelModel

    var body: some View {
        screen
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: store.generation) { _ in model.reset() }
    }

    @ViewBuilder private var screen: some View {
        switch model.current {
        case .categories:
            CategoriesScreen(store: store, model: model)

        case .category(let id):
            CategoryScreen(store: store, model: model, categoryID: id)

        case .subcategory(let categoryID, let subcategoryID):
            SubcategoryScreen(store: store, model: model, categoryID: categoryID, subcategoryID: subcategoryID)

        case .newCategory:
            NameEditorScreen(heading: "New Category", label: "Category name", initial: "", saveTitle: "Create",
                             onSave: { name in
                                 if let id = store.addCategory(name) { model.replaceTop(.category(id)) }
                             }, onCancel: model.pop)

        case .renameCategory(let id):
            NameEditorScreen(heading: "Rename Category", label: "Category name",
                             initial: store.category(id)?.title ?? "", saveTitle: "Save",
                             onSave: { name in store.renameCategory(id, to: name); model.pop() },
                             onCancel: model.pop)

        case .newSubcategory(let categoryID):
            NameEditorScreen(heading: "New Subcategory", label: "Subcategory name", initial: "", saveTitle: "Create",
                             onSave: { name in
                                 if let id = store.addSubcategory(name, to: categoryID) {
                                     model.replaceTop(.subcategory(categoryID, id))
                                 }
                             }, onCancel: model.pop)

        case .renameSubcategory(let categoryID, let subcategoryID):
            NameEditorScreen(heading: "Rename Subcategory", label: "Subcategory name",
                             initial: store.subcategory(categoryID, subcategoryID)?.title ?? "", saveTitle: "Save",
                             onSave: { name in
                                 store.renameSubcategory(categoryID, subcategoryID, to: name)
                                 model.pop()
                             }, onCancel: model.pop)

        case .snippetEditor(let categoryID, let subcategoryID, let snippetID):
            let existing = snippetID.flatMap { store.snippet($0, in: categoryID, subcategoryID) }
            SnippetEditorScreen(
                heading: existing == nil ? "New Snippet" : "Edit Snippet",
                location: locationText(categoryID, subcategoryID),
                initialTitle: existing?.title ?? "",
                initialText: existing?.text ?? "",
                onSave: { title, text in
                    store.saveSnippet(id: existing?.id, title: title, text: text, in: categoryID, subcategoryID)
                    model.pop()
                },
                onDelete: existing.map { snippet -> () -> Void in
                    return {
                        confirmDelete("Delete “\(snippet.title)”?", detail: "This snippet will be permanently removed.") {
                            store.deleteSnippet(snippet.id, in: categoryID, subcategoryID)
                            model.pop()
                        }
                    }
                },
                onCancel: model.pop)

        case .shortcut:
            ShortcutScreen(model: model)
        }
    }

    private func locationText(_ categoryID: UUID, _ subcategoryID: UUID?) -> String {
        var parts = [store.category(categoryID)?.title ?? ""]
        if let subcategoryID, let sub = store.subcategory(categoryID, subcategoryID) { parts.append(sub.title) }
        return parts.joined(separator: " › ")
    }
}

// MARK: - Screens

private struct CategoriesScreen: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Snippets") {
                IconButton(systemName: "plus", help: "Add Category", prominent: true) { model.push(.newCategory) }
                    .disabled(!store.canEdit)
                MoreMenu(model: model)
                CloseButton(model: model)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    StatusBanners(store: store)
                    if store.categories.isEmpty && store.loadError == nil {
                        EmptyState(systemImage: "square.stack.3d.up",
                                   title: "No categories yet",
                                   message: "Categories keep your snippets organized. Create your first one to get started.",
                                   buttonTitle: "Add Category") { model.push(.newCategory) }
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(store.categories) { category in
                                FolderRow(title: category.title,
                                          subtitle: categorySummary(category),
                                          systemImage: "folder.fill") { model.push(.category(category.id)) }
                                    .contextMenu {
                                        Button("Rename…") { model.push(.renameCategory(category.id)) }
                                        Button("Delete…", role: .destructive) {
                                            confirmDelete("Delete “\(category.title)”?",
                                                          detail: "This category and all of its snippets will be permanently removed.") {
                                                store.deleteCategory(category.id)
                                            }
                                        }
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

    private func categorySummary(_ category: Category) -> String {
        var parts = [countText(category.snippetCount, "snippet")]
        if !category.subcategories.isEmpty { parts.append(countText(category.subcategories.count, "subcategory", "subcategories")) }
        return parts.joined(separator: " · ")
    }
}

private struct CategoryScreen: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var model: PanelModel
    let categoryID: UUID

    var body: some View {
        if let category = store.category(categoryID) {
            VStack(spacing: 0) {
                PanelHeader(title: category.title, backTitle: "Snippets", onBack: model.pop) {
                    AddButton(options: [
                        AddOption(title: "Add Snippet", systemImage: "text.badge.plus") {
                            model.push(.snippetEditor(category: categoryID, subcategory: nil, snippet: nil))
                        },
                        AddOption(title: "Add Subcategory", systemImage: "folder.badge.plus") {
                            model.push(.newSubcategory(categoryID))
                        },
                    ])
                    .disabled(!store.canEdit)
                    CloseButton(model: model)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusBanners(store: store)
                        if category.subcategories.isEmpty && category.snippets.isEmpty {
                            EmptyState(systemImage: "tray",
                                       title: "This category is empty",
                                       message: "Use the + button to add a snippet or a subcategory.",
                                       buttonTitle: nil) {}
                        }
                        if !category.subcategories.isEmpty {
                            SectionTitle("Subcategories")
                            LazyVStack(spacing: 2) {
                                ForEach(category.subcategories) { sub in
                                    FolderRow(title: sub.title,
                                              subtitle: countText(sub.snippets.count, "snippet"),
                                              systemImage: "folder") { model.push(.subcategory(categoryID, sub.id)) }
                                        .contextMenu {
                                            Button("Rename…") { model.push(.renameSubcategory(categoryID, sub.id)) }
                                            Button("Delete…", role: .destructive) {
                                                confirmDelete("Delete “\(sub.title)”?",
                                                              detail: "This subcategory and all of its snippets will be permanently removed.") {
                                                    store.deleteSubcategory(categoryID, sub.id)
                                                }
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        if !category.snippets.isEmpty {
                            SectionTitle("Snippets")
                            SnippetList(store: store, model: model, snippets: category.snippets,
                                        categoryID: categoryID, subcategoryID: nil)
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

private struct SubcategoryScreen: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var model: PanelModel
    let categoryID: UUID
    let subcategoryID: UUID

    var body: some View {
        if let category = store.category(categoryID), let sub = store.subcategory(categoryID, subcategoryID) {
            VStack(spacing: 0) {
                PanelHeader(title: sub.title, backTitle: category.title, onBack: model.pop) {
                    AddButton(options: [
                        AddOption(title: "Add Snippet", systemImage: "text.badge.plus") {
                            model.push(.snippetEditor(category: categoryID, subcategory: subcategoryID, snippet: nil))
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
                                       message: "Use the + button to add your first snippet here.",
                                       buttonTitle: nil) {}
                        } else {
                            SnippetList(store: store, model: model, snippets: sub.snippets,
                                        categoryID: categoryID, subcategoryID: subcategoryID)
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
                    TextField("", text: $title, prompt: Text("Shown in the menu"))
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

private struct ShortcutScreen: View {
    @ObservedObject var model: PanelModel
    @State private var recording = false
    @State private var message: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: "Keyboard Shortcut", backTitle: "Snippets", onBack: { stop(); model.pop() }) {
                CloseButton(model: model)
            }
            VStack(alignment: .leading, spacing: 14) {
                Text("Press this shortcut in any app to open your snippets right where your pointer is.")
                    .fixedSize(horizontal: false, vertical: true)

                Text(recording ? "Type your new shortcut" : model.shortcut.display)
                    .font(.system(size: recording ? 15 : 24, weight: .semibold, design: .rounded))
                    .foregroundColor(recording ? .accentColor : .primary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(recording ? Color.accentColor : Color.secondary.opacity(0.25),
                                      lineWidth: recording ? 2 : 1))

                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button(recording ? "Cancel" : "Change Shortcut") { recording ? stop() : start() }
                    Spacer()
                    Button("Restore Default") { apply(Shortcut.fallback) }
                        .disabled(recording || model.shortcut == Shortcut.fallback)
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
        model.pauseShortcut(true)
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
        apply(shortcut)
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording {
            recording = false
            model.pauseShortcut(false)
        }
    }

    private func apply(_ shortcut: Shortcut) {
        message = model.applyShortcut(shortcut) ? nil : "That shortcut is already used by another app. Please choose a different one."
    }
}

// MARK: - Building blocks

private struct PanelHeader<Trailing: View>: View {
    let title: String
    var backTitle: String?
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let onBack {
                Button(action: onBack) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        Text(backTitle ?? "Back").lineLimit(1)
                    }
                    .font(.callout)
                    .foregroundColor(.accentColor)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                trailing
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}

private struct PanelFooter: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "keyboard").foregroundColor(.secondary)
                Text("Press \(model.shortcut.display) in any app for quick access")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

private struct IconButton: View {
    let systemName: String
    let help: String
    var prominent = false
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(prominent ? .white : .primary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(fill))
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }

    private var fill: Color {
        if prominent { return Color.accentColor.opacity(hovering ? 0.85 : 1) }
        return Color.primary.opacity(hovering ? 0.14 : 0.07)
    }
}

private struct CloseButton: View {
    @ObservedObject var model: PanelModel
    var body: some View {
        IconButton(systemName: "xmark", help: "Close") { model.hidePanel() }
    }
}

private struct AddOption: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
}

// The round + button. With several choices, hovering or clicking shows them.
private struct AddButton: View {
    let options: [AddOption]
    @State private var showingChoices = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        IconButton(systemName: "plus", help: options.count == 1 ? options[0].title : "Add", prominent: true) {
            if options.count == 1 { options[0].action() } else { showingChoices.toggle() }
        }
        .onHover { inside in
            if inside && isEnabled && options.count > 1 { showingChoices = true }
        }
        .onAppear {
            // Used to capture a preview image of the choices.
            if ProcessInfo.processInfo.environment["SNIPPETMENU_SHOW_PANEL"] == "add" && options.count > 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showingChoices = true }
            }
        }
        .popover(isPresented: $showingChoices, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(options) { option in
                    ChoiceRow(option: option) {
                        showingChoices = false
                        DispatchQueue.main.async { option.action() }
                    }
                }
            }
            .padding(6)
            .frame(width: 210)
        }
    }
}

private struct ChoiceRow: View {
    let option: AddOption
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: option.systemImage)
                    .frame(width: 18)
                    .foregroundColor(hovering ? .white : .accentColor)
                Text(option.title)
                Spacer()
            }
            .foregroundColor(hovering ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.accentColor : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct MoreMenu: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        Menu {
            Button("Keyboard Shortcut…") { model.push(.shortcut) }
            Toggle("Open at Login", isOn: Binding(get: model.isOpenAtLogin, set: model.setOpenAtLogin))
            Button("Show Library in Finder") {
                if FileManager.default.fileExists(atPath: SnippetStore.fileURL.path) {
                    NSWorkspace.shared.activateFileViewerSelecting([SnippetStore.fileURL])
                } else {
                    NSWorkspace.shared.open(SnippetStore.folderURL)
                }
            }
            Divider()
            Button("Quit Snippet Menu") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26, height: 26)
        .background(Circle().fill(Color.primary.opacity(0.07)))
        .help("More")
    }
}

private struct FolderRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body.weight(.medium)).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct SnippetList: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var model: PanelModel
    let snippets: [Snippet]
    let categoryID: UUID
    let subcategoryID: UUID?

    var body: some View {
        LazyVStack(spacing: 2) {
            ForEach(snippets) { snippet in
                SnippetRow(snippet: snippet,
                           copied: model.copiedSnippetID == snippet.id,
                           onCopy: { model.copy(snippet) },
                           onEdit: edit(snippet))
                    .contextMenu {
                        Button("Copy") { model.copy(snippet) }
                        Button("Edit…", action: edit(snippet))
                        Button("Delete…", role: .destructive) {
                            confirmDelete("Delete “\(snippet.title)”?", detail: "This snippet will be permanently removed.") {
                                store.deleteSnippet(snippet.id, in: categoryID, subcategoryID)
                            }
                        }
                    }
            }
        }
        .padding(.horizontal, 8)
    }

    private func edit(_ snippet: Snippet) -> () -> Void {
        { model.push(.snippetEditor(category: categoryID, subcategory: subcategoryID, snippet: snippet.id)) }
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let copied: Bool
    let onCopy: () -> Void
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "text.alignleft")
                .foregroundColor(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title).font(.body.weight(.medium)).lineLimit(1)
                Text(snippet.text.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            if copied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
            } else if hovering {
                IconButton(systemName: "pencil", help: "Edit Snippet", action: onEdit)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .onHover { hovering = $0 }
        .help("Click to copy")
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 18)
    }
}

private struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let buttonTitle {
                Button(buttonTitle, action: action).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 40)
    }
}

private struct StatusBanners: View {
    @ObservedObject var store: SnippetStore

    var body: some View {
        VStack(spacing: 8) {
            if let error = store.loadError {
                Banner(message: error,
                       buttonTitle: store.fileExists ? "Show in Finder" : "Create New Library") {
                    if store.fileExists {
                        NSWorkspace.shared.activateFileViewerSelecting([SnippetStore.fileURL])
                    } else {
                        store.createStarterLibrary()
                    }
                }
            }
            if !store.problems.isEmpty {
                Banner(message: "Some entries in your library couldn't be read:\n• " + store.problems.joined(separator: "\n• "),
                       buttonTitle: nil) {}
            }
        }
    }
}

private struct Banner: View {
    let message: String
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if let buttonTitle {
                    Button(buttonTitle, action: action)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
        .padding(.horizontal, 12)
    }
}

// MARK: - Helpers

private func countText(_ count: Int, _ singular: String, _ plural: String? = nil) -> String {
    "\(count) \(count == 1 ? singular : (plural ?? singular + "s"))"
}

private func confirmDelete(_ message: String, detail: String, onConfirm: @escaping () -> Void) {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { onConfirm() }
    }
}
