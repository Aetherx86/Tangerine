import SwiftUI
import AppKit

public struct ProgressHUDView: View {
    @ObservedObject var manager: ProgressHUDManager

    public init(manager: ProgressHUDManager) {
        self.manager = manager
    }

    public var body: some View {
        if let job = manager.currentJob {
            HStack(spacing: 12) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(job.isComplete ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 36, height: 36)

                    if job.isComplete {
                        if job.error != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.red)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.green)
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .tint(Color.orange)
                    }
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Text(job.detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Action button
                if job.isComplete && !job.outputURLs.isEmpty {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting(job.outputURLs)
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 12, weight: .medium))
                            .padding(6)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }

                Button(action: {
                    manager.hideHUD()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        }
    }
}
