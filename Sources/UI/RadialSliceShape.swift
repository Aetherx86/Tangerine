import SwiftUI

public struct RadialSliceShape: Shape {
    public var startAngle: Angle
    public var endAngle: Angle
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat
    public var cornerRadius: CGFloat

    public var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(startAngle.radians, endAngle.radians)
        }
        set {
            startAngle = Angle(radians: newValue.first)
            endAngle = Angle(radians: newValue.second)
        }
    }

    public init(
        startAngle: Angle,
        endAngle: Angle,
        innerRadius: CGFloat = 55,
        outerRadius: CGFloat = 135,
        cornerRadius: CGFloat = 12
    ) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        let span = endAngle.radians - startAngle.radians
        // If single slice (360 degrees full donut ring)
        if span >= .pi * 1.99 {
            path.addArc(center: center, radius: outerRadius, startAngle: .zero, endAngle: .radians(.pi * 2), clockwise: false)
            path.addArc(center: center, radius: innerRadius, startAngle: .radians(.pi * 2), endAngle: .zero, clockwise: true)
            path.closeSubpath()
            return path
        }

        // Slight angular gap padding so wedges don't touch
        let angularPadding = 0.04 // ~2.3 degrees gap
        let sAngle = startAngle.radians + angularPadding
        let eAngle = endAngle.radians - angularPadding

        guard eAngle > sAngle else { return path }

        let p1 = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(sAngle)),
            y: center.y + innerRadius * CGFloat(sin(sAngle))
        )
        let p2 = CGPoint(
            x: center.x + outerRadius * CGFloat(cos(sAngle)),
            y: center.y + outerRadius * CGFloat(sin(sAngle))
        )
        let p4 = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(eAngle)),
            y: center.y + innerRadius * CGFloat(sin(eAngle))
        )

        // Draw rounded wedge with quad curves
        path.move(to: p1)
        path.addLine(to: p2)
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: Angle(radians: sAngle),
            endAngle: Angle(radians: eAngle),
            clockwise: false
        )
        path.addLine(to: p4)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: Angle(radians: eAngle),
            endAngle: Angle(radians: sAngle),
            clockwise: true
        )
        path.closeSubpath()

        return path
    }
}
