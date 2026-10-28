import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @State private var hasAccessibilityPermission: Bool = AXIsProcessTrusted()

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            modifiersTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            formatsTab
                .tabItem {
                    Label("Formats & Quality", systemImage: "slider.horizontal.3")
                }

            watchFoldersTab
                .tabItem {
                    Label("Watch Folders", systemImage: "folder.badge.gearshape")
                }

            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised")
                }
        }
        .frame(width: 520, height: 380)
        .padding(20)
        .onAppear {
            checkPermissions()
        }
    }

    private var generalTab: some View {
        Form {
            Section("Menu Bar & Appearance") {
                Picker("Menu Bar Icon Style", selection: $store.menuBarIconStyleRaw) {
                    Text("Vibrant Orange Tangerine").tag(MenuBarIconStyle.coloredTangerine.rawValue)
                    Text("Monochrome Template").tag(MenuBarIconStyle.monochromeTemplate.rawValue)
                }
                .pickerStyle(.radioGroup)
            }

            Section("Feedback") {
                Toggle("Play sound effects on drop and hover", isOn: $store.playSounds)
                Toggle("Haptic feedback on trackpad", isOn: $store.hapticFeedback)
                Toggle("Reveal finished files in Finder", isOn: $store.revealInFinder)
            }
        }
        .formStyle(.grouped)
    }

    private var modifiersTab: some View {
        Form {
            Section("Trigger Keys (tap while dragging in Finder)") {
                Picker("Convert Formats Wheel", selection: $store.convertModifierKey) {
                    Text("⇧ Shift (Default)").tag("shift")
                    Text("⌥ Option").tag("option")
                    Text("⌘ Command").tag("command")
                    Text("⌃ Control").tag("control")
                }

                Picker("File Tools Wheel", selection: $store.toolsModifierKey) {
                    Text("⌘ Command (Default)").tag("command")
                    Text("⌥ Option").tag("option")
                    Text("⇧ Shift").tag("shift")
                    Text("⌃ Control").tag("control")
                }

                Picker("File Actions Wheel", selection: $store.actionsModifierKey) {
                    Text("⌃ Control (Default)").tag("control")
                    Text("⌥ Option").tag("option")
                    Text("⌘ Command").tag("command")
                    Text("⇧ Shift").tag("shift")
                }
            }

            Text("Start dragging any file in Finder, then tap the key. The radial wheel will stay open until dropped.")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
        .formStyle(.grouped)
    }

    private var formatsTab: some View {
        Form {
            Section("Image & Document Quality") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("JPEG / WebP Quality")
                        Spacer()
                        Text("\(Int(store.jpegQuality * 100))%")
                            .foregroundStyle(Color.secondary)
                    }
                    Slider(value: $store.jpegQuality, in: 0.3...1.0, step: 0.05)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("PDF Page Export DPI")
                        Spacer()
                        Text("\(Int(store.pdfDPI)) DPI")
                            .foregroundStyle(Color.secondary)
                    }
                    Slider(value: $store.pdfDPI, in: 72...600, step: 24)
                }
            }

            Section("Destination") {
                Toggle("Save converted files right beside the original", isOn: $store.saveBesideOriginal)
            }
        }
        .formStyle(.grouped)
    }

    private var watchFoldersTab: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Automatically convert files that land in watched folders.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Button("+ Add Folder…") {
                    pickWatchFolder()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.orange)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if store.watchRules.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                    Text("No Watch Folders Added")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                    Text("Drop or choose a folder to automatically convert any new file.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                    Spacer()
                }
            } else {
                List {
                    ForEach(store.watchRules) { rule in
                        HStack(spacing: 10) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(URL(fileURLWithPath: rule.folderPath).lastPathComponent)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(rule.folderPath)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("→ \(rule.targetFormat.uppercased())")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            Toggle("", isOn: Binding(
                                get: { rule.isEnabled },
                                set: { _ in FolderWatcherService.shared.toggleRule(id: rule.id) }
                            ))
                            .labelsHidden()

                            Button(action: {
                                FolderWatcherService.shared.removeRule(id: rule.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func pickWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch Folder"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                FolderWatcherService.shared.addRule(folderURL: url, targetFormat: "PNG")
            }
        }
    }

    private var permissionsTab: some View {
        VStack(spacing: 16) {
            Image(systemName: hasAccessibilityPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(hasAccessibilityPermission ? Color.green : Color.orange)

            Text(hasAccessibilityPermission ? "Accessibility Granted" : "Accessibility Permission Needed")
                .font(.system(size: 15, weight: .bold))

            Text("Tangerine uses macOS Accessibility to detect when you hold Shift, Command, or Control while dragging files in Finder.")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !hasAccessibilityPermission {
                Button("Open System Settings > Privacy & Security > Accessibility") {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.orange)
            }

            Button("Refresh Permission Status") {
                checkPermissions()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func checkPermissions() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
}
