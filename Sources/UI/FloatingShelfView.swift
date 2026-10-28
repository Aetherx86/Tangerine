import SwiftUI
import AppKit

public struct FloatingShelfView: View {
    @ObservedObject var manager: FloatingShelfManager

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
                Text("Floating Shelf")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Button("Clear") {
                    manager.clear()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)

                Button(action: {
                    manager.hideShelf()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // List of floating items
            if manager.floatingFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.secondary)
                    Text("Shelf is empty")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(manager.floatingFiles, id: \.self) { url in
                            FloatingItemRow(url: url) {
                                manager.removeFile(url)
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 260, height: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}

public struct FloatingItemRow: View {
    public let url: URL
    public let onRemove: () -> Void

    public var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(url.pathExtension.uppercased())
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onDrag {
            NSItemProvider(object: url as NSURL)
        }
    }
}
