// Renders the 1024×1024 app icon PNG. Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let background = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.95, alpha: 1),
    NSColor(calibratedRed: 0.55, green: 0.18, blue: 0.85, alpha: 1),
])!.draw(in: background, angle: -60)

func drawSymbol(_ name: String, pointSize: CGFloat, centerY: CGFloat) {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return }
    let s = symbol.size
    symbol.draw(in: NSRect(x: (size - s.width) / 2, y: centerY - s.height / 2, width: s.width, height: s.height))
}

drawSymbol("lock.fill", pointSize: 330, centerY: 590)
drawSymbol("keyboard", pointSize: 190, centerY: 300)
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
