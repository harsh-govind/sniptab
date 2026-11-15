# SnipTab

A tiny macOS menu bar app for taking screenshots. Click the ✂️ icon, drag over an area, done.

## Features

- **Left-click** the menu bar icon to drag-select an area and capture it
- **Right-click** for more: capture a window, full screen, area after a 3-second delay, open the screenshots folder, quit
- Every capture is **copied to the clipboard** and saved to `~/Pictures/SnipTab/`
- A preview card drops down after each capture with **Edit** (opens in Preview to crop/annotate), **Copy**, **Finder** and **Delete**
- No Dock icon, follows light/dark menu bar

## Install

1. Download **SnipTab-1.0.dmg** from the [latest release](../../releases/latest).
2. Open it and drag **SnipTab** into **Applications**.
3. The app isn't notarized by Apple, so the first launch is blocked. Open it once from
   **System Settings → Privacy & Security → "Open Anyway"**, or run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/SnipTab.app
   ```

## Build from source

Requires macOS 12+ and the Xcode command line tools (`xcode-select --install`).

```bash
./build.sh            # builds SnipTab.app
./release.sh 1.0      # builds dist/SnipTab-1.0.dmg
```

On the first capture macOS asks for **Screen Recording** permission. Enable SnipTab in
System Settings → Privacy & Security → Screen Recording, then quit and reopen the app.

To start it at login, add `SnipTab.app` under System Settings → General → Login Items.

## How it works

A single Swift file (`main.swift`) creates an `NSStatusItem` and calls the built-in
`/usr/sbin/screencapture` tool for the interactive selection.
