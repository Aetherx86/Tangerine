import Foundation
import AppKit

@MainActor
public final class SoundManager {
    public static let shared = SoundManager()

    private var highlightSound: NSSound?

    private init() {
        if let url = Bundle.main.url(forResource: "HighlightSound", withExtension: "wav") {
            self.highlightSound = NSSound(contentsOf: url, byReference: true)
        } else {
            let local = URL(fileURLWithPath: "Resources/HighlightSound.wav")
            if FileManager.default.fileExists(atPath: local.path) {
                self.highlightSound = NSSound(contentsOf: local, byReference: true)
            }
        }
    }

    public func playHoverTick() {
        guard SettingsStore.shared.playSounds else { return }
        if let sound = highlightSound {
            sound.stop()
            sound.play()
        } else {
            NSSound(named: "Tink")?.play()
        }
    }

    public func playSuccess() {
        guard SettingsStore.shared.playSounds else { return }
        NSSound(named: "Glass")?.play()
    }

    public func playDrop() {
        guard SettingsStore.shared.playSounds else { return }
        NSSound(named: "Pop")?.play()
    }

    public func triggerHaptic() {
        guard SettingsStore.shared.hapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}
