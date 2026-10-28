# 🍊 Tangerine for macOS

**Tangerine** converts and processes files right where you are in Finder—no extra windows, no web uploads, 100% private and on-device.

---

## ✨ Features

* **Instant Radial Wheel**: Hold a modifier key while dragging files in Finder to summon an interactive radial wheel around your mouse cursor.
  * **`⇧ Shift`**: **Format Conversions** (PNG, JPG, WebP, HEIC, AVIF, TIFF, PDF, MP4, MP3, ICO, ICNS, HWPX, AAC, 7Z, etc.)
  * **`⌘ Command`**: **File Tools** (Compress, Strip Metadata, Crop, Mute, Trim, Snapshot, Split, Merge, Extract)
  * **`⌃ Control`**: **File Actions** (AirDrop, Floating Shelf, Copy, Move, Copy Path, Terminal)
* **Two-Sided Donut (Flip Side)**: Press `Tab` or use mouse scroll wheel to flip the radial wheel between Side 1 (primary formats) and Side 2 (tools and actions) on the fly.
* **Watch Folders**: Automatically convert incoming files in designated directories with settling detection (ignores incomplete downloads, `.crdownload`, and Finder copying sentinels).
* **Recent Conversions & Undo**: Track completed conversion history in the Drop Zone window with one-click "Undo" that safely moves output files to the macOS Trash.
* **Direct Web Drag**: Drag images and URLs directly out of Chrome, Safari, Firefox, and Edge into Tangerine to automatically fetch and convert them.
* **Command-Line Interface (`tangerine`)**: Full CLI tool built-in (`tangerine convert`, `tangerine watch`, `tangerine formats`).
* **Tangerine Citrus Aesthetics**: Frosted glassmorphic wedges with Tangerine orange glow and polar hit-testing.
* **Tangerine Menu Bar Icon**: Custom menu bar icon styled after the citrus wheel with support for both vibrant orange and monochrome template modes.
* **Drop Zone / Simulator Window**: Test and use the radial wheel directly from the menu bar anytime, or manage Watch Folders and Recent Conversions.
* **Floating Shelf**: Pin a drawer to the screen edge to collect files and drag them into other apps.
* **Floating Progress HUD**: Notification card indicating conversion status with one-click "Reveal in Finder".

---

## 💻 Command-Line Interface (`tangerine`)

Tangerine includes a fast, native CLI installed at `~/.local/bin/tangerine`:

```bash
# Convert files to any supported format
tangerine convert photo.heic --to jpg
tangerine convert document.pdf --to png
tangerine convert recording.mov --to mp4

# Watch a folder and automatically convert incoming files
tangerine watch ~/Downloads/Incoming --to pdf

# List all supported formats and categories
tangerine formats
```

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
