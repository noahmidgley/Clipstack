# Clipstack

A clipboard history app for the Mac menu bar. Clipstack remembers what you copy (text, links, images, colours and files) so you can find and paste it again later.

Everything stays on your Mac. Clipstack never connects to the network.

## Features

- **Menu bar history.** Click the menu bar icon to see recent copies, newest first, with the app each one came from.
- **Quick Paste.** Press ⇧⌘V in any app to open a floating panel, pick an item and paste it straight into the app you're using. You can change the shortcut in Settings.
- **Search.** Filter by content or by source app.
- **Keyboard driven.** Press ⌘1–⌘9 to choose an item, ⌘P to pin one, ⌫ to delete and ⌘Z to undo.
- **Pinned items.** Pinned items stay at the top and aren't removed by limits or Clear History.
- **Rich content.** Formatted text keeps its styles, with an option to paste it as plain text. Images get thumbnails, and hex codes show a colour swatch.
- **Universal Clipboard.** Copies from an iPhone, iPad or another Mac are labelled "Other Device".
- **Privacy.** Clipstack skips items that password managers mark as concealed or transient (see [nspasteboard.org](https://nspasteboard.org)), can ignore apps you choose, and can clear history on launch.
- **History limits.** Keep a set number of items, keep them for a set number of days, or keep everything.
- **Settings.** Open at login, show or hide the menu bar icon, and change the Quick Paste shortcut.

## Tech stack

- Swift and SwiftUI (`MenuBarExtra`, `Settings` scene, Observation)
- AppKit for the pasteboard, the floating Quick Paste panel and sending ⌘V
- Carbon `RegisterEventHotKey` for the system-wide shortcut
- `ServiceManagement` (`SMAppService`) for open at login
- History saved as JSON with image files in Application Support, and settings saved in `UserDefaults`
- No third-party dependencies

## Requirements

- macOS 27 or later
- Xcode 27 or later

## Running locally

1. Clone the repo:
   ```sh
   git clone https://github.com/noahmidgley/Clipstack.git
   cd Clipstack
   ```
2. Open `Clipstack.xcodeproj` in Xcode.
3. Select the **Clipstack** target, open **Signing & Capabilities**, and choose your own team. The project is set up for the author's team, so it won't sign with another account until you change this.
4. Press ⌘R to build and run. Clipstack runs in the menu bar and doesn't show a Dock icon.
5. To use Quick Paste's auto-paste, allow Clipstack in **System Settings → Privacy & Security → Accessibility** when it asks. macOS needs this before one app can send ⌘V to another.

The app isn't sandboxed because sending keystrokes to other apps doesn't work inside the App Sandbox. It uses the hardened runtime and is meant for Developer ID distribution outside the Mac App Store.

## Project layout

```
Clipstack/
├── ClipstackApp.swift      App entry point: menu bar extra and Settings scene
├── Models/                 ClipItem and AppSettings
├── Services/               Clipboard monitoring, history storage, hotkey, Quick Paste, login item
└── Views/                  Menu bar popover, Quick Paste panel, rows, previews, Settings
```

## License

MIT. See [LICENSE](LICENSE).
