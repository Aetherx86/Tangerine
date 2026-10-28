import Foundation

public struct ArchiveProcessor: Sendable {
    public static func convert(urls: [URL], toExtension ext: String) async throws -> [URL] {
        var results: [URL] = []
        let targetExt = ext.lowercased()

        for url in urls {
            let base = url.deletingPathExtension().lastPathComponent
            let folder = url.deletingLastPathComponent()

            if targetExt == "zip" {
                let out = folder.appendingPathComponent("\(base).zip")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--sequesterRsrc", url.path, out.path]
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    results.append(out)
                }
            } else if targetExt == "tar" {
                let out = folder.appendingPathComponent("\(base).tar")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-cf", out.path, "-C", folder.path, url.lastPathComponent]
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    results.append(out)
                }
            } else if targetExt == "gzip" || targetExt == "gz" {
                let out = folder.appendingPathComponent("\(base).tar.gz")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-czf", out.path, "-C", folder.path, url.lastPathComponent]
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    results.append(out)
                }
            }
        }
        return results
    }

    public static func extract(urls: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let base = url.deletingPathExtension().lastPathComponent
            let folder = url.deletingLastPathComponent()
            let destFolder = folder.appendingPathComponent(base)
            try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)

            let ext = url.pathExtension.lowercased()
            let process = Process()

            if ext == "zip" {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-x", "-k", url.path, destFolder.path]
            } else if ext == "tar" || ext == "gz" || ext == "tgz" {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-xf", url.path, "-C", destFolder.path]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-x", "-k", url.path, destFolder.path]
            }

            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                results.append(destFolder)
            }
        }
        return results
    }
}
