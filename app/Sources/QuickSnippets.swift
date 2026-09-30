import AppKit
import Combine
import SwiftUI

// A Quick Snippet is a small notepad for text you need right now.
struct QuickSnippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var text = ""
    var modified = Date()

    /// The first line of the note, like Apple Notes.
    var displayTitle: String {
        let firstLine = text.split(separator: "\n", omittingEmptySubsequences: true)
            .first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        if firstLine.isEmpty { return "Untitled" }
        return firstLine.count > 60 ? String(firstLine.prefix(60)) + "…" : firstLine
    }

    var preview: String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).dropFirst()
        return lines.joined(separator: " ")
    }
}

final class QuickSnippetStore: ObservableObject {
    static var fileURL: URL { SnippetStore.folderURL.appendingPathComponent("quick-snippets.json") }

    @Published private(set) var notes: [QuickSnippet] = []
    private var pendingSave: DispatchWorkItem?

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? decoder.decode([QuickSnippet].self, from: data) {
            notes = saved
        }
    }

    func note(_ id: UUID) -> QuickSnippet? { notes.first { $0.id == id } }

    func add() -> UUID {
        let note = QuickSnippet()
        notes.insert(note, at: 0)
        saveNow()
        return note.id
    }

    func update(_ id: UUID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].text != text else { return }
        notes[index].text = text
        notes[index].modified = Date()
        scheduleSave()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        saveNow()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try FileManager.default.createDirectory(at: SnippetStore.folderURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(notes).write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("QuickSnip couldn't save Quick Snippets: \(error)")
        }
    }
}

// Opens each Quick Snippet in its own small floating notepad window.
final class NotepadWindows: NSObject, NSWindowDelegate {
    private let store: QuickSnippetStore
    private var windows: [UUID: NSWindow] = [:]
    private var titleUpdates: AnyCancellable?

    init(store: QuickSnippetStore) {
        self.store = store
        super.init()
        titleUpdates = store.$notes.sink { [weak self] notes in
            guard let self else { return }
            for note in notes { self.windows[note.id]?.title = note.displayTitle }
            for id in self.windows.keys where !notes.contains(where: { $0.id == id }) {
                self.windows[id]?.close()
            }
        }
    }

    func open(_ id: UUID) {
        guard let note = store.note(id) else {
            HUD.show("That Quick Snippet no longer exists")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = note.displayTitle
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 260, height: 200)
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: NotepadView(store: store, id: id))
        window.delegate = self
        position(window)
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
    }

    private func position(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { window.center(); return }
        let offset = CGFloat(windows.count % 6) * 26
        let origin = NSPoint(x: area.midX - window.frame.width / 2 - 120 + offset,
                             y: area.midY - window.frame.height / 2 - offset)
        window.setFrameOrigin(origin)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = windows.first(where: { $0.value === window })?.key else { return }
        windows[id] = nil
        store.saveNow()
    }
}

private struct NotepadView: View {
    @ObservedObject var store: QuickSnippetStore
    let id: UUID
    @State private var text = ""
    @State private var copied = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .focused($focused)
            Divider()
            HStack {
                Text(countText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.accent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Copy all text (⌘Return)")
            }
            .padding(10)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            text = store.note(id)?.text ?? ""
            DispatchQueue.main.async { focused = true }
        }
        .onChange(of: text) { store.update(id, text: $0) }
    }

    private var countText: String {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        return "\(words) \(words == 1 ? "word" : "words") · \(text.count) \(text.count == 1 ? "character" : "characters")"
    }
}
