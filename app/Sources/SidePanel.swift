import AppKit
import SwiftUI

// Which screen the side panel is showing.
enum PanelScreen: Equatable {
    case categories
    case category(UUID)
    case subcategory(UUID, UUID)
    case newCategory
    case renameCategory(UUID)
    case newSubcategory(UUID)
    case renameSubcategory(UUID, UUID)
    case snippetEditor(category: UUID, subcategory: UUID?, snippet: UUID?)
    case shortcut
}

enum UpdateState: Equatable {
    case none
    case available(version: String)
    case installing
    case failed(String)
}

final class PanelModel: ObservableObject {
    @Published var stack: [PanelScreen] = [.categories]
    @Published var shortcut: Shortcut
    @Published var copiedSnippetID: UUID?
    @Published var update: UpdateState = .none

    // Supplied by the app delegate.
    var hidePanel: () -> Void = {}
    var applyShortcut: (Shortcut) -> Bool = { _ in false }
    var pauseShortcut: (Bool) -> Void = { _ in }
    var isOpenAtLogin: () -> Bool = { false }
    var setOpenAtLogin: (Bool) -> Void = { _ in }
    var startUpdate: () -> Void = {}
    var checkForUpdates: () -> Void = {}

    init(shortcut: Shortcut) {
        self.shortcut = shortcut
    }

    var current: PanelScreen { stack.last ?? .categories }

    func push(_ screen: PanelScreen) { stack.append(screen) }
    func pop() { if stack.count > 1 { stack.removeLast() } }
    func replaceTop(_ screen: PanelScreen) { stack[stack.count - 1] = screen }
    func reset() { stack = [.categories] }

    func escape() {
        if stack.count > 1 { pop() } else { hidePanel() }
    }

    func copy(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
        HUD.show("Copied: \(snippet.title)")
        copiedSnippetID = snippet.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            if self?.copiedSnippetID == snippet.id { self?.copiedSnippetID = nil }
        }
    }
}

private final class SidePanelWindow: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

// The panel that slides in from the right edge of the screen.
final class SidePanelController {
    private let panel: SidePanelWindow
    private let store: SnippetStore
    private var wantsVisible = false
    static let width: CGFloat = 360

    var isVisible: Bool { wantsVisible }

    init(store: SnippetStore, model: PanelModel) {
        self.store = store
        panel = SidePanelWindow(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 600),
                                styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let background = NSVisualEffectView()
        background.material = .sidebar
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: PanelView(store: store, model: model))
        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)
        panel.contentView = background

        panel.onCancel = { [weak model] in model?.escape() }
        model.hidePanel = { [weak self] in self?.hide() }

        // Close when you click into another app, like other Mac side panels.
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.hide()
        }
    }

    func toggle() {
        wantsVisible ? hide() : show()
    }

    func show() {
        store.reloadIfChanged()
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let frame = NSRect(x: area.maxX - Self.width - 10, y: area.minY + 10,
                           width: Self.width, height: area.height - 20)

        let wasVisible = wantsVisible
        wantsVisible = true
        NSApp.activate(ignoringOtherApps: true)
        if wasVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        panel.setFrame(frame.offsetBy(dx: 24, dy: 0), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel.animator().setFrame(frame, display: true)
            self.panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard wantsVisible else { return }
        wantsVisible = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.wantsVisible else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        })
    }
}
