import SwiftUI
import AppKit

@MainActor
public final class MetadataEditorViewModel: ObservableObject {
    public let url: URL
    @Published public var record: FileMetadataRecord
    @Published public var titleInput: String = ""
    @Published public var authorInput: String = ""
    @Published public var copyrightInput: String = ""
    @Published public var descriptionInput: String = ""
    @Published public var statusMessage: String?

    public init(url: URL) {
        self.url = url
        let rec = MetadataReader.readMetadata(for: url)
        self.record = rec
        self.titleInput = rec.title
        self.authorInput = rec.author
        self.copyrightInput = rec.copyright
        self.descriptionInput = rec.description
    }

    public func saveUpdatedMetadata() -> URL? {
        var updated = record
        updated.title = titleInput
        updated.author = authorInput
        updated.copyright = copyrightInput
        updated.description = descriptionInput

        let out = ImageProcessor.destinationURL(for: url, newExtension: "updated_meta.\(url.pathExtension)")
        do {
            try MetadataReader.saveMetadata(record: updated, outputURL: out)
            return out
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
            return nil
        }
    }

    public func stripAllMetadata() -> URL? {
        let out = ImageProcessor.destinationURL(for: url, newExtension: "nometa.\(url.pathExtension)")
        Task {
            _ = try? await ImageProcessor.stripMetadata(urls: [url])
        }
        return out
    }

    public func copyAllToClipboard() {
        var text = "=== Metadata for \(url.lastPathComponent) ===\n"
        for item in record.items {
            text += "\(item.category) - \(item.key): \(item.value)\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "Copied to clipboard!"
    }
}

public struct MetadataEditorView: View {
    @ObservedObject var vm: MetadataEditorViewModel
    public let onSave: (URL) -> Void
    public let onClose: () -> Void

    public init(vm: MetadataEditorViewModel, onSave: @escaping (URL) -> Void, onClose: @escaping () -> Void) {
        self.vm = vm
        self.onSave = onSave
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: vm.url.path))
                    .resizable()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.url.lastPathComponent)
                        .font(.system(size: 14, weight: .bold))
                    Text(vm.url.path)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button("Copy All") {
                    vm.copyAllToClipboard()
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11))
            }
            .padding(16)
            .background(.regularMaterial)

            Divider()

            // Main Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Editable fields
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Editable Tags")
                            .font(.system(size: 13, weight: .bold))

                        VStack(spacing: 8) {
                            HStack {
                                Text("Title:")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                                TextField("Title or Document Name", text: $vm.titleInput)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Author:")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                                TextField("Author, Creator or Artist", text: $vm.authorInput)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                Text("Copyright:")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                                TextField("Copyright Notice", text: $vm.copyrightInput)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack(alignment: .top) {
                                Text("Description:")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                                    .padding(.top, 4)
                                TextEditor(text: $vm.descriptionInput)
                                    .frame(height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Read-only Metadata Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metadata Attributes")
                            .font(.system(size: 13, weight: .bold))

                        if vm.record.items.isEmpty {
                            Text("No embedded metadata attributes detected.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        } else {
                            let grouped = Dictionary(grouping: vm.record.items, by: { $0.category })
                            ForEach(grouped.keys.sorted(), id: \.self) { cat in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(cat)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.orange)

                                    ForEach(grouped[cat] ?? []) { item in
                                        HStack {
                                            Text(item.key)
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.secondary)
                                                .frame(width: 140, alignment: .leading)
                                            Text(item.value)
                                                .font(.system(size: 11, weight: .medium))
                                                .textSelection(.enabled)
                                            Spacer()
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.025))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                if let msg = vm.statusMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.green)
                }

                Spacer()

                Button("Remove All Metadata") {
                    Task {
                        let outputs = try? await ImageProcessor.stripMetadata(urls: [vm.url])
                        if let first = outputs?.first {
                            onSave(first)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(Color.red)

                Button("Close", action: onClose)

                Button("Save Metadata") {
                    if let out = vm.saveUpdatedMetadata() {
                        onSave(out)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.orange)
            }
            .padding(14)
            .background(.regularMaterial)
        }
        .frame(width: 580, height: 600)
    }
}
