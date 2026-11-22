import AppKit

/// macOS-style keyboard backlight icons: a small arc of light rays plus the
/// keyboard keys. `increase` renders long rays, `decrease` renders short ones.
enum KeyboardLightIcon {
    static func image(increase: Bool) -> NSImage {
        let resource = increase ? "keyboard-light-increase" : "keyboard-light-decrease"
        if let url = Bundle.module.url(forResource: resource, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        // Fallback if the bundled asset is missing.
        let size = NSSize(width: 36, height: 36)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()

        // Keyboard keys along the bottom (centre key is wider).
        drawCapsule(from: NSPoint(x: 6, y: 5), to: NSPoint(x: 12, y: 5))
        drawCapsule(from: NSPoint(x: 14.5, y: 5), to: NSPoint(x: 21.5, y: 5))
        drawCapsule(from: NSPoint(x: 24, y: 5), to: NSPoint(x: 30, y: 5))

        // Light rays above the keys.
        let center = NSPoint(x: 18, y: 9)
        let rayLength: CGFloat = increase ? 8 : 3
        for degrees in [35, 65, 90, 115, 145] {
            let angle = CGFloat(degrees) * CGFloat.pi / 180
            let inner: CGFloat = 4
            let start = NSPoint(
                x: center.x + cos(angle) * inner,
                y: center.y + sin(angle) * inner
            )
            let end = NSPoint(
                x: center.x + cos(angle) * (inner + rayLength),
                y: center.y + sin(angle) * (inner + rayLength)
            )
            drawCapsule(from: start, to: end)
        }

        image.unlockFocus()
        return image
    }

    private static func drawCapsule(from start: NSPoint, to end: NSPoint) {
        let path = NSBezierPath()
        path.lineWidth = 2.6
        path.lineCapStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.stroke()
    }
}
