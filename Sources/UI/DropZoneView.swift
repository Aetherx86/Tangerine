import SwiftUI
import UniformTypeIdentifiers

public struct DropZoneView: View {
    @State private var selectedMode: WheelMode = .convert
    @State private var droppedURLs: [URL] = []
    @State private var hoveredIndex: Int? = nil
    @State private var isTargeted: Bool = false

    public var body: some View {
        VStack(spacing: 16) {
            // Mode selector
            Picker("Mode", selection: $selectedMode) {
                Text("⇧ Convert Formats").tag(WheelMode.convert)
                Text("⌘ File Tools").tag(WheelMode.tools)
                Text("⌃ File Actions").tag(WheelMode.actions)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .padding(.top, 16)

            // Dropped file indicator banner
            if !droppedURLs.isEmpty {
                let cat = FileCategory.detect(from: droppedURLs)
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(Color.orange)
                    Text("\(droppedURLs.first?.lastPathComponent ?? "") (\(cat.rawValue))")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Button("Remove") {
                        droppedURLs.removeAll()
                    }
                    .font(.system(size: 11))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
            }

            // Radial Wheel
            let cat = FileCategory.detect(from: droppedURLs)
            let ext = droppedURLs.first?.pathExtension ?? "png"
            let slices = RadialSlice.slices(for: cat, mode: selectedMode, currentExtension: ext)

            ZStack {
                RadialWheelView(
                    slices: slices,
                    hoveredIndex: hoveredIndex,
                    centerText: droppedURLs.isEmpty ? "Drop Here" : "\(droppedURLs.count) file",
                    subtitleText: selectedMode == .convert ? "Convert formats" : (selectedMode == .tools ? "File tools" : "File actions"),
                    onSelectSlice: { slice in
                        if !droppedURLs.isEmpty {
                            Task {
                                await ConversionEngine.execute(slice: slice, urls: droppedURLs, category: cat)
                            }
                        }
                    }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        updateHover(location: location, count: slices.count)
                    case .ended:
                        hoveredIndex = nil
                    }
                }
            }
            .frame(width: 360, height: 360)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                loadDroppedFiles(providers)
                return true
            }

            Spacer()

            // Bottom guide matching mockup 5 caption
            Text("Start dragging, then tap a key. The wheel stays open until you drop. Change the keys in Settings.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 16)
        }
        .frame(width: 480, height: 520)
        .background(.regularMaterial)
    }

    private func updateHover(location: CGPoint, count: Int) {
        guard count > 0 else { return }
        // Center is at (180, 180) in a 360x360 frame
        let centerX: CGFloat = 180
        let centerY: CGFloat = 180
        let dx = location.x - centerX
        // SwiftUI y increases downwards, so dy > 0 is down
        let dy = location.y - centerY
        let distance = sqrt(dx * dx + dy * dy)

        guard distance >= 50 && distance <= 150 else {
            if hoveredIndex != nil { hoveredIndex = nil }
            return
        }

        // Angle in radians (-pi to pi) where 0 is right (+x)
        let angle = atan2(dy, dx)
        // Convert to clockwise from top (-pi/2)
        var angleFromTop = angle - (-Double.pi / 2.0)
        if angleFromTop < 0 { angleFromTop += 2.0 * .pi }

        let span = (2.0 * .pi) / Double(count)
        let idx = Int(angleFromTop / span) % count

        if idx != hoveredIndex {
            hoveredIndex = idx
            SoundManager.shared.playHoverTick()
            SoundManager.shared.triggerHaptic()
        }
    }

    private func loadDroppedFiles(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.droppedURLs.append(url)
                    }
                } else if let url = item as? URL {
                    DispatchQueue.main.async {
                        self.droppedURLs.append(url)
                    }
                }
            }
        }
    }
}
