import AppKit

// Holds the snippet library and saves every change to snippets.txt.
final class SnippetStore: ObservableObject {
    static let folderURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/QuickSnip", isDirectory: true)
    static let legacyFolderURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Snippet Menu", isDirectory: true)
    static let fileURL = folderURL.appendingPathComponent("snippets.txt")

    static let defaultPreamble = [
        "QuickSnip library",
        "",
        "This file is managed by QuickSnip. You can also edit it in any text editor:",
        "a line starting with \"# \" is a folder, \"## \" is a subfolder, \"### \" is a snippet title,",
        "and the lines under a snippet title are the text that gets copied.",
    ]

    /// Moves the library from its location before the app was renamed.
    static func moveLegacyLibrary() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: folderURL.path), fm.fileExists(atPath: legacyFolderURL.path) else { return }
        try? fm.moveItem(at: legacyFolderURL, to: folderURL)
    }

    /// Called after renames and deletions so keyboard shortcuts follow along.
    var remapShortcuts: ((ShortcutTarget) -> ShortcutTarget?) -> Void = { _ in }

    @Published private(set) var categories: [Category] = []
    @Published private(set) var loadError: String?
    @Published private(set) var problems: [String] = []
    /// Changes whenever the library is re-read from disk.
    @Published private(set) var generation = 0

    private var preamble = SnippetStore.defaultPreamble
    private var loadedModificationDate: Date?
    private var hasLoaded = false

    var fileExists: Bool { FileManager.default.fileExists(atPath: Self.fileURL.path) }

    /// Editing is blocked only when a library exists but can't be read,
    /// so it's never overwritten by accident.
    var canEdit: Bool { loadError == nil || !fileExists }

    // MARK: Reading

    func reloadIfChanged() {
        if !hasLoaded || loadError != nil || modificationDate() != loadedModificationDate {
            reload()
        }
    }

    func reload() {
        hasLoaded = true
        loadedModificationDate = modificationDate()
        generation += 1

        guard fileExists else {
            categories = []
            problems = []
            preamble = Self.defaultPreamble
            loadError = "Your library couldn't be found. It may have been moved or deleted."
            return
        }
        guard let data = try? Data(contentsOf: Self.fileURL),
              let content = String(data: data, encoding: .utf8) else {
            categories = []
            problems = []
            loadError = "Your library couldn't be opened because it isn't saved as plain text."
            return
        }
        let result = SnippetParser.parse(content)
        preamble = result.preamble.isEmpty ? Self.defaultPreamble : result.preamble
        categories = result.categories
        problems = result.problems
        loadError = nil
    }

    /// Starts a new, empty library.
    func createEmptyLibrary() {
        guard !fileExists else { return }
        preamble = Self.defaultPreamble
        categories = []
        problems = []
        loadError = nil
        commit { $0 = [] }
    }

    /// Removes the sample snippets that earlier versions came with. Snippets
    /// the user added or changed are kept.
    func removeSampleSnippets() {
        guard loadError == nil, fileExists else { return }
        let samples = ["sample-1.0", "sample-1.1"]
            .compactMap { Bundle.main.url(forResource: $0, withExtension: "txt") }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .map(SnippetParser.parse)
        guard !samples.isEmpty else { return }
        let cleaned = SampleCleanup.removeSamples(samples, from: categories)
        guard cleaned != categories else { return }
        commit { $0 = cleaned }
    }

    /// Replaces the note at the top of the file written by earlier versions.
    func updateLibraryNotes() {
        guard loadError == nil, fileExists, preamble != Self.defaultPreamble else { return }
        let outdated = preamble.contains {
            $0.contains("HOW THIS FILE WORKS") || $0.contains("Replace the examples") || $0.contains("Snippet Menu")
        }
        guard outdated else { return }
        preamble = Self.defaultPreamble
        commit { _ in }
    }

    // MARK: Looking things up

    func category(_ id: UUID) -> Category? {
        categories.first { $0.id == id }
    }

    func subcategory(_ categoryID: UUID, _ subcategoryID: UUID) -> Subcategory? {
        category(categoryID)?.subcategories.first { $0.id == subcategoryID }
    }

    func snippet(_ id: UUID, in categoryID: UUID, _ subcategoryID: UUID?) -> Snippet? {
        if let subcategoryID {
            return subcategory(categoryID, subcategoryID)?.snippets.first { $0.id == id }
        }
        return category(categoryID)?.snippets.first { $0.id == id }
    }

    // MARK: Changing things

    func addCategory(_ title: String) -> UUID? {
        let category = Category(title: SnippetWriter.cleanTitle(title))
        return commit { $0.append(category) } ? category.id : nil
    }

    func renameCategory(_ id: UUID, to title: String) {
        guard let old = category(id)?.title else { return }
        let new = SnippetWriter.cleanTitle(title)
        let saved = commit { categories in
            guard let c = categories.firstIndex(where: { $0.id == id }) else { return }
            categories[c].title = new
        }
        if saved { remapShortcuts { $0.renamingFolder(old, to: new) } }
    }

    func deleteCategory(_ id: UUID) {
        guard let title = category(id)?.title else { return }
        if commit({ $0.removeAll { $0.id == id } }) {
            remapShortcuts { $0.isInside(folder: title) ? nil : $0 }
        }
    }

    func addSubcategory(_ title: String, to categoryID: UUID) -> UUID? {
        let subcategory = Subcategory(title: SnippetWriter.cleanTitle(title))
        let saved = commit { categories in
            guard let c = categories.firstIndex(where: { $0.id == categoryID }) else { return }
            categories[c].subcategories.append(subcategory)
        }
        return saved ? subcategory.id : nil
    }

    func renameSubcategory(_ categoryID: UUID, _ subcategoryID: UUID, to title: String) {
        guard let folder = category(categoryID)?.title,
              let old = subcategory(categoryID, subcategoryID)?.title else { return }
        let new = SnippetWriter.cleanTitle(title)
        if editSubcategory(categoryID, subcategoryID, { $0.title = new }) {
            remapShortcuts { $0.renamingSubfolder(in: folder, old, to: new) }
        }
    }

    func deleteSubcategory(_ categoryID: UUID, _ subcategoryID: UUID) {
        guard let folder = category(categoryID)?.title,
              let sub = subcategory(categoryID, subcategoryID)?.title else { return }
        let saved = commit { categories in
            guard let c = categories.firstIndex(where: { $0.id == categoryID }) else { return }
            categories[c].subcategories.removeAll { $0.id == subcategoryID }
        }
        if saved { remapShortcuts { $0.isInside(folder: folder, subfolder: sub) ? nil : $0 } }
    }

    func saveSnippet(id: UUID?, title: String, text: String, in categoryID: UUID, _ subcategoryID: UUID?) {
        let cleanTitle = SnippetWriter.cleanTitle(title)
        let cleanText = SnippetWriter.cleanText(text)
        let oldTitle = id.flatMap { snippet($0, in: categoryID, subcategoryID)?.title }
        let saved = editSnippets(categoryID, subcategoryID) { snippets in
            if let id, let s = snippets.firstIndex(where: { $0.id == id }) {
                snippets[s].title = cleanTitle
                snippets[s].text = cleanText
            } else {
                snippets.append(Snippet(title: cleanTitle, text: cleanText))
            }
        }
        if saved, let oldTitle, oldTitle != cleanTitle, let place = names(categoryID, subcategoryID) {
            remapShortcuts { $0.renamingSnippet(in: place.0, place.1, oldTitle, to: cleanTitle) }
        }
    }

    func deleteSnippet(_ id: UUID, in categoryID: UUID, _ subcategoryID: UUID?) {
        guard let title = snippet(id, in: categoryID, subcategoryID)?.title,
              let place = names(categoryID, subcategoryID) else { return }
        let removed = ShortcutTarget.snippet(place.0, place.1, title)
        if editSnippets(categoryID, subcategoryID, { $0.removeAll { $0.id == id } }) {
            remapShortcuts { $0 == removed ? nil : $0 }
        }
    }

    /// The shortcut target for a folder, subfolder or snippet.
    func target(_ categoryID: UUID, _ subcategoryID: UUID? = nil, snippet snippetID: UUID? = nil) -> ShortcutTarget? {
        guard let place = names(categoryID, subcategoryID) else { return nil }
        let (folder, sub) = place
        if let snippetID {
            guard let title = snippet(snippetID, in: categoryID, subcategoryID)?.title else { return nil }
            return .snippet(folder, sub, title)
        }
        if let sub { return .subfolder(folder, sub) }
        return .folder(folder)
    }

    private func names(_ categoryID: UUID, _ subcategoryID: UUID?) -> (String, String?)? {
        guard let folder = category(categoryID)?.title else { return nil }
        if let subcategoryID {
            guard let sub = subcategory(categoryID, subcategoryID)?.title else { return nil }
            return (folder, sub)
        }
        return (folder, nil)
    }

    @discardableResult
    private func editSubcategory(_ categoryID: UUID, _ subcategoryID: UUID, _ change: (inout Subcategory) -> Void) -> Bool {
        commit { categories in
            guard let c = categories.firstIndex(where: { $0.id == categoryID }),
                  let s = categories[c].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }
            change(&categories[c].subcategories[s])
        }
    }

    @discardableResult
    private func editSnippets(_ categoryID: UUID, _ subcategoryID: UUID?, _ change: (inout [Snippet]) -> Void) -> Bool {
        if let subcategoryID {
            return editSubcategory(categoryID, subcategoryID) { change(&$0.snippets) }
        }
        return commit { categories in
            guard let c = categories.firstIndex(where: { $0.id == categoryID }) else { return }
            change(&categories[c].snippets)
        }
    }

    @discardableResult
    private func commit(_ change: (inout [Category]) -> Void) -> Bool {
        guard canEdit else { return false }
        var updated = categories
        change(&updated)
        let text = SnippetWriter.serialize(preamble: preamble, categories: updated)
        do {
            try FileManager.default.createDirectory(at: Self.folderURL, withIntermediateDirectories: true)
            try text.write(to: Self.fileURL, atomically: true, encoding: .utf8)
        } catch {
            showError("Your change couldn't be saved.", error)
            return false
        }
        categories = updated
        loadError = nil
        hasLoaded = true
        loadedModificationDate = modificationDate()
        return true
    }

    // MARK: Helpers

    private func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: Self.fileURL.path))?[.modificationDate] as? Date
    }

    private func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
