import AppKit
import SwiftUI

// Reusable pieces of the side panel.

struct PanelHeader<Trailing: View>: View {
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
                    .foregroundColor(Brand.accent)
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

struct PanelFooter: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.update {
        case .none:
            HStack(spacing: 6) {
                Image(systemName: "keyboard").foregroundColor(.secondary)
                Text("Press \(model.shortcut.display) in any app for quick access")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .font(.caption)

        case .available(let version):
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Brand.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Update available").font(.callout.weight(.semibold))
                    Text("Version \(version) is ready to install").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button("Update", action: model.startUpdate)
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.accent)
                    .controlSize(.small)
            }

        case .installing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Updating…").font(.callout.weight(.semibold))
                    Text("\(Brand.name) will reopen in a moment").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Try Again", action: model.startUpdate).controlSize(.small)
                    Button("Open Download Page") { NSWorkspace.shared.open(Updater.releasesPage) }
                        .controlSize(.small)
                    Spacer()
                }
            }
        }
    }
}

struct IconButton: View {
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
        if prominent { return Brand.accent.opacity(hovering ? 0.85 : 1) }
        return Color.primary.opacity(hovering ? 0.14 : 0.07)
    }
}

struct CloseButton: View {
    @ObservedObject var model: PanelModel
    var body: some View {
        IconButton(systemName: "xmark", help: "Close") { model.hidePanel() }
    }
}

struct AddOption: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
}

// The round + button. With several choices, hovering or clicking shows them.
struct AddButton: View {
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
            if ProcessInfo.processInfo.environment["QUICKSNIP_PREVIEW"] == "add" && options.count > 1 {
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
            .frame(width: 220)
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
                    .foregroundColor(hovering ? .white : Brand.accent)
                Text(option.title)
                Spacer()
            }
            .foregroundColor(hovering ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Brand.accent : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct MoreMenu: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        Menu {
            Button("Keyboard Shortcuts…") { model.push(.shortcutList) }
            Toggle("Open at Login", isOn: Binding(get: model.isOpenAtLogin, set: model.setOpenAtLogin))
            Button("Show Library in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([SnippetStore.fileURL])
            }
            Divider()
            Button("Check for Updates…", action: model.checkForUpdates)
            Button("About \(Brand.name)") { model.push(.about) }
            Button("Support") { model.push(.support) }
            Divider()
            Button("Quit \(Brand.name)") { NSApp.terminate(nil) }
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

struct ShortcutBadge: View {
    let shortcut: Shortcut

    var body: some View {
        Text(shortcut.display)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.12)))
            .help("Keyboard shortcut")
    }
}

struct ListRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var iconColor: Color = Brand.accent
    var shortcut: Shortcut?
    var showsChevron = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(iconColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body.weight(.medium)).lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if let shortcut { ShortcutBadge(shortcut: shortcut) }
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
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

struct SnippetRow: View {
    let snippet: Snippet
    let copied: Bool
    let shortcut: Shortcut?
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
            } else if let shortcut {
                ShortcutBadge(shortcut: shortcut)
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

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 18)
    }
}

struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actions: [AddOption] = []

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
            if !actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(actions) { option in
                        Button(action: option.action) {
                            Label(option.title, systemImage: option.systemImage)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
    }
}

struct StatusBanners: View {
    @ObservedObject var store: SnippetStore

    var body: some View {
        VStack(spacing: 8) {
            if let error = store.loadError {
                Banner(message: error,
                       buttonTitle: store.fileExists ? "Show in Finder" : "Create New Library") {
                    if store.fileExists {
                        NSWorkspace.shared.activateFileViewerSelecting([SnippetStore.fileURL])
                    } else {
                        store.createEmptyLibrary()
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

func countText(_ count: Int, _ singular: String, _ plural: String? = nil) -> String {
    "\(count) \(count == 1 ? singular : (plural ?? singular + "s"))"
}

func confirmDelete(_ message: String, detail: String, onConfirm: @escaping () -> Void) {
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

func describeTarget(_ target: ShortcutTarget, quickSnippets: QuickSnippetStore) -> String {
    switch target {
    case .folder(let folder): return folder
    case .subfolder(let folder, let sub): return "\(folder) › \(sub)"
    case .snippet(let folder, let sub, let title): return [folder, sub, title].compactMap { $0 }.joined(separator: " › ")
    case .quickSnippet(let id): return quickSnippets.note(id)?.displayTitle ?? "Quick Snippet"
    }
}

func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}
