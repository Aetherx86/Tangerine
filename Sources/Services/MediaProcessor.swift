import Foundation
import AVFoundation
import AppKit

public struct MediaProcessor: Sendable {
    public static func convert(urls: [URL], toExtension ext: String) async throws -> [URL] {
        var results: [URL] = []
        let targetExt = ext.lowercased()

        for url in urls {
            let outputURL = ImageProcessor.destinationURL(for: url, newExtension: targetExt)

            if targetExt == "mp3" || targetExt == "m4a" {
                // Audio extraction or audio re-encode
                try await extractOrConvertAudio(from: url, to: outputURL, format: targetExt)
                results.append(outputURL)
            } else if targetExt == "gif" {
                // Video to GIF snapshot
                if let gifURL = try await videoToGIF(from: url, to: outputURL) {
                    results.append(gifURL)
                }
            } else {
                // Video to video (MP4/MOV)
                try await exportVideo(from: url, to: outputURL)
                results.append(outputURL)
            }
        }

        return results
    }

    public static func mute(urls: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            let base = url.deletingPathExtension().lastPathComponent
            let outputURL = url.deletingLastPathComponent().appendingPathComponent("\(base)_muted.\(ext)")

            let asset = AVAsset(url: url)
            let composition = AVMutableComposition()

            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let firstVideoTrack = videoTracks.first else { continue }

            let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            let duration = try await asset.load(.duration)
            try compVideoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: firstVideoTrack, at: .zero)

            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                continue
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = outputURL.pathExtension.lowercased() == "mov" ? .mov : .mp4
            await exportSession.export()

            if exportSession.status == .completed {
                results.append(outputURL)
            }
        }
        return results
    }

    public static func snapshot(urls: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let base = url.deletingPathExtension().lastPathComponent
            let outputURL = url.deletingLastPathComponent().appendingPathComponent("\(base)_snapshot.png")

            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            let (cgImage, _) = try await imageGenerator.image(at: time)

            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            if let tiff = nsImage.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try png.write(to: outputURL)
                results.append(outputURL)
            }
        }
        return results
    }

    public static func compress(urls: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            let base = url.deletingPathExtension().lastPathComponent
            let outputURL = url.deletingLastPathComponent().appendingPathComponent("\(base)_compressed.\(ext)")

            let asset = AVAsset(url: url)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
                continue
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = ext == "mov" ? .mov : .mp4
            await exportSession.export()

            if exportSession.status == .completed {
                results.append(outputURL)
            }
        }
        return results
    }

    private static func exportVideo(from inputURL: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "Tangerine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputURL.pathExtension.lowercased() == "mov" ? .mov : .mp4
        await exportSession.export()

        if exportSession.status != .completed {
            throw exportSession.error ?? NSError(domain: "Tangerine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Video export failed"])
        }
    }

    private static func extractOrConvertAudio(from inputURL: URL, to outputURL: URL, format: String) async throws {
        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "Tangerine", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio export session"])
        }

        let m4aURL = format == "m4a" ? outputURL : outputURL.deletingPathExtension().appendingPathExtension("m4a")
        exportSession.outputURL = m4aURL
        exportSession.outputFileType = .m4a
        await exportSession.export()

        if exportSession.status != .completed {
            throw exportSession.error ?? NSError(domain: "Tangerine", code: 6, userInfo: [NSLocalizedDescriptionKey: "Audio export failed"])
        }

        // If target was mp3 and m4a succeeded, rename/keep or convert
        if format != "m4a" && m4aURL != outputURL {
            try? FileManager.default.moveItem(at: m4aURL, to: outputURL)
        }
    }

    private static func videoToGIF(from inputURL: URL, to outputURL: URL) async throws -> URL? {
        let asset = AVAsset(url: inputURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let duration = try await asset.load(.duration).seconds
        let frameCount = min(Int(duration * 6.0), 30) // Up to 30 frames for a quick GIF
        guard frameCount > 0 else { return nil }

        var images: [CGImage] = []
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) * (duration / Double(frameCount)), preferredTimescale: 600)
            if let (cg, _) = try? await generator.image(at: time) {
                images.append(cg)
            }
        }

        guard !images.isEmpty,
              let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, images.count, nil) else {
            return nil
        }

        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: 0.15
            ]
        ]
        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(dest, gifProperties as CFDictionary)

        for img in images {
            CGImageDestinationAddImage(dest, img, frameProperties as CFDictionary)
        }

        if CGImageDestinationFinalize(dest) {
            return outputURL
        }
        return nil
    }
}
