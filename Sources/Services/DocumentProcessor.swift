import Foundation
import AppKit

public struct DocumentProcessor: Sendable {
    public static func convert(urls: [URL], toExtension ext: String) async throws -> [URL] {
        var results: [URL] = []
        let targetExt = ext.lowercased()

        for url in urls {
            let srcExt = url.pathExtension.lowercased()
            let outputURL = ImageProcessor.destinationURL(for: url, newExtension: targetExt)

            // Subtitle conversions
            if srcExt == "srt" || srcExt == "vtt" {
                let content = try String(contentsOf: url, encoding: .utf8)
                if targetExt == "vtt" {
                    let vtt = convertSRTtoVTT(content)
                    try vtt.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                } else if targetExt == "txt" {
                    let plain = stripSubtitlesToPlain(content)
                    try plain.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                }
                continue
            }

            // General text / markdown / html conversions
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                if targetExt == "html" {
                    let html = "<!DOCTYPE html><html><body><pre>\(text)</pre></body></html>"
                    try html.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                } else {
                    try text.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                }
            }
        }

        return results
    }

    private static func convertSRTtoVTT(_ srt: String) -> String {
        let lines = srt.components(separatedBy: .newlines)
        var result = "WEBVTT\n\n"
        for line in lines {
            // Replace comma in timestamps with period
            if line.contains("-->") {
                let fixed = line.replacingOccurrences(of: ",", with: ".")
                result += fixed + "\n"
            } else {
                result += line + "\n"
            }
        }
        return result
    }

    private static func stripSubtitlesToPlain(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var result = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == "WEBVTT" { continue }
            if Int(trimmed) != nil { continue } // Sequence number
            if trimmed.contains("-->") { continue } // Timestamp line
            result += trimmed + "\n"
        }
        return result
    }
}
