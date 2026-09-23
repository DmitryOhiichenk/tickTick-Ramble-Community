// Renders the app icon into an .iconset folder: swift scripts/make_icon.swift <out.iconset>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    // macOS icon grid: 824/1024 body with rounded corners.
    let inset = s * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.set()
    NSColor(srgbRed: 0.28, green: 0.45, blue: 0.98, alpha: 1).setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGradient(colors: [NSColor(srgbRed: 0.42, green: 0.56, blue: 1, alpha: 1),
                        NSColor(srgbRed: 0.24, green: 0.40, blue: 0.95, alpha: 1)])!.draw(in: path, angle: -90)

    // Concentric rings, like the start screen.
    let c = NSPoint(x: body.midX, y: body.midY)
    for (i, r) in [0.34, 0.27].enumerated() {
        let rr = body.width * r
        let ring = NSBezierPath(ovalIn: NSRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
        ring.lineWidth = s * 0.012
        NSColor.white.withAlphaComponent(i == 0 ? 0.22 : 0.38).setStroke()
        ring.stroke()
    }
    let disc = body.width * 0.2
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - disc, y: c.y - disc, width: disc * 2, height: disc * 2)).fill()

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.2, weight: .semibold)
    if let mic = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let tinted = NSImage(size: mic.size, flipped: false) { rect in
            mic.draw(in: rect)
            NSColor(srgbRed: 0.28, green: 0.45, blue: 0.98, alpha: 1).set()
            rect.fill(using: .sourceAtop)
            return true
        }
        let size = mic.size
        tinted.draw(in: NSRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(base * scale).write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
    }
}
print("iconset written to \(out)")
