import SwiftUI

public struct CenterHubView: View {
    public let activeSlice: RadialSlice?
    public let centerText: String
    public let radius: CGFloat

    public init(activeSlice: RadialSlice?, centerText: String = "", radius: CGFloat = 50) {
        self.activeSlice = activeSlice
        self.centerText = centerText
        self.radius = radius
    }

    public var body: some View {
        ZStack {
            // Glass background
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.7), Color.white.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )

            // Content
            VStack(spacing: 2) {
                if let active = activeSlice {
                    Text(active.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .transition(.scale.combined(with: .opacity))
                } else if !centerText.isEmpty {
                    Text(centerText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                } else {
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.orange.opacity(0.8))
                }
            }
            .padding(.horizontal, 8)
        }
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.75), value: activeSlice?.id)
    }
}
