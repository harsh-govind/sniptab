// Renders a macOS app icon (.icns) from an SF Symbol on a gradient tile.
// Usage: swift make_icon.swift <symbol> <topHex> <bottomHex> <out.icns>
import Cocoa

let args = CommandLine.arguments
guard args.count == 5 else { print("usage: make_icon.swift symbol topHex bottomHex out.icns"); exit(1) }
let symbol = args[1], outPath = args[4]

func color(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                   blue: CGFloat(v & 255) / 255, alpha: 1)
}
let top = color(args[2]), bottom = color(args[3])

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)   // draw in a 1024pt space at any pixel size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Standard macOS icon tile: 824pt rounded square centred in 1024.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let path = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    bottom.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: top, ending: bottom)!.draw(in: path, angle: -90)

    // Soft top highlight.
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(starting: NSColor(white: 1, alpha: 0.22), ending: NSColor(white: 1, alpha: 0))!
        .draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // White glyph, scaled to fit ~520pt.
    let cfg = NSImage.SymbolConfiguration(pointSize: 400, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let s = img.size
        let k = min(520 / s.width, 520 / s.height)
        let w = s.width * k, h = s.height * k
        let glyphShadow = NSShadow()
        glyphShadow.shadowColor = NSColor(white: 0, alpha: 0.25)
        glyphShadow.shadowBlurRadius = 14
        glyphShadow.shadowOffset = NSSize(width: 0, height: -6)
        glyphShadow.set()
        img.draw(in: NSRect(x: 512 - w / 2, y: 512 - h / 2, width: w, height: h))
    } else {
        print("unknown SF Symbol: \(symbol)"); exit(1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent(UUID().uuidString + ".iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", outPath]
try! p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(p.terminationStatus)
