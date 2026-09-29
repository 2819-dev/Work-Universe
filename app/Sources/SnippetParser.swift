import Foundation

// Reads snippets.txt. Uses only Foundation so it can be tested on its own.
//
// Format:
//   # Category
//   ## Subcategory            (optional)
//   ### Snippet title
//   The text that gets copied. As many lines as you like.
//
// Before the first "# Category" line, anything is treated as notes, except
// an optional line like "Shortcut: control+option+s".

struct Snippet {
    let title: String
    let text: String
}

struct Subcategory {
    let title: String
    var snippets: [Snippet] = []
}

struct Category {
    let title: String
    var subcategories: [Subcategory] = []
    var snippets: [Snippet] = []
}

struct ParseResult {
    var categories: [Category] = []
    var problems: [String] = []
    var shortcut: String?

    var snippetCount: Int {
        categories.reduce(0) { total, category in
            total + category.snippets.count
                + category.subcategories.reduce(0) { $0 + $1.snippets.count }
        }
    }
}

enum SnippetParser {
    static func parse(_ content: String) -> ParseResult {
        var result = ParseResult()
        let text = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var pendingTitle: String?
        var pendingLines: [String] = []
        var pendingPlace: (category: Int, subcategory: Int?)?
        var currentSubcategory: Int?

        func finishSnippet() {
            defer { pendingTitle = nil; pendingLines = []; pendingPlace = nil }
            guard let title = pendingTitle, let place = pendingPlace else { return }
            let body = trimBlankLines(pendingLines).joined(separator: "\n")
            if body.isEmpty {
                result.problems.append("“\(title)” has no text, so it was left out.")
                return
            }
            let snippet = Snippet(title: title, text: body)
            if let sub = place.subcategory {
                result.categories[place.category].subcategories[sub].snippets.append(snippet)
            } else {
                result.categories[place.category].snippets.append(snippet)
            }
        }

        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let lineNumber = index + 1
            guard let heading = headingParts(line), heading.level <= 3 else {
                if pendingTitle != nil {
                    pendingLines.append(line)
                } else if result.categories.isEmpty, result.shortcut == nil,
                          let setting = shortcutSetting(line) {
                    result.shortcut = setting
                }
                continue
            }

            finishSnippet()
            switch heading.level {
            case 1:
                result.categories.append(Category(title: heading.title))
                currentSubcategory = nil
            case 2:
                if result.categories.isEmpty {
                    result.problems.append("Line \(lineNumber): subcategory “\(heading.title)” needs a # Category above it.")
                } else {
                    result.categories[result.categories.count - 1].subcategories.append(Subcategory(title: heading.title))
                    currentSubcategory = result.categories[result.categories.count - 1].subcategories.count - 1
                }
            default:
                if result.categories.isEmpty {
                    result.problems.append("Line \(lineNumber): snippet “\(heading.title)” needs a # Category above it.")
                } else {
                    pendingTitle = heading.title
                    pendingPlace = (result.categories.count - 1, currentSubcategory)
                }
            }
        }
        finishSnippet()
        return result
    }

    static func headingParts(_ line: String) -> (level: Int, title: String)? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard !hashes.isEmpty else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard let first = rest.first, first == " " || first == "\t" else { return nil }
        let title = rest.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }
        return (hashes.count, title)
    }

    static func shortcutSetting(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix("shortcut:") else { return nil }
        return String(trimmed.dropFirst("shortcut:".count)).trimmingCharacters(in: .whitespaces)
    }

    static func trimBlankLines(_ lines: [String]) -> [String] {
        let isBlank = { (line: String) in line.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let first = lines.firstIndex(where: { !isBlank($0) }),
              let last = lines.lastIndex(where: { !isBlank($0) }) else { return [] }
        return Array(lines[first...last])
    }
}

// A keyboard shortcut written like "control+option+s".
struct Shortcut: Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let display: String

    static let fallback = Shortcut.parse("control+option+s")!

    // Carbon modifier flags (from HIToolbox/Events.h).
    private static let cmdKey: UInt32 = 256
    private static let shiftKey: UInt32 = 512
    private static let optionKey: UInt32 = 2048
    private static let controlKey: UInt32 = 4096

    // Key codes for a US-layout keyboard.
    private static let keyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50, "space": 49,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    ]

    static func parse(_ text: String) -> Shortcut? {
        let parts = text.lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, let keyName = parts.last, let keyCode = keyCodes[keyName] else { return nil }

        var modifiers: UInt32 = 0
        for part in parts.dropLast() {
            switch part {
            case "control", "ctrl", "⌃": modifiers |= controlKey
            case "option", "opt", "alt", "⌥": modifiers |= optionKey
            case "command", "cmd", "⌘": modifiers |= cmdKey
            case "shift", "⇧": modifiers |= shiftKey
            default: return nil
            }
        }
        // Shift alone would steal ordinary capital letters.
        guard modifiers & (controlKey | optionKey | cmdKey) != 0 else { return nil }

        var display = ""
        if modifiers & controlKey != 0 { display += "⌃" }
        if modifiers & optionKey != 0 { display += "⌥" }
        if modifiers & shiftKey != 0 { display += "⇧" }
        if modifiers & cmdKey != 0 { display += "⌘" }
        display += keyName.uppercased()
        return Shortcut(keyCode: keyCode, carbonModifiers: modifiers, display: display)
    }
}
