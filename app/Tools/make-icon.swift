import AppKit

// Draws the QuickSnip app icon as a 1024px PNG: white scissors on a
// graphite tile with a blue accent.
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let tileRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.22, blue: 0.27, alpha: 1),
           ending: NSColor(srgbRed: 0.09, green: 0.10, blue: 0.13, alpha: 1))!.draw(in: tile, angle: -90)

// Soft blue glow behind the scissors.
NSGraphicsContext.saveGraphicsState()
tile.addClip()
let glow = NSGradient(colors: [NSColor(srgbRed: 0.18, green: 0.42, blue: 0.96, alpha: 0.55),
                               NSColor(srgbRed: 0.18, green: 0.42, blue: 0.96, alpha: 0)])!
glow.draw(fromCenter: NSPoint(x: 512, y: 470), radius: 0, toCenter: NSPoint(x: 512, y: 470), radius: 430, options: [])
NSGraphicsContext.restoreGraphicsState()

// Subtle top highlight on the tile edge.
NSColor(white: 1, alpha: 0.08).setStroke()
tile.lineWidth = 4
tile.stroke()

if let symbol = NSImage(systemSymbolName: "scissors", accessibilityDescription: nil)?
    .withSymbolConfiguration(.init(pointSize: 400, weight: .semibold)) {
    let white = NSImage(size: symbol.size, flipped: false) { rect in
        symbol.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    let s = white.size
    white.draw(in: NSRect(x: (1024 - s.width) / 2, y: (1024 - s.height) / 2, width: s.width, height: s.height))
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
