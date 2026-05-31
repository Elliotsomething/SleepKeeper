# Storage Cleaner Design

## Goal

Add a storage cleaner to SleepKeeper that scans common user folders for large files and lets the user move selected files to the macOS Trash.

## Scope

The first version defaults to a Quick Scan for high-value cleanup targets: downloads, large personal files, regenerable caches, Xcode data, simulator data, and common dependency/build folders such as `node_modules`, `.build`, `Pods`, and `build`. A Deep Scan remains available for whole-disk scanning from `/`. Results are at least 100 MB by default, sorted from largest to smallest. The UI supports selecting items, revealing items in Finder, rescanning, and moving selected items to Trash after confirmation.

The app will not permanently delete files, clean system folders, or run automatic cleanup in the background.

## Architecture

Scanning lives in `SleepKeeperCore` as a platform-neutral `StorageScanner` that walks configured directories and returns a `StorageScanReport`. The app target owns macOS-specific actions such as revealing files in Finder and moving files to Trash through `NSWorkspace`.

`SleepKeeperModel` owns scan state, selected file IDs, confirmation state, and user-visible errors. `ContentView` composes a storage panel into the existing main window; the menu bar remains focused on awake controls and opening the main window.

## Behavior

- Default scan mode: Quick Scan.
- Advanced scan mode: Deep Scan from `/`.
- Minimum displayed size: 100 MB.
- Result ordering: largest first.
- Result cap: 200 items.
- Scanner skips packages and inaccessible items.
- Quick Scan can return both files and folders.
- Scan errors are counted and displayed without stopping the whole scan.
- Trash action is available only when at least one listed item is selected.
- Before trashing, a confirmation alert shows item count and total selected size.
- After trashing, the app removes trashed items from the list, clears their selection, and reports failures through the existing error alert path.

## Testing

Core tests cover threshold filtering, size ordering, result limits, quick scan folder classification, and resilience when a scan location is missing. App-level behavior is verified by building the executable because Trash and Finder actions depend on AppKit.
