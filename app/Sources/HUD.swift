import AppKit

// A short on-screen message ("Copied: ...") that fades away by itself.
// Needs no notification permission.
enum HUD {
    private static var panel: NSPanel?

    static func show(_ text: String, seconds: Double = 1.5) {
        panel?.orderOut(nil)

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.sizeToFit()

        let width = min(max(label.frame.width + 48, 180), 560)
        let height = label.frame.height + 28
        label.frame = NSRect(x: 24, y: 14, width: width - 48, height: label.frame.height)

        let background = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        background.layer?.cornerRadius = 12
        background.addSubview(label)

        let newPanel = NSPanel(contentRect: background.frame,
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        newPanel.contentView = background
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.level = .statusBar
        newPanel.ignoresMouseEvents = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let area = screen?.visibleFrame {
            newPanel.setFrameOrigin(NSPoint(x: area.midX - width / 2, y: area.minY + area.height * 0.2))
        }
        newPanel.alphaValue = 1
        newPanel.orderFrontRegardless()
        panel = newPanel

        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard panel === newPanel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                newPanel.animator().alphaValue = 0
            }, completionHandler: {
                newPanel.orderOut(nil)
                if panel === newPanel { panel = nil }
            })
        }
    }
}
