import Foundation
import AppKit

@MainActor
public final class FolderWatcherService: ObservableObject {
    public static let shared = FolderWatcherService()

    private var timer: Timer?
    private var pendingCandidates: [String: (size: Int64, stableTicks: Int)] = [:]
    private var processedFiles: Set<String> = []

    private let ignoredExtensions: Set<String> = [
        "tmp", "temp", "part", "partial", "crdownload", "download", "opdownload", "filepart", "ds_store"
    ]

    private init() {}

    public func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanWatchedFolders()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        pendingCandidates.removeAll()
    }

    public func addRule(folderURL: URL, targetFormat: String, moveOriginals: Bool = false) {
        var rules = SettingsStore.shared.watchRules
        rules.removeAll { $0.folderPath == folderURL.path }
        rules.append(WatchRule(folderPath: folderURL.path, targetFormat: targetFormat, moveOriginals: moveOriginals, isEnabled: true))
        SettingsStore.shared.watchRules = rules
    }

    public func removeRule(id: UUID) {
        var rules = SettingsStore.shared.watchRules
        rules.removeAll { $0.id == id }
        SettingsStore.shared.watchRules = rules
    }

    public func toggleRule(id: UUID) {
        var rules = SettingsStore.shared.watchRules
        if let idx = rules.firstIndex(where: { $0.id == id }) {
            rules[idx].isEnabled.toggle()
            SettingsStore.shared.watchRules = rules
        }
    }

    private func scanWatchedFolders() {
        let rules = SettingsStore.shared.watchRules.filter(\.isEnabled)
        guard !rules.isEmpty else { return }

        let fm = FileManager.default

        for rule in rules {
            guard fm.fileExists(atPath: rule.folderPath) else { continue }
            let folderURL = URL(fileURLWithPath: rule.folderPath)

            guard let files = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) else {
                continue
            }

            for file in files {
                let ext = file.pathExtension.lowercased()
                let path = file.path

                // Skip ignored extensions and already processed files
                if ignoredExtensions.contains(ext) || processedFiles.contains(path) {
                    continue
                }

                // Skip if already in the target format
                if ext == rule.targetFormat.lowercased() {
                    continue
                }

                guard let attrs = try? fm.attributesOfItem(atPath: path),
                      let fileSize = attrs[.size] as? Int64 else {
                    continue
                }

                // Check Finder copy-in-progress sentinel date (Jan 24, 1984)
                if let created = attrs[.creationDate] as? Date {
                    let comps = Calendar.current.dateComponents([.year, .month, .day], from: created)
                    if comps.year == 1984 && comps.month == 1 && comps.day == 24 {
                        // Finder is currently copying this file! Wait until finished.
                        continue
                    }
                }

                // File settling verification (must remain steady size across ticks)
                if let candidate = pendingCandidates[path] {
                    if candidate.size == fileSize {
                        let newTicks = candidate.stableTicks + 1
                        if newTicks >= 2 {
                            // File is settled and ready for conversion!
                            pendingCandidates.removeValue(forKey: path)
                            processedFiles.insert(path)
                            processWatchFile(file, rule: rule)
                        } else {
                            pendingCandidates[path] = (fileSize, newTicks)
                        }
                    } else {
                        // File is still actively writing! Reset tick count.
                        pendingCandidates[path] = (fileSize, 0)
                    }
                } else {
                    pendingCandidates[path] = (fileSize, 0)
                }
            }
        }
    }

    private func processWatchFile(_ fileURL: URL, rule: WatchRule) {
        Task {
            let cat = FileCategory.detect(from: [fileURL])
            let slice = RadialSlice(
                id: "watch_\(rule.targetFormat)",
                title: rule.targetFormat.uppercased(),
                actionKind: .convert(targetExtension: rule.targetFormat.lowercased())
            )

            await ConversionEngine.execute(slice: slice, urls: [fileURL], category: cat)

            if rule.moveOriginals {
                try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            }
        }
    }
}
