import AppKit
import Foundation
import CoreGraphics

let size = 1024

// Create bitmap context with transparent background (NO background fill)
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("ERROR: cannot create context")
    exit(1)
}

let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = nsCtx

// ── NO background! Just transparent ──

// ── Draw banana emoji CENTERED and LARGE ──
let emoji = "🍌" as NSString
let emojiFontSize: CGFloat = CGFloat(size) * 0.98  // Fill the canvas completely

let emojiFont = NSFont(name: "Apple Color Emoji", size: emojiFontSize)
    ?? NSFont.systemFont(ofSize: emojiFontSize)

let attrs: [NSAttributedString.Key: Any] = [
    .font: emojiFont,
    .foregroundColor: NSColor.black
]

let emojiSize = emoji.size(withAttributes: attrs)
let emojiX = (CGFloat(size) - emojiSize.width) / 2.0
let emojiY = (CGFloat(size) - emojiSize.height) / 2.0

emoji.draw(at: NSPoint(x: emojiX, y: emojiY), withAttributes: attrs)

// ── Save as PNG ──
NSGraphicsContext.current = nil

guard let cgImage = ctx.makeImage() else {
    print("ERROR: cannot create CGImage")
    exit(1)
}

let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))

guard let tiff = nsImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("ERROR: cannot encode PNG")
    exit(1)
}

let url = URL(fileURLWithPath: "/Users/changgeng/FocusGuard/build/emoji_master.png")
try! png.write(to: url)
print("SAVED: \(url.path) (\(size)x\(size)) - transparent bg, emoji only")
