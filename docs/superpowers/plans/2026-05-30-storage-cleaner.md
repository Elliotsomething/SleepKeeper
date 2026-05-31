# Storage Cleaner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a storage cleaner that quickly finds likely cleanup files and folders, keeps whole-disk scanning as an advanced option, and moves selected items to the macOS Trash after confirmation.

**Architecture:** Add test-covered scanning primitives to `SleepKeeperCore`, including Quick Scan categories and a Deep Scan scope. Keep AppKit-specific Finder and Trash operations in the app target, coordinated by `SleepKeeperModel` and rendered in `ContentView`.

**Tech Stack:** Swift 5.9, SwiftPM, XCTest, SwiftUI, AppKit `NSWorkspace`.

---

### Task 1: Core Storage Scanner

**Files:**
- Create: `Sources/SleepKeeperCore/StorageScanner.swift`
- Test: `Tests/SleepKeeperCoreTests/StorageScannerTests.swift`

- [ ] Write failing XCTest cases for threshold filtering, sorting, result limit, and missing scan locations.
- [ ] Run `swift test --filter StorageScannerTests` and confirm the tests fail because `StorageScanner` does not exist.
- [ ] Implement `StorageFile`, `StorageScanReport`, and `StorageScanner`.
- [ ] Run `swift test --filter StorageScannerTests` and confirm the tests pass.

### Task 2: App State And Trash Actions

**Files:**
- Modify: `Sources/SleepKeeper/App/SleepKeeperModel.swift`
- Create: `Sources/SleepKeeper/App/StorageTrashService.swift`

- [ ] Add scan state, selection state, formatted size helpers, and whole-disk scan locations to `SleepKeeperModel`.
- [ ] Add async Quick Scan and Deep Scan paths that run off the main actor and update published state on completion.
- [ ] Add Finder reveal and Trash movement methods using AppKit in the app target.
- [ ] Run `swift build` and fix compile errors.

### Task 3: Storage Cleaner UI

**Files:**
- Modify: `Sources/SleepKeeper/Views/ContentView.swift`

- [ ] Add a `StorageCleanerPanel` below launch settings.
- [ ] Render scan summary, Quick Scan and Deep Scan buttons, selectable rows, Finder reveal buttons, and Trash selected button.
- [ ] Add a confirmation alert for moving selected files to Trash.
- [ ] Run `swift build` and fix layout or compile errors.

### Task 4: Verification

**Files:**
- Modify: `README.md`

- [ ] Document the storage cleaner behavior and Trash-only deletion policy.
- [ ] Run `swift test`.
- [ ] Run `swift build`.
