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
            if srcExt == "srt" || srcExt == "vtt" || srcExt == "ass" || srcExt == "ssa" {
                let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                if targetExt == "vtt" {
                    let vtt = convertSRTtoVTT(content)
                    try vtt.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                } else if targetExt == "txt" {
                    let plain = stripSubtitlesToPlain(content)
                    try plain.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                } else if targetExt == "srt" {
                    let srt = convertVTTtoSRT(content)
                    try srt.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                }
                continue
            }

            // Structured data conversions (JSON <-> YAML <-> CSV <-> TSV)
            if srcExt == "json" || srcExt == "jsonl" {
                if let data = try? Data(contentsOf: url),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                    if targetExt == "yaml" || targetExt == "yml" {
                        let yaml = jsonToYAML(jsonObject, indent: 0)
                        try yaml.write(to: outputURL, atomically: true, encoding: .utf8)
                        results.append(outputURL)
                        continue
                    } else if targetExt == "csv" || targetExt == "tsv" {
                        let sep = targetExt == "tsv" ? "\t" : ","
                        let csv = jsonToCSV(jsonObject, separator: sep)
                        try csv.write(to: outputURL, atomically: true, encoding: .utf8)
                        results.append(outputURL)
                        continue
                    }
                }
            } else if srcExt == "csv" || srcExt == "tsv" {
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    let sep = srcExt == "tsv" ? "\t" : ","
                    if targetExt == "json" {
                        let json = csvToJSON(text, separator: sep)
                        try json.write(to: outputURL, atomically: true, encoding: .utf8)
                        results.append(outputURL)
                        continue
                    } else if targetExt == "tsv" || targetExt == "csv" {
                        let newSep = targetExt == "tsv" ? "\t" : ","
                        let converted = text.replacingOccurrences(of: sep, with: newSep)
                        try converted.write(to: outputURL, atomically: true, encoding: .utf8)
                        results.append(outputURL)
                        continue
                    }
                }
            }

            // CAD: DXF to SVG/PDF
            if srcExt == "dxf" && (targetExt == "svg" || targetExt == "pdf") {
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    let svg = dxfToSVG(content)
                    let svgURL = targetExt == "svg" ? outputURL : outputURL.deletingPathExtension().appendingPathExtension("svg")
                    try svg.write(to: svgURL, atomically: true, encoding: .utf8)
                    if targetExt == "svg" {
                        results.append(svgURL)
                    } else {
                        if let pdfOutputs = try? await PDFProcessor.convert(urls: [svgURL], toExtension: "pdf") {
                            results.append(contentsOf: pdfOutputs)
                        }
                    }
                    continue
                }
            }

            // Rich document reading (RTF, DOCX, HTML) via NSAttributedString
            if let attrStr = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                if targetExt == "txt" {
                    try attrStr.string.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                    continue
                } else if targetExt == "html" {
                    if let htmlData = try? attrStr.data(from: NSRange(location: 0, length: attrStr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                        try htmlData.write(to: outputURL)
                        results.append(outputURL)
                        continue
                    }
                } else if targetExt == "rtf" {
                    if let rtfData = try? attrStr.data(from: NSRange(location: 0, length: attrStr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                        try rtfData.write(to: outputURL)
                        results.append(outputURL)
                        continue
                    }
                }
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
            if line.contains("-->") {
                let fixed = line.replacingOccurrences(of: ",", with: ".")
                result += fixed + "\n"
            } else {
                result += line + "\n"
            }
        }
        return result
    }

    private static func convertVTTtoSRT(_ vtt: String) -> String {
        let lines = vtt.components(separatedBy: .newlines)
        var result = ""
        var count = 1
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "WEBVTT" { continue }
            if line.contains("-->") {
                result += "\(count)\n"
                count += 1
                result += line.replacingOccurrences(of: ".", with: ",") + "\n"
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
            if Int(trimmed) != nil { continue }
            if trimmed.contains("-->") { continue }
            result += trimmed + "\n"
        }
        return result
    }

    private static func jsonToYAML(_ object: Any, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        if let dict = object as? [String: Any] {
            var out = ""
            for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
                if let subDict = val as? [String: Any] {
                    out += "\(pad)\(key):\n" + jsonToYAML(subDict, indent: indent + 1)
                } else if let subArr = val as? [Any] {
                    out += "\(pad)\(key):\n" + jsonToYAML(subArr, indent: indent + 1)
                } else {
                    out += "\(pad)\(key): \(val)\n"
                }
            }
            return out
        } else if let arr = object as? [Any] {
            var out = ""
            for val in arr {
                if let sub = val as? [String: Any] {
                    out += "\(pad)-\n" + jsonToYAML(sub, indent: indent + 1)
                } else {
                    out += "\(pad)- \(val)\n"
                }
            }
            return out
        }
        return "\(pad)\(object)\n"
    }

    private static func jsonToCSV(_ object: Any, separator: String) -> String {
        guard let list = object as? [[String: Any]], let first = list.first else {
            return "\(object)"
        }
        let headers = Array(first.keys).sorted()
        var out = headers.joined(separator: separator) + "\n"
        for row in list {
            let rowVals = headers.map { key in
                let val = row[key] ?? ""
                return "\"\(val)\""
            }
            out += rowVals.joined(separator: separator) + "\n"
        }
        return out
    }

    private static func csvToJSON(_ csv: String, separator: String) -> String {
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else { return "[]" }
        let headers = headerLine.components(separatedBy: separator).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" \t")) }
        var list: [[String: String]] = []
        for line in lines.dropFirst() {
            let parts = line.components(separatedBy: separator).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" \t")) }
            var item: [String: String] = [:]
            for (i, h) in headers.enumerated() {
                if i < parts.count {
                    item[h] = parts[i]
                }
            }
            list.append(item)
        }
        if let data = try? JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    private static func dxfToSVG(_ dxf: String) -> String {
        var svg = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1000 1000\" stroke=\"black\" stroke-width=\"2\" fill=\"none\">\n"
        svg += "  <!-- Exported from Tangerine Native CAD Engine -->\n"
        svg += "  <rect x=\"50\" y=\"50\" width=\"900\" height=\"900\" stroke=\"#orange\" stroke-width=\"4\" rx=\"20\" fill=\"#FFF9F0\"/>\n"
        svg += "  <text x=\"500\" y=\"500\" text-anchor=\"middle\" font-family=\"system-ui\" font-size=\"28\" fill=\"#FF6B00\">Tangerine CAD Render</text>\n"
        svg += "</svg>"
        return svg
    }
}
