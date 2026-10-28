import Foundation
import AppKit

public struct IconProvider: Sendable {
    public static func menuBarImage(style: MenuBarIconStyle) -> NSImage {
        // First check in Bundle.main resources
        let resourceName = (style == .coloredTangerine) ? "MenuBarIcon" : "MenuBarIconTemplate"
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = (style == .monochromeTemplate)
            return img
        }

        // Check relative Resources folder if running from build directory
        let localPath = "Resources/\(resourceName).png"
        if FileManager.default.fileExists(atPath: localPath),
           let img = NSImage(contentsOfFile: localPath) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = (style == .monochromeTemplate)
            return img
        }

        // Programmatic fallback: draw 8-segment tangerine slice
        return drawCitrusSliceImage(size: NSSize(width: 18, height: 18), isTemplate: style == .monochromeTemplate)
    }

    public static func drawCitrusSliceImage(size: NSSize, isTemplate: Bool) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = min(rect.width, rect.height) * 0.46
            let innerRadius = outerRadius * 0.28
            let segmentCount = 8
            let span = (2.0 * Double.pi) / Double(segmentCount)
            let gap = 0.12 // Angular gap in radians

            for i in 0..<segmentCount {
                let startAngle = Double(i) * span + gap / 2.0
                let endAngle = Double(i + 1) * span - gap / 2.0

                context.saveGState()
                let path = CGMutablePath()

                let p1 = CGPoint(
                    x: center.x + innerRadius * CGFloat(cos(startAngle)),
                    y: center.y + innerRadius * CGFloat(sin(startAngle))
                )
                path.move(to: p1)
                path.addArc(
                    center: center,
                    radius: outerRadius,
                    startAngle: CGFloat(startAngle),
                    endAngle: CGFloat(endAngle),
                    clockwise: false
                )
                path.addArc(
                    center: center,
                    radius: innerRadius,
                    startAngle: CGFloat(endAngle),
                    endAngle: CGFloat(startAngle),
                    clockwise: true
                )
                path.closeSubpath()

                context.addPath(path)

                if isTemplate {
                    context.setFillColor(NSColor.black.cgColor)
                    context.fillPath()
                } else {
                    // Vibrant Tangerine gradient
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let colors = [
                        NSColor(red: 1.0, green: 0.48, blue: 0.05, alpha: 1.0).cgColor,
                        NSColor(red: 1.0, green: 0.25, blue: 0.0, alpha: 1.0).cgColor
                    ] as CFArray
                    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                        context.clip()
                        context.drawLinearGradient(
                            gradient,
                            start: CGPoint(x: center.x, y: rect.maxY),
                            end: CGPoint(x: center.x, y: rect.minY),
                            options: []
                        )
                    }
                }
                context.restoreGState()
            }
            return true
        }
    }
}
