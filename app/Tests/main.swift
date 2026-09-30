import Foundation

// Checks for the snippet library reader and writer. Run by build.sh.
var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL (line \(line)): \(message)") }
}

// The sample libraries that earlier versions came with.
let sample10 = SnippetParser.parse(try! String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8))
let starter = SnippetParser.parse(try! String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8))
check(sample10.snippetCount == 10, "1.0 sample count: \(sample10.snippetCount)")
check(starter.problems.isEmpty, "sample has problems: \(starter.problems)")
check(starter.categories.map(\.title) == ["Welcome", "Rule Reminders", "Moderation Actions", "Support"],
      "categories: \(starter.categories.map(\.title))")
check(starter.categories[1].subcategories.map(\.title) == ["Spam & Self-Promotion", "Civility", "Off-Topic"],
      "subcategories")
check(starter.preamble.first == "Snippet Menu library", "preamble kept")
let warning = starter.categories[2].snippets[0]
check(warning.title == "Formal warning", "title")
check(warning.text.hasPrefix("Hello,\n\nThis is a formal warning") && warning.text.hasSuffix("The Moderation Team"),
      "multi-line text kept, blank lines trimmed: \(warning.text)")

// Removing the samples empties an untouched sample library...
check(SampleCleanup.removeSamples([sample10, starter], from: starter.categories).isEmpty, "1.1 samples removed")
check(SampleCleanup.removeSamples([sample10, starter], from: sample10.categories).isEmpty, "1.0 samples removed")
// ...but keeps anything the user added or changed.
var customized = starter.categories
customized[0].snippets[0].text = "Welcome to our server! Changed by me."
customized[1].subcategories[1].snippets.append(Snippet(title: "My own", text: "Mine"))
customized.append(Category(title: "My Category"))
let kept = SampleCleanup.removeSamples([sample10, starter], from: customized)
check(kept.map(\.title) == ["Welcome", "Rule Reminders", "My Category"], "kept categories: \(kept.map(\.title))")
check(kept[0].snippets.map(\.title) == ["Welcome new member"], "kept edited snippet")
check(kept[1].subcategories.map(\.title) == ["Civility"] && kept[1].subcategories[0].snippets.map(\.title) == ["My own"],
      "kept added snippet only")

// Versions
check(AppVersion.isNewer("1.2.0", than: "1.1.0"), "1.2.0 > 1.1.0")
check(AppVersion.isNewer("v1.10.0", than: "1.9.3"), "1.10 > 1.9.3")
check(!AppVersion.isNewer("1.1.0", than: "1.1.0"), "same version")
check(!AppVersion.isNewer("1.0.9", than: "1.1"), "older")

// Saving and reading back gives the same library.
let saved = SnippetWriter.serialize(preamble: starter.preamble, categories: starter.categories)
let reread = SnippetParser.parse(saved)
func shape(_ categories: [Category]) -> String {
    categories.map { c in
        c.title + "{" + c.snippets.map { $0.title + "=" + $0.text }.joined(separator: ";")
            + "|" + c.subcategories.map { s in s.title + "[" + s.snippets.map { $0.title + "=" + $0.text }.joined(separator: ";") + "]" }.joined(separator: ",") + "}"
    }.joined(separator: "\n")
}
check(shape(reread.categories) == shape(starter.categories), "round trip")
check(reread.preamble == starter.preamble, "preamble round trip: \(reread.preamble) vs \(starter.preamble)")

// Snippet text that looks like a heading survives saving.
var tricky = Category(title: "Discord")
tricky.snippets = [Snippet(title: "Rules post", text: "# Server rules\n## Be kind\n\\n not a newline\n#hashtag")]
tricky.subcategories = [Subcategory(title: "Empty subcategory")]
let trickyBack = SnippetParser.parse(SnippetWriter.serialize(preamble: [], categories: [tricky]))
check(trickyBack.categories.count == 1, "tricky categories: \(trickyBack.categories.count)")
check(trickyBack.categories.first?.snippets.first?.text == tricky.snippets[0].text,
      "tricky text: \(String(describing: trickyBack.categories.first?.snippets.first?.text))")
check(trickyBack.categories.first?.subcategories.map(\.title) == ["Empty subcategory"], "empty subcategory kept")

// Mistakes in a hand-edited file are reported; good snippets still load.
let broken = SnippetParser.parse("### orphan\ntext\n# Cat\n### empty\n\n### ok\r\nhello\r\n#hashtag stays text\r\n")
check(broken.problems.count == 2, "problems: \(broken.problems)")
check(broken.snippetCount == 1, "count: \(broken.snippetCount)")
check(broken.categories[0].snippets[0].text == "hello\n#hashtag stays text", "text: \(broken.categories[0].snippets[0].text)")

// Keyboard shortcuts
check(Shortcut.fallback.display == "⌃⌥S", "default display")
check(Shortcut.parse("Cmd + Shift + M")?.display == "⇧⌘M", "cmd shift m")
check(Shortcut.make(keyCode: 96, carbonModifiers: Shortcut.controlKey)?.display == "⌃F5", "f5")
check(Shortcut.make(keyCode: 49, carbonModifiers: Shortcut.optionKey)?.display == "⌥Space", "space")
check(Shortcut.make(keyCode: 0, carbonModifiers: Shortcut.shiftKey) == nil, "shift alone rejected")
check(Shortcut.make(keyCode: 0, carbonModifiers: 0) == nil, "no modifier rejected")
check(Shortcut.make(keyCode: 999, carbonModifiers: Shortcut.cmdKey) == nil, "unknown key rejected")

if failures > 0 { print("\(failures) check(s) failed"); exit(1) }
print("All library tests passed")
