import Foundation
import AppKit
import TangerineKit

@MainActor
func printHelp() {
    print("""
    🍊 Tangerine CLI — Native macOS File Converter & Tool Suite
    
    USAGE:
      tangerine <command> [options]
    
    COMMANDS:
      convert <files...> --to <format>   Convert one or more files to target format
      watch <folder> --to <format>       Watch a folder and automatically convert new files
      formats                            List all supported categories and formats
      help                               Show this help message
    
    OPTIONS:
      --quality <1-100>                  Image compression quality (e.g. --quality 80)
      --dpi <72|150|300>                 PDF rasterization resolution DPI
      -o, --output <dir>                 Output directory for converted files
      --move-originals                   Move source files into .original subfolder when watching
    
    EXAMPLES:
      tangerine convert photo.heic --to jpg --quality 85
      tangerine convert doc.pdf --to png --dpi 300 -o ~/Desktop
      tangerine convert video.mov --to mp4
      tangerine watch ~/Downloads/Incoming --to pdf --move-originals
    """)
}

@MainActor
func printFormats() {
    print("🍊 Supported Formats by Category:")
    print("-----------------------------------")
    for category in FileCategory.allCases {
        let targets = ConversionMatrix.validTargets(for: category)
        print("• \(category.rawValue): \(targets.joined(separator: ", "))")
    }
}

@MainActor
func runConvert(args: [String]) async {
    guard let toIndex = args.firstIndex(of: "--to"), toIndex + 1 < args.count else {
        print("❌ Error: Missing target format. Usage: tangerine convert <files...> --to <format>")
        exit(1)
    }

    let targetExt = args[toIndex + 1].lowercased()
    var filePaths: [String] = []

    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--to" {
            i += 2
            continue
        }
        if arg == "--quality", i + 1 < args.count {
            if let q = Double(args[i + 1]) {
                SettingsStore.shared.jpegQuality = max(0.1, min(1.0, q / 100.0))
            }
            i += 2
            continue
        }
        if arg == "--dpi", i + 1 < args.count {
            if let dpi = Double(args[i + 1]) {
                SettingsStore.shared.pdfDPI = dpi
            }
            i += 2
            continue
        }
        if (arg == "-o" || arg == "--output"), i + 1 < args.count {
            let outDir = (args[i + 1] as NSString).expandingTildeInPath
            SettingsStore.shared.customOutputDirectory = outDir
            SettingsStore.shared.saveBesideOriginal = false
            i += 2
            continue
        }
        if !arg.hasPrefix("-") {
            filePaths.append(arg)
        }
        i += 1
    }

    guard !filePaths.isEmpty else {
        print("❌ Error: No input files specified.")
        exit(1)
    }

    let urls = filePaths.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    let category = FileCategory.detect(from: urls)

    let slice = RadialSlice(
        id: "cli_convert_\(targetExt)",
        title: targetExt.uppercased(),
        actionKind: .convert(targetExtension: targetExt)
    )

    print("🍊 Converting \(urls.count) file(s) to \(targetExt.uppercased())...")
    await ConversionEngine.execute(slice: slice, urls: urls, category: category)
    print("✅ Conversion complete.")
}

@MainActor
func runWatch(args: [String]) {
    guard let toIndex = args.firstIndex(of: "--to"), toIndex + 1 < args.count else {
        print("❌ Error: Missing target format. Usage: tangerine watch <folder> --to <format>")
        exit(1)
    }

    let targetFormat = args[toIndex + 1].uppercased()
    let moveOriginals = args.contains("--move-originals")

    var folderPath: String? = nil
    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--to" {
            i += 2
            continue
        }
        if arg == "--move-originals" {
            i += 1
            continue
        }
        if !arg.hasPrefix("-") {
            folderPath = arg
            break
        }
        i += 1
    }

    guard let folderPath = folderPath else {
        print("❌ Error: Missing folder path.")
        exit(1)
    }

    let folderURL = URL(fileURLWithPath: (folderPath as NSString).expandingTildeInPath)
    guard FileManager.default.fileExists(atPath: folderURL.path) else {
        print("❌ Error: Folder not found: \(folderURL.path)")
        exit(1)
    }

    print("🍊 Watching folder: \(folderURL.path) → \(targetFormat) (Move originals: \(moveOriginals))")
    FolderWatcherService.shared.addRule(folderURL: folderURL, targetFormat: targetFormat, moveOriginals: moveOriginals)
    FolderWatcherService.shared.start()

    print("Press Ctrl+C to stop watching.")
    RunLoop.main.run()
}

@MainActor
func main() async {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else {
        printHelp()
        return
    }

    switch command.lowercased() {
    case "convert":
        await runConvert(args: args)
    case "watch":
        runWatch(args: args)
    case "formats":
        printFormats()
    case "help", "-h", "--help":
        printHelp()
    default:
        print("❌ Unknown command: \(command)")
        printHelp()
        exit(1)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
Task { @MainActor in
    await main()
    exit(0)
}
app.run()
