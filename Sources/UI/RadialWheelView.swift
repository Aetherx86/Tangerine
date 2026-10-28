import SwiftUI

public struct RadialWheelView: View {
    public let slices: [RadialSlice]
    public let hoveredIndex: Int?
    public let centerText: String
    public let subtitleText: String?
    public let innerRadius: CGFloat
    public let outerRadius: CGFloat
    public let onSelectSlice: ((RadialSlice) -> Void)?

    public init(
        slices: [RadialSlice],
        hoveredIndex: Int?,
        centerText: String = "",
        subtitleText: String? = nil,
        innerRadius: CGFloat = 52,
        outerRadius: CGFloat = 142,
        onSelectSlice: ((RadialSlice) -> Void)? = nil
    ) {
        self.slices = slices
        self.hoveredIndex = hoveredIndex
        self.centerText = centerText
        self.subtitleText = subtitleText
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.onSelectSlice = onSelectSlice
    }

    public var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Ambient frosted backing disc
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.75))
                    .frame(width: (outerRadius + 8) * 2, height: (outerRadius + 8) * 2)
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                    )

                // Wedges
                let count = slices.count
                if count > 0 {
                    ForEach(0..<count, id: \.self) { index in
                        let slice = slices[index]
                        let isHovered = (hoveredIndex == index)
                        let span = (2.0 * .pi) / Double(count)
                        let start = -Double.pi / 2.0 + Double(index) * span
                        let end = start + span

                        WedgeItemView(
                            slice: slice,
                            startAngle: Angle(radians: start),
                            endAngle: Angle(radians: end),
                            innerRadius: innerRadius,
                            outerRadius: outerRadius,
                            isHovered: isHovered,
                            onTap: {
                                onSelectSlice?(slice)
                            }
                        )
                    }
                }

                // Center Hub (only shows active slice title when hovering, otherwise shows centerText like 2.2 MB)
                let active = (hoveredIndex != nil && hoveredIndex! >= 0 && hoveredIndex! < slices.count) ? slices[hoveredIndex!] : nil
                CenterHubView(
                    activeSlice: active,
                    centerText: centerText,
                    radius: innerRadius - 4
                )
            }
            .frame(width: (outerRadius + 14) * 2, height: (outerRadius + 14) * 2)

            // Dynamic bottom caption (e.g. "Convert to PNG", "Compress", or mode default)
            if let active = (hoveredIndex != nil && hoveredIndex! >= 0 && hoveredIndex! < slices.count) ? slices[hoveredIndex!] : nil {
                Text(active.subtitle ?? active.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .animation(.easeInOut(duration: 0.15), value: hoveredIndex)
            } else if let sub = subtitleText, !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.secondary)
            } else {
                Text("Drop file on format to convert")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(16)
    }
}

public struct WedgeItemView: View {
    public let slice: RadialSlice
    public let startAngle: Angle
    public let endAngle: Angle
    public let innerRadius: CGFloat
    public let outerRadius: CGFloat
    public let isHovered: Bool
    public let onTap: () -> Void

    public var body: some View {
        let midAngle = (startAngle.radians + endAngle.radians) / 2.0
        let midR = (innerRadius + outerRadius) / 2.0
        let labelX = midR * CGFloat(cos(midAngle))
        let labelY = midR * CGFloat(sin(midAngle))

        let shape = RadialSliceShape(
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            cornerRadius: 12
        )

        ZStack {
            if isHovered {
                // Vibrant Tangerine Orange fill on hover
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.35, blue: 0.0),
                                Color(red: 1.0, green: 0.18, blue: 0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(shape.stroke(Color.white.opacity(0.45), lineWidth: 1.2))
                    .shadow(color: Color(red: 1.0, green: 0.32, blue: 0.0).opacity(0.55), radius: 12, x: 0, y: 4)
            } else {
                // Warm frosted glass for unselected wedges (matches mockup 2 & 5)
                shape
                    .fill(
                        Color(red: 0.98, green: 0.96, blue: 0.94).opacity(0.85)
                    )
                    .overlay(shape.stroke(Color.white.opacity(0.7), lineWidth: 1))
            }

            // Text / Icon
            VStack(spacing: 3) {
                if let icon = slice.iconName {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(slice.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isHovered ? Color.white : Color(red: 0.12, green: 0.12, blue: 0.14))
            .offset(x: labelX, y: labelY)
            .allowsHitTesting(false)
        }
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .contentShape(shape)
        .onTapGesture(perform: onTap)
    }
}
