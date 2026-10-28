import SwiftUI
import UniformTypeIdentifiers

public struct DropZoneView: View {
    @ObservedObject private var history = ConversionHistoryManager.shared
    @State private var selectedTab: Int = 0 // 0: Donut Simulator, 1: Recent Conversions
    @State private var selectedMode: WheelMode = .convert
    @State private var droppedURLs: [URL] = []
    @State private var hoveredIndex: Int? = nil
    @State private var isTargeted: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Section Switcher (Home / Recent Conversions)
            Picker("", selection: $selectedTab) {
                Text("Donut Simulator").tag(0)
                Text("Recent Conversions (\(history.items.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            if selectedTab == 0 {
                simulatorView
            } else {
                recentConversionsView
            }
        }
        .frame(width: 520, height: 560)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var simulatorView: some View {
        VStack(spacing: 14) {
            // Mode selector
            Picker("Mode", selection: $selectedMode) {
                Text("⇧ Convert Formats").tag(WheelMode.convert)
                Text("⌘ File Tools").tag(WheelMode.tools)
                Text("⌃ File Actions").tag(WheelMode.actions)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .padding(.top, 8)

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
                    subtitleText: selectedMode == .convert ? "Convert formats (Press Tab to flip)" : (selectedMode == .tools ? "File tools" : "File actions"),
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
            Text("Hold a key (Shift, Command, Control), drag files and drop on a format. Press Tab to flip sides.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private var recentConversionsView: some View {
        VStack(spacing: 0) {
            if history.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                    Text("No conversions yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    Text("Drag files over the radial wheel to convert them.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                    Spacer()
                }
            } else {
                HStack {
                    Text("Past Conversions")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Button("Clear History") {
                        history.clearAll()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)

                List {
                    ForEach(history.items) { item in
                        HStack(spacing: 12) {
                            // Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(item.isSuccess ? Color.orange.opacity(0.15) : Color.red.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text(item.targetFormat.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(item.isSuccess ? Color.orange : Color.red)
                            }

                            // Details
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                if let out = item.outputPaths.first {
                                    Text(URL(fileURLWithPath: out).path)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            // Action Buttons (Open, Reveal, Undo)
                            if item.isSuccess && !item.isUndone {
                                Button("Open") {
                                    if let first = item.outputPaths.first {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: first))
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button(action: {
                                    let urls = item.outputPaths.map { URL(fileURLWithPath: $0) }
                                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                                }) {
                                    Image(systemName: "folder")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Reveal in Finder")

                                Button("Undo") {
                                    history.undo(item: item)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(Color.red)
                                .help("Move converted file(s) to Trash")
                            } else if item.isUndone {
                                Text("Trashed")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
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
