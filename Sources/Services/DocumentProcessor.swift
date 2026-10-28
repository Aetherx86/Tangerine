import Foundation
import AppKit
import CoreText

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

            // Standard document conversion pipeline
            let attr = attributedStringFrom(url: url, srcExt: srcExt)

            if targetExt == "pdf" {
                let pdfData = renderAttributedStringToPDF(attr)
                try pdfData.write(to: outputURL)
                results.append(outputURL)
            } else if targetExt == "docx" {
                if let docxData = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]) {
                    try docxData.write(to: outputURL)
                    results.append(outputURL)
                }
            } else if targetExt == "rtf" {
                if let rtfData = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                    try rtfData.write(to: outputURL)
                    results.append(outputURL)
                }
            } else if targetExt == "html" {
                if srcExt == "md" || srcExt == "markdown" || srcExt == "txt" {
                    let text = (try? String(contentsOf: url, encoding: .utf8)) ?? attr.string
                    let html = markdownToHTML(text, title: url.deletingPathExtension().lastPathComponent)
                    try html.write(to: outputURL, atomically: true, encoding: .utf8)
                    results.append(outputURL)
                } else if let htmlData = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                    try htmlData.write(to: outputURL)
                    results.append(outputURL)
                }
            } else if targetExt == "epub" {
                let text = plainTextFrom(url: url, srcExt: srcExt)
                try createEPUB(title: url.deletingPathExtension().lastPathComponent, text: text, destinationURL: outputURL)
                results.append(outputURL)
            } else if targetExt == "txt" || targetExt == "md" {
                let text = plainTextFrom(url: url, srcExt: srcExt)
                try text.write(to: outputURL, atomically: true, encoding: .utf8)
                results.append(outputURL)
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

    public static func renderAttributedStringToPDF(_ attr: NSAttributedString) -> Data {
        let framesetter = CTFramesetterCreateWithAttributedString(attr as CFAttributedString)
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let margin: CGFloat = 54
        let printableRect = CGRect(x: margin, y: margin, width: 612 - margin * 2, height: 792 - margin * 2)

        var textIndex = 0
        while textIndex < attr.length {
            context.beginPDFPage(nil)
            let path = CGPath(rect: printableRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(textIndex, 0), path, nil)
            CTFrameDraw(frame, context)
            let frameRange = CTFrameGetVisibleStringRange(frame)
            if frameRange.length == 0 { break }
            textIndex += frameRange.length
            context.endPDFPage()
        }
        context.closePDF()
        return pdfData as Data
    }

    public static func attributedStringFrom(url: URL, srcExt: String) -> NSAttributedString {
        if srcExt == "rtf" || srcExt == "rtfd" || srcExt == "docx" || srcExt == "doc" || srcExt == "html" || srcExt == "htm" {
            if let attr = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                return attr
            }
        }

        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if srcExt == "md" || srcExt == "markdown" {
            let html = markdownToHTML(text, title: url.deletingPathExtension().lastPathComponent)
            if let data = html.data(using: .utf8),
               let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
                return attr
            }
        }

        return NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ])
    }

    public static func plainTextFrom(url: URL, srcExt: String) -> String {
        if srcExt == "rtf" || srcExt == "rtfd" || srcExt == "docx" || srcExt == "doc" || srcExt == "html" || srcExt == "htm" {
            if let attr = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                return attr.string
            }
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    public static func markdownToHTML(_ md: String, title: String = "Document") -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset=\"utf-8\">
        <title>\(title)</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; font-size: 13pt; line-height: 1.6; color: #24292f; max-width: 800px; margin: 40px auto; padding: 0 24px; }
        h1 { font-size: 22pt; color: #FF6B00; border-bottom: 2px solid #FF6B00; padding-bottom: 8px; margin-top: 24px; }
        h2 { font-size: 16pt; color: #333; border-bottom: 1px solid #eaecef; padding-bottom: 6px; margin-top: 20px; }
        h3 { font-size: 14pt; color: #444; margin-top: 16px; }
        p { margin: 10px 0; }
        code { font-family: ui-monospace, Menlo, Monaco, monospace; font-size: 11pt; background: #f6f8fa; padding: 2px 5px; border-radius: 4px; border: 1px solid #e1e4e8; }
        pre { background: #f6f8fa; padding: 14px; border-radius: 6px; overflow-x: auto; border: 1px solid #e1e4e8; line-height: 1.45; }
        pre code { background: none; padding: 0; border: none; }
        blockquote { border-left: 4px solid #FF6B00; margin: 12px 0; padding: 4px 16px; color: #57606a; background: #fff8f0; border-radius: 0 4px 4px 0; }
        ul, ol { padding-left: 24px; margin: 8px 0; }
        li { margin: 4px 0; }
        hr { border: none; border-top: 1px solid #d0d7de; margin: 24px 0; }
        </style>
        </head>
        <body>
        """

        var inPre = false
        var inList = false
        let lines = md.components(separatedBy: .newlines)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if inPre {
                    html += "</code></pre>\n"
                    inPre = false
                } else {
                    if inList { html += "</ul>\n"; inList = false }
                    html += "<pre><code>"
                    inPre = true
                }
                continue
            }
            if inPre {
                html += escapeHTML(rawLine) + "\n"
                continue
            }
            if line.isEmpty {
                if inList { html += "</ul>\n"; inList = false }
                continue
            }
            if line.hasPrefix("# ") {
                if inList { html += "</ul>\n"; inList = false }
                html += "<h1>\(formatInline(String(line.dropFirst(2))))</h1>\n"
            } else if line.hasPrefix("## ") {
                if inList { html += "</ul>\n"; inList = false }
                html += "<h2>\(formatInline(String(line.dropFirst(3))))</h2>\n"
            } else if line.hasPrefix("### ") {
                if inList { html += "</ul>\n"; inList = false }
                html += "<h3>\(formatInline(String(line.dropFirst(4))))</h3>\n"
            } else if line.hasPrefix("> ") {
                if inList { html += "</ul>\n"; inList = false }
                html += "<blockquote><p>\(formatInline(String(line.dropFirst(2))))</p></blockquote>\n"
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if !inList {
                    html += "<ul>\n"
                    inList = true
                }
                html += "<li>\(formatInline(String(line.dropFirst(2))))</li>\n"
            } else if line == "---" || line == "***" {
                if inList { html += "</ul>\n"; inList = false }
                html += "<hr/>\n"
            } else {
                if inList { html += "</ul>\n"; inList = false }
                html += "<p>\(formatInline(rawLine))</p>\n"
            }
        }
        if inPre { html += "</code></pre>\n" }
        if inList { html += "</ul>\n" }
        html += "</body></html>"
        return html
    }

    private static func formatInline(_ text: String) -> String {
        var result = escapeHTML(text)
        result = result.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"`(.+?)`"#, with: "<code>$1</code>", options: .regularExpression)
        return result
    }

    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    public static func createEPUB(title: String, text: String, destinationURL: URL) throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("epub_\(UUID().uuidString)")
        let metaInf = tempDir.appendingPathComponent("META-INF")
        let oebps = tempDir.appendingPathComponent("OEBPS")
        try fm.createDirectory(at: metaInf, withIntermediateDirectories: true)
        try fm.createDirectory(at: oebps, withIntermediateDirectories: true)

        let mimetypeURL = tempDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypeURL, atomically: true, encoding: .ascii)

        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        try containerXML.write(to: metaInf.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        let safeTitle = escapeHTML(title)
        let bodyHTML = text.components(separatedBy: .newlines).map { "<p>\(escapeHTML($0))</p>" }.joined(separator: "\n")
        let chapterXHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>\(safeTitle)</title></head>
        <body>
            <h1>\(safeTitle)</h1>
            \(bodyHTML)
        </body>
        </html>
        """
        try chapterXHTML.write(to: oebps.appendingPathComponent("chapter1.xhtml"), atomically: true, encoding: .utf8)

        let bookId = UUID().uuidString
        let contentOPF = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="3.0">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>\(safeTitle)</dc:title>
                <dc:identifier id="BookId">urn:uuid:\(bookId)</dc:identifier>
                <dc:language>en</dc:language>
            </metadata>
            <manifest>
                <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
            </manifest>
            <spine>
                <itemref idref="chapter1"/>
            </spine>
        </package>
        """
        try contentOPF.write(to: oebps.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        try? fm.removeItem(at: destinationURL)
        let zipProcess = Process()
        zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipProcess.currentDirectoryURL = tempDir
        zipProcess.arguments = ["-q", "-r", destinationURL.path, "mimetype", "META-INF", "OEBPS"]
        try zipProcess.run()
        zipProcess.waitUntilExit()
        try? fm.removeItem(at: tempDir)
    }
}
