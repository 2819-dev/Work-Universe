import AppKit

// Holds the snippet library and saves every change to snippets.txt.
final class SnippetStore: ObservableObject {
    static let folderURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Snippet Menu", isDirectory: true)
    static let fileURL = folderURL.appendingPathComponent("snippets.txt")

    static let defaultPreamble = [
        "Snippet Menu library",
        "",
        "This file is managed by Snippet Menu. You can also edit it in any text editor:",
        "a line starting with \"# \" is a category, \"## \" is a subcategory, \"### \" is a snippet title,",
        "and the lines under a snippet title are the text that gets copied.",
    ]

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
            loadError = "Your snippet library couldn't be found. It may have been moved or deleted."
            return
        }
        guard let data = try? Data(contentsOf: Self.fileURL),
              let content = String(data: data, encoding: .utf8) else {
            categories = []
            problems = []
            loadError = "Your snippet library couldn't be opened because it isn't saved as plain text."
            return
        }
        let result = SnippetParser.parse(content)
        preamble = result.preamble.isEmpty ? Self.defaultPreamble : result.preamble
        categories = result.categories
        problems = result.problems
        loadError = nil
    }

    @discardableResult
    func createStarterLibrary() -> Bool {
        guard !fileExists else { return true }
        do {
            guard let starter = Bundle.main.url(forResource: "starter-snippets", withExtension: "txt") else {
                throw CocoaError(.fileNoSuchFile)
            }
            try FileManager.default.createDirectory(at: Self.folderURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: starter, to: Self.fileURL)
            reload()
            return true
        } catch {
            showError("Your snippet library couldn't be created.", error)
            return false
        }
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
        commit { categories in
            guard let c = categories.firstIndex(where: { $0.id == id }) else { return }
            categories[c].title = SnippetWriter.cleanTitle(title)
        }
    }

    func deleteCategory(_ id: UUID) {
        commit { $0.removeAll { $0.id == id } }
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
        editSubcategory(categoryID, subcategoryID) { $0.title = SnippetWriter.cleanTitle(title) }
    }

    func deleteSubcategory(_ categoryID: UUID, _ subcategoryID: UUID) {
        commit { categories in
            guard let c = categories.firstIndex(where: { $0.id == categoryID }) else { return }
            categories[c].subcategories.removeAll { $0.id == subcategoryID }
        }
    }

    func saveSnippet(id: UUID?, title: String, text: String, in categoryID: UUID, _ subcategoryID: UUID?) {
        let cleanTitle = SnippetWriter.cleanTitle(title)
        let cleanText = SnippetWriter.cleanText(text)
        editSnippets(categoryID, subcategoryID) { snippets in
            if let id, let s = snippets.firstIndex(where: { $0.id == id }) {
                snippets[s].title = cleanTitle
                snippets[s].text = cleanText
            } else {
                snippets.append(Snippet(title: cleanTitle, text: cleanText))
            }
        }
    }

    func deleteSnippet(_ id: UUID, in categoryID: UUID, _ subcategoryID: UUID?) {
        editSnippets(categoryID, subcategoryID) { $0.removeAll { $0.id == id } }
    }

    private func editSubcategory(_ categoryID: UUID, _ subcategoryID: UUID, _ change: @escaping (inout Subcategory) -> Void) {
        commit { categories in
            guard let c = categories.firstIndex(where: { $0.id == categoryID }),
                  let s = categories[c].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }
            change(&categories[c].subcategories[s])
        }
    }

    private func editSnippets(_ categoryID: UUID, _ subcategoryID: UUID?, _ change: @escaping (inout [Snippet]) -> Void) {
        if let subcategoryID {
            editSubcategory(categoryID, subcategoryID) { change(&$0.snippets) }
        } else {
            commit { categories in
                guard let c = categories.firstIndex(where: { $0.id == categoryID }) else { return }
                change(&categories[c].snippets)
            }
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
