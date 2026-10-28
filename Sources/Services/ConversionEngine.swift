import Foundation
import AppKit

public struct ConversionEngine: Sendable {
    public static func execute(slice: RadialSlice, urls: [URL], category: FileCategory) async {
        guard !urls.isEmpty else { return }

        await MainActor.run {
            SoundManager.shared.playDrop()
        }

        switch slice.actionKind {
        case .convert(let targetExt):
            // Validate that the conversion is legal
            for url in urls {
                let srcExt = url.pathExtension.lowercased()
                if !ConversionMatrix.isValid(from: srcExt, to: targetExt) {
                    let errorMsg = "Cannot convert .\(srcExt) to .\(targetExt.lowercased()). \(ConversionMatrix.supportedDescription(for: srcExt))"
                    await MainActor.run {
                        ProgressHUDManager.shared.failJob(error: errorMsg)
                    }
                    return
                }
            }

            await MainActor.run {
                ProgressHUDManager.shared.startJob(
                    title: "Converting...",
                    detail: "\(urls.count) file(s) to \(targetExt.uppercased())"
                )
            }

            do {
                let outputs: [URL]
                switch category {
                case .image:
                    outputs = try await ImageProcessor.convert(urls: urls, toExtension: targetExt)
                case .video, .audio:
                    outputs = try await MediaProcessor.convert(urls: urls, toExtension: targetExt)
                case .pdf:
                    outputs = try await PDFProcessor.convert(urls: urls, toExtension: targetExt)
                case .document, .subtitle, .presentation, .spreadsheet, .epub:
                    outputs = try await DocumentProcessor.convert(urls: urls, toExtension: targetExt)
                case .archive:
                    outputs = try await ArchiveProcessor.convert(urls: urls, toExtension: targetExt)
                default:
                    outputs = try await DocumentProcessor.convert(urls: urls, toExtension: targetExt)
                }

                await MainActor.run {
                    ProgressHUDManager.shared.finishJob(outputURLs: outputs)
                    ConversionHistoryManager.shared.record(
                        sources: urls,
                        outputs: outputs,
                        format: targetExt,
                        success: true
                    )
                }
            } catch {
                await MainActor.run {
                    ProgressHUDManager.shared.failJob(error: error.localizedDescription)
                    ConversionHistoryManager.shared.record(
                        sources: urls,
                        outputs: [],
                        format: targetExt,
                        success: false,
                        error: error.localizedDescription
                    )
                }
            }

        case .tool(let toolName):
            guard let firstURL = urls.first else { return }

            switch toolName.lowercased() {
            case "crop":
                await MainActor.run {
                    ToolWindowManager.shared.openImageEditor(for: firstURL, mode: .crop)
                }
                return

            case "annotate":
                await MainActor.run {
                    ToolWindowManager.shared.openImageEditor(for: firstURL, mode: .annotate)
                }
                return

            case "edit":
                await MainActor.run {
                    ToolWindowManager.shared.openImageEditor(for: firstURL, mode: .adjust)
                }
                return

            case "addbg":
                await MainActor.run {
                    ToolWindowManager.shared.openImageEditor(for: firstURL, mode: .background)
                }
                return

            case "redact":
                await MainActor.run {
                    ToolWindowManager.shared.openImageEditor(for: firstURL, mode: .annotate)
                }
                return

            case "metadata":
                await MainActor.run {
                    ToolWindowManager.shared.openMetadataEditor(for: firstURL)
                }
                return

            default:
                break
            }

            // Direct tools (Compress, Mute, Snapshot, Split, Extract)
            await MainActor.run {
                ProgressHUDManager.shared.startJob(
                    title: "\(slice.title)...",
                    detail: "Processing \(urls.count) file(s)"
                )
            }

            do {
                let outputs: [URL]
                switch toolName.lowercased() {
                case "compress":
                    switch category {
                    case .image:
                        outputs = try await ImageProcessor.compress(urls: urls)
                    case .video:
                        outputs = try await MediaProcessor.compress(urls: urls)
                    case .pdf:
                        outputs = try await PDFProcessor.compress(urls: urls)
                    default:
                        outputs = try await ArchiveProcessor.convert(urls: urls, toExtension: "zip")
                    }

                case "mute":
                    outputs = try await MediaProcessor.mute(urls: urls)

                case "snapshot":
                    outputs = try await MediaProcessor.snapshot(urls: urls)

                case "split":
                    if category == .pdf {
                        outputs = try await PDFProcessor.split(urls: urls)
                    } else {
                        outputs = []
                    }

                case "extract":
                    outputs = try await ArchiveProcessor.extract(urls: urls)

                default:
                    outputs = []
                }

                await MainActor.run {
                    ProgressHUDManager.shared.finishJob(outputURLs: outputs)
                    ConversionHistoryManager.shared.record(
                        sources: urls,
                        outputs: outputs,
                        format: toolName,
                        success: true
                    )
                }
            } catch {
                await MainActor.run {
                    ProgressHUDManager.shared.failJob(error: error.localizedDescription)
                    ConversionHistoryManager.shared.record(
                        sources: urls,
                        outputs: [],
                        format: toolName,
                        success: false,
                        error: error.localizedDescription
                    )
                }
            }

        case .fileAction(let actionType):
            await MainActor.run {
                FileActionsProcessor.handle(action: actionType, urls: urls)
            }
        }
    }
}
