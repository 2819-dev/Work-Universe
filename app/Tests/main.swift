import Foundation

// Checks for SnippetParser. Run by build.sh before building the app.
var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL (line \(line)): \(message)") }
}

// The example snippets file that ships with the app.
let examplePath = CommandLine.arguments[1]
let example = SnippetParser.parse(try! String(contentsOfFile: examplePath, encoding: .utf8))
check(example.problems.isEmpty, "example has problems: \(example.problems)")
check(example.categories.map(\.title) == ["Welcome", "Rule reminders", "Moderation actions", "Support"],
      "categories: \(example.categories.map(\.title))")
check(example.categories[1].subcategories.map(\.title) == ["Spam & self-promotion", "Civility", "Off-topic"],
      "subcategories")
check(example.shortcut == "control+option+s", "shortcut: \(String(describing: example.shortcut))")
let warning = example.categories[2].snippets[0]
check(warning.title == "Formal warning", "title")
check(warning.text.hasPrefix("Hello,\n\nThis is a formal warning") && warning.text.hasSuffix("The Moderation Team"),
      "multi-line text kept, blank lines trimmed: \(warning.text)")

// Mistakes are reported, good snippets still load, Windows line endings work.
let broken = SnippetParser.parse("### orphan\ntext\n# Cat\n### empty\n\n### ok\r\nhello\r\n#hashtag stays text\r\n")
check(broken.problems.count == 2, "problems: \(broken.problems)")
check(broken.snippetCount == 1, "count: \(broken.snippetCount)")
check(broken.categories[0].snippets[0].text == "hello\n#hashtag stays text", "text: \(broken.categories[0].snippets[0].text)")
check(SnippetParser.parse("just notes").snippetCount == 0, "notes only")

// Shortcuts
check(Shortcut.parse("control+option+s")?.display == "⌃⌥S", "default display")
check(Shortcut.parse("Cmd + Shift + M")?.display == "⇧⌘M", "cmd shift m")
check(Shortcut.parse("control+option+f5")?.keyCode == 96, "f5")
check(Shortcut.parse("shift+a") == nil, "shift alone rejected")
check(Shortcut.parse("s") == nil, "no modifier rejected")
check(Shortcut.parse("control+banana") == nil, "unknown key rejected")

if failures > 0 { print("\(failures) test(s) failed"); exit(1) }
print("All parser tests passed")
