# 🍊 Tangerine for macOS

**Tangerine** converts and processes files right where you are in Finder—no extra windows, no web uploads, 100% private and on-device.

---

## ✨ Features

* **Instant Radial Wheel**: Hold a modifier key while dragging files in Finder to summon an interactive radial wheel around your mouse cursor.
  * **`⇧ Shift`**: **Format Conversions** (PNG, JPG, WebP, HEIC, AVIF, TIFF, PDF, MP4, MP3, etc.)
  * **`⌘ Command`**: **File Tools** (Compress, Strip Metadata, Crop, Mute, Trim, Snapshot, Split, Extract)
  * **`⌃ Control`**: **File Actions** (AirDrop, Floating Shelf, Copy, Move, Copy Path, Terminal)
* **Tangerine Citrus Aesthetics**: Frosted glassmorphic wedges with Tangerine orange glow and polar hit-testing.
* **Tangerine Menu Bar Icon**: Custom menu bar icon styled after the citrus wheel with support for both vibrant orange and monochrome template modes.
* **Drop Zone / Simulator Window**: Test and use the radial wheel directly from the menu bar anytime.
* **Floating Shelf**: Pin a drawer to the screen edge to collect files and drag them into other apps.
* **Floating Progress HUD**: Notification card indicating conversion status with one-click "Reveal in Finder".

---

## 🚀 Building & Running

### Option 1: Run the bundled application
```bash
open Tangerine.app
```

### Option 2: Build from source with the build script
```bash
./Scripts/build_app.sh
```

### Option 3: Swift Package Manager
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run
```

---

## 🔒 Permissions

To enable global drag & modifier key monitoring while in Finder, grant **Accessibility** permission:
1. Open **System Settings > Privacy & Security > Accessibility**.
2. Enable **Tangerine**.
*(Alternatively, use the built-in **Drop Zone** window to convert files without Accessibility permissions).*
