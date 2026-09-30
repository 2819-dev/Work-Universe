import AppKit

// Keyboard shortcuts for individual folders, subfolders, snippets and
// Quick Snippets, saved in shortcuts.json next to the library.
final class ShortcutManager: ObservableObject {
    static var fileURL: URL { SnippetStore.folderURL.appendingPathComponent("shortcuts.json") }
    private static let firstHotKeyID: UInt32 = 100

    @Published private(set) var bindings: [ShortcutBinding] = []

    /// Runs when one of these shortcuts is pressed.
    var perform: (ShortcutTarget) -> Void = { _ in }
    /// The main shortcut, which item shortcuts may not reuse.
    var mainShortcut: () -> Shortcut = { Shortcut.fallback }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([ShortcutBinding].self, from: data) {
            bindings = saved
        }
    }

    func shortcut(for target: ShortcutTarget) -> Shortcut? {
        bindings.first { $0.target == target }.flatMap(Self.shortcut)
    }

    /// Returns a message explaining the problem, or nil when it worked.
    func assign(_ shortcut: Shortcut, to target: ShortcutTarget, describe: (ShortcutTarget) -> String) -> String? {
        if shortcut == mainShortcut() {
            return "\(shortcut.display) already opens the \(Brand.name) quick menu. Please choose a different shortcut."
        }
        if let other = bindings.first(where: { $0.target != target && Self.shortcut($0) == shortcut }) {
            return "\(shortcut.display) is already used for “\(describe(other.target))”. Please choose a different shortcut."
        }
        let previous = bindings
        bindings.removeAll { $0.target == target }
        bindings.append(ShortcutBinding(target: target, keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers))
        if registerAll().contains(target) {
            bindings = previous
            registerAll()
            return "\(shortcut.display) is already used by another app. Please choose a different shortcut."
        }
        save()
        return nil
    }

    func remove(_ target: ShortcutTarget) {
        bindings.removeAll { $0.target == target }
        save()
        registerAll()
    }

    /// Updates or removes shortcuts after something is renamed or deleted.
    func remap(_ transform: (ShortcutTarget) -> ShortcutTarget?) {
        let updated = bindings.compactMap { binding -> ShortcutBinding? in
            guard let target = transform(binding.target) else { return nil }
            var changed = binding
            changed.target = target
            return changed
        }
        guard updated != bindings else { return }
        bindings = updated
        save()
        registerAll()
    }

    /// Registers every shortcut; returns the ones that couldn't be turned on.
    @discardableResult
    func registerAll() -> Set<ShortcutTarget> {
        HotKey.unregister { $0 >= Self.firstHotKeyID }
        var failed = Set<ShortcutTarget>()
        for (index, binding) in bindings.enumerated() {
            guard let shortcut = Self.shortcut(binding) else { continue }
            let target = binding.target
            let ok = HotKey.register(id: Self.firstHotKeyID + UInt32(index), shortcut) { [weak self] in
                self?.perform(target)
            }
            if !ok { failed.insert(target) }
        }
        return failed
    }

    func unregisterAll() {
        HotKey.unregister { $0 >= Self.firstHotKeyID }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: SnippetStore.folderURL, withIntermediateDirectories: true)
            try JSONEncoder().encode(bindings).write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("QuickSnip couldn't save shortcuts: \(error)")
        }
    }

    private static func shortcut(_ binding: ShortcutBinding) -> Shortcut? {
        Shortcut.make(keyCode: binding.keyCode, carbonModifiers: binding.modifiers)
    }
}
