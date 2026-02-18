# Stack Research

**Domain:** macOS menu bar task capture app (floating panel, global hotkey, local persistence)
**Researched:** 2026-02-17 (v1.0) | Updated: 2026-02-18 (v1.1 additions)
**Confidence:** MEDIUM-HIGH (Apple framework facts: HIGH; third-party library versions: HIGH via GitHub; architectural recommendations: MEDIUM via multiple community sources)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.1 (Xcode 16.3) | Primary language | Swift 6 concurrency model eliminates data races at compile time; `@MainActor` isolation is especially important for UI-touching code in menu bar apps. Swift 6.1 shipped March 2025 with `nonisolated` improvements that reduce boilerplate in AppDelegate-style patterns. |
| SwiftUI | macOS 14+ API surface | UI framework for panel content | SwiftUI's declarative model is the right fit for a checklist view — `@Observable`, `List`, `Toggle`, animations all work well. Use SwiftUI for everything inside the floating panel. |
| AppKit (NSStatusItem) | macOS 14+ | Menu bar icon + panel anchor | MenuBarExtra (pure SwiftUI) has a critical limitation for this project: you cannot programmatically show/hide the window from a global hotkey. NSStatusItem remains the correct primitive for hotkey-triggered floating panels because you retain full control over when the window appears. |
| AppKit (NSPanel) | macOS 14+ | Floating panel window | NSPanel with `isFloatingPanel = true` and `level = .floating` is the correct window type for a Spotlight-style overlay — it stays above other windows, hides on app deactivation, and supports `hidesOnDeactivate`. Wrap SwiftUI content with `NSHostingController`. |
| Xcode | 16.3+ | IDE and build toolchain | Required for Swift 6.1 and latest macOS 14/15 SDK. SPM dependency management is first-class. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KeyboardShortcuts (sindresorhus) | 2.4.0 (Sep 2025) | User-configurable global hotkey | Use this for the global capture hotkey (e.g. Cmd+Shift+Space). Fully sandboxed and Mac App Store compatible. Ships with a SwiftUI `KeyboardShortcuts.Recorder` component. Stores shortcut in UserDefaults automatically. Wraps Carbon APIs correctly so you don't have to. |
| Defaults (sindresorhus) | 9.0.6 (Oct 2025) | Type-safe UserDefaults wrapper | Use for app preferences (window position, hotkey preference, show-completed toggle). Strongly typed, Codable-aware, SwiftUI property wrapper support. Notably better than raw `@AppStorage` for structured types. |

**No additional third-party libraries are needed.** The persistence story (tasks list) is handled by Swift's `Codable` + `FileManager` + JSON, not a database — see below.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16.3+ | Build, debug, SwiftUI Previews | Use SwiftUI Previews aggressively for the panel UI — they work with isolated preview data and save a huge amount of build-run cycles for UI work. |
| Swift Package Manager | Dependency management | Both KeyboardShortcuts and Defaults are SPM packages. Add via Xcode "Add Package Dependencies" dialog. No CocoaPods or Carthage needed. |
| Instruments (Time Profiler) | Performance | Not needed in MVP, but keep in mind for checklist rendering if task list grows large. |

---

## Persistence Strategy

This is a pure-Swift decision with no third-party library needed.

**Use: JSON file in Application Support via FileManager + Codable**

```swift
// Model
struct Task: Codable, Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
}

// Storage location
let url = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("QuickTask/tasks.json")
```

Why not UserDefaults for the task list: UserDefaults has a practical size limit (~4MB documented intent, OS may enforce differently) and is not designed for structured lists. JSON file in Application Support is the standard macOS pattern for local structured data that is not a database.

Why not SQLite/Core Data: Severe overkill for a checklist with no relational structure, no full-text search, no concurrent writes. Adds ~50% of the project's complexity for zero benefit at this scale.

Why not CloudKit: Explicitly out of scope per project brief. No cloud, no accounts.

---

## Project Setup

This is a macOS-only app with no web server, no npm, no package.json. All dependencies are Swift packages.

```
# Xcode project setup
1. File > New > Project > macOS > App
2. Set deployment target: macOS 14.0
3. In Info.plist, add: LSUIElement = YES (hides Dock icon — required for menu bar only app)
4. In Info.plist, add: NSAccessibilityUsageDescription (required for global hotkey entitlement)
5. Add entitlement: com.apple.security.input.monitoring (for global keyboard shortcuts)

# Add dependencies via Xcode SPM:
https://github.com/sindresorhus/KeyboardShortcuts  (Up to Next Major: 2.4.0)
https://github.com/sindresorhus/Defaults            (Up to Next Major: 9.0.6)
```

**No shell install steps** — SPM handles everything via Xcode's package resolution.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| NSStatusItem + NSPanel | MenuBarExtra (.window style) | Use MenuBarExtra only if you do NOT need programmatic show/hide from a global hotkey. MenuBarExtra window cannot be toggled from outside the SwiftUI scene — a fatal limitation for QuickTask's hotkey-first design. |
| NSPanel (floating) | NSPopover | NSPopover is acceptable but has a directional arrow and is harder to position precisely. NSPanel gives more control over position, size, and animation behavior for a Spotlight-style experience. |
| KeyboardShortcuts | HotKey (soffes) | Use HotKey only if you want a hardcoded shortcut with no user configuration UI. HotKey has no recorder component. For QuickTask, user-configurable is strongly preferred UX. |
| KeyboardShortcuts | CGEventTap (raw) | Only if App Store sandboxing is not needed. CGEventTap requires a broader accessibility entitlement and is harder to implement correctly. KeyboardShortcuts wraps Carbon APIs safely. |
| Defaults | @AppStorage | @AppStorage is fine for simple scalar values. Use @AppStorage for truly trivial preferences. Use Defaults when you need Codable types, centralized key definitions, or usage outside SwiftUI. |
| JSON + FileManager | Core Data | Core Data is warranted at 10K+ records, complex relationships, or fts queries. A checklist with <1000 tasks does not need it. |
| JSON + FileManager | SQLite (GRDB) | GRDB is excellent but is a third-party dependency for a problem that doesn't require SQL. Adds ~100KB binary overhead and a learning curve with no benefit at this scale. |
| macOS 14+ target | macOS 13+ target | macOS 13 is required for MenuBarExtra but since we use NSStatusItem, macOS 14 is the right floor — it gets `@Observable` (no Combine needed), significantly cleaner SwiftUI state management, and the user base on 13 is small and shrinking. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| MenuBarExtra with `.window` style as the primary approach | Cannot be programmatically toggled from a global hotkey registered outside the SwiftUI scene — the core interaction pattern of QuickTask. This is a known limitation reported to Apple (FB11984872). | NSStatusItem + NSPanel |
| NSPopover for the main panel | Has a triangular "tail" anchor, limited positioning control, and cannot float freely from the status item anchor point in all configurations. Feels less Spotlight-like. | NSPanel with `isFloatingPanel = true` |
| HotKey library | No UI for the user to configure their shortcut. Hardcoded shortcuts are a UX liability. | KeyboardShortcuts (sindresorhus) |
| Core Data | Massive complexity for a flat list of tasks. Setup alone is 200+ lines of boilerplate. Not worth it unless you add sync, CloudKit, or complex querying. | Swift Codable + JSON + FileManager |
| UserDefaults for task list storage | Not designed for structured data arrays. Debugging is harder (binary plist). Size limitations in edge cases. | JSON file in Application Support |
| Combine (reactive framework) | Unnecessary since macOS 14's `@Observable` macro covers all observation patterns needed in this app. | `@Observable` + SwiftUI's native state tools |
| Third-party UI frameworks (SnapKit, Texture, etc.) | AppKit + SwiftUI covers everything needed. Adding layout frameworks for a small floating panel creates an unmaintainable mix. | SwiftUI + AppKit NSPanel directly |
| Electron / web tech | Explicitly out of scope. Native Swift/SwiftUI is the stated stack and it's the right call — native menu bar integration, proper sandboxing, App Store eligibility, ~5MB app size vs ~200MB Electron. | Swift + SwiftUI |

---

## Stack Patterns by Variant

**If targeting Mac App Store distribution:**
- Keep the `com.apple.security.input.monitoring` entitlement — KeyboardShortcuts handles the App Store approval flow for it
- Use App Sandbox entitlement (KeyboardShortcuts is sandbox-compatible)
- JSON storage in Application Support is sandbox-safe

**If targeting direct distribution (outside App Store):**
- Same stack applies
- Can optionally use notarization without sandbox, but sandbox is recommended anyway
- No stack changes needed

**If user wants iCloud sync later (post-MVP):**
- Swap JSON FileManager storage for CloudKit / NSUbiquitousKeyValueStore
- Defaults library already has iCloud sync support built in for preferences
- Core Data with CloudKit becomes relevant if sync + conflict resolution is needed

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| KeyboardShortcuts 2.4.0 | macOS 10.15+ | Works on the macOS 14 minimum target. App Store sandbox compatible. |
| Defaults 9.0.6 | macOS 11+ | Works on the macOS 14 minimum target. |
| Swift 6.1 | Xcode 16.3 | Swift 6 strict concurrency mode: expect to annotate `@MainActor` on AppDelegate and status item manager. |
| SwiftUI (macOS 14 APIs) | Xcode 15.2+ | `@Observable` macro requires macOS 14+. Targeting macOS 14 unlocks it without workarounds. |

---

## Sources

- GitHub: sindresorhus/KeyboardShortcuts — verified v2.4.0 released Sep 18, 2025, macOS 10.15+, App Store sandbox compatible
  https://github.com/sindresorhus/KeyboardShortcuts/releases
- GitHub: sindresorhus/Defaults — verified v9.0.6 released Oct 12, 2025, macOS 11+
  https://github.com/sindresorhus/Defaults/releases
- Swift.org blog: Swift 6.1 released March 31, 2025, ships with Xcode 16.3
  https://www.swift.org/blog/swift-6.1-released/
- Apple Xcode 16 release: Swift 6.0 shipped Sep 16, 2024 with Xcode 16
  https://developer.apple.com/documentation/xcode-release-notes/xcode-16-release-notes
- Cindori Developer Blog: floating panel implementation pattern — NSPanel with isFloatingPanel, level = .floating, hidesOnDeactivate
  https://cindori.com/developer/floating-panel
- Cindori Developer Blog: MenuBarExtra hands-on — MenuBarExtra window style limitation for programmatic toggle
  https://cindori.com/developer/hands-on-menu-bar
- nil coalescing blog: MenuBarExtra with SwiftUI utility app pattern
  https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/
- Apple Feedback: FB11984872 — MenuBarExtra cannot programmatically hide/show window (confirmed limitation, no fix as of research date)
  https://github.com/feedback-assistant/reports/issues/383
- WebSearch (MEDIUM confidence): macOS 14 as practical deployment floor for SwiftUI menu bar apps per community consensus, Jan 2026 developer report
- WebSearch (MEDIUM confidence): NSMenu preferred over NSPopover per Apple HIG, confirmed Jan 2026 developer experience report

---

*Stack research for: macOS menu bar task capture app (QuickTask)*
*Researched: 2026-02-17*

---
---

# v1.1 Stack Additions

**Scope:** Badge, drag-to-reorder, configurable hotkey recorder UI, bulk-clear
**Researched:** 2026-02-18
**Confidence:** HIGH for all four features (Apple built-in APIs verified; KeyboardShortcuts version verified on GitHub releases page)

## Summary

No new SPM dependencies are required. All four features use:
- AppKit built-ins (NSImage compositing for badge)
- SwiftUI built-ins (`.onMove`, `.moveDisabled`, `.onHover`, `.confirmationDialog`)
- KeyboardShortcuts library already in the project (bump version constraint from `exact: "1.10.0"` to `from: "2.4.0"`)

---

## Required Package.swift Change

The on-disk `Package.swift` pins `KeyboardShortcuts` at `exact: "1.10.0"`. The milestone targets 2.4.0. Update before implementing the recorder UI:

```swift
// Before
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.10.0"),

// After
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
```

The `KeyboardShortcuts.Name.init(_:default:)` call in `HotkeyService.swift` and `KeyboardShortcuts.onKeyUp(for:)` in `register()` are API-stable across 1.x → 2.x. No call-site changes needed in existing files.

---

## Feature: Task Count Badge on NSStatusItem

**API:** Pure AppKit — `NSImage.init(size:flipped:drawingHandler:)` + `NSBezierPath` + `NSAttributedString`
**New dependency:** None

The standard macOS pattern for numeric overlays on status bar icons is to composite a new `NSImage` from the base SF Symbol icon plus a colored circle and count string, then assign it to `statusItem.button?.image`.

Key rules:
- `isTemplate = true` must be `false` on the composed badge image. Template mode strips color; the red badge circle requires color rendering.
- Use `NSStatusItem.squareLength` (22pt). Badge circle occupies top-right ~10pt of the 22pt canvas.
- Observe `TaskStore.tasks` count changes via `@Observable` (already used in the project). Use `withObservationTracking` or add a computed property to `TaskStore` that returns `activeTasks` count and trigger badge update from there.
- When count is 0: revert to the original template icon (no badge).

```swift
// In AppDelegate — replace/extend updateStatusItemImage():
private func makeBadgeImage(count: Int) -> NSImage {
    let size = NSSize(width: 22, height: 22)
    return NSImage(size: size, flipped: false) { rect in
        // Base SF Symbol — draw at reduced opacity so badge is readable
        if let icon = NSImage(systemSymbolName: "checkmark.circle",
                              accessibilityDescription: nil) {
            icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.85)
        }
        // Badge circle: top-right corner, 10x10pt
        let badgeRect = NSRect(x: 12, y: 12, width: 10, height: 10)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        // Count label
        let label = count > 9 ? "9+" : "\(count)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = (label as NSString).size(withAttributes: attrs)
        let origin = NSPoint(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2
        )
        (label as NSString).draw(at: origin, withAttributes: attrs)
        return true
    }
}
```

How `AppDelegate` observes `TaskStore`: inject a reference to `TaskStore` into `AppDelegate` (same instance already passed to `PanelManager.shared.configure(with:)`). Add a method `refreshBadge()` called from `TaskStore` mutations, or use `withObservationTracking` on the main actor.

---

## Feature: Drag-to-Reorder with Drag Handle

**API:** SwiftUI `.onMove(perform:)` + `.moveDisabled(_:)` + `.onHover(perform:)` + `Array.move(fromOffsets:toOffset:)`
**New dependency:** None

The current `TaskListView` uses `List(store.tasks) { ... }`. This must change to `List { ForEach(...) { }.onMove(...) }` because `.onMove` only attaches to `ForEach`, not the bare `List` initializer.

On macOS, drag starts on mousedown (not long-press like iOS). Without confining the gesture to a drag handle, clicking the checkbox can be delayed or ambiguous. The fix: use `.moveDisabled(!isHoveringHandle)` on each row, toggled by an `.onHover` modifier on the drag handle icon.

`isHoveringHandle` is transient UI state — it lives in `TaskRowView`, NOT in the `Task` model.

```swift
// TaskListView.swift — replace List body
List {
    ForEach(store.tasks) { task in
        TaskRowView(task: task)
            .listRowSeparator(.hidden)
    }
    .onMove { indices, newOffset in
        store.move(fromOffsets: indices, toOffset: newOffset)
    }
}
.listStyle(.plain)

// TaskRowView.swift — add drag handle
@State private var isHoveringHandle = false

var body: some View {
    HStack {
        Image(systemName: "line.3.horizontal")
            .foregroundColor(.secondary)
            .onHover { isHoveringHandle = $0 }
        // ... existing checkbox Toggle and delete button ...
    }
    .moveDisabled(!isHoveringHandle)
}
```

`TaskStore` needs a new `move(fromOffsets:toOffset:)` method:

```swift
func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    tasks.move(fromOffsets: source, toOffset: destination)
    persist()
}
```

---

## Feature: Configurable Hotkey Recorder UI

**API:** `KeyboardShortcuts.Recorder` (SwiftUI view) — bundled with KeyboardShortcuts 2.4.0
**New dependency:** None (version bump only, see Package.swift section above)

`KeyboardShortcuts.Recorder` is a ready-made SwiftUI view that renders a native-style recorder control. Drop it directly into `SettingsView`'s existing `Form`. It handles:
- Displaying the current shortcut
- Recording a new one when clicked
- Detecting conflicts with system shortcuts and app shortcuts
- Persisting to `UserDefaults` automatically

```swift
// SettingsView.swift — add to Form
import KeyboardShortcuts

Section {
    KeyboardShortcuts.Recorder("Toggle panel:", name: .togglePanel)
} header: {
    Text("Hotkey")
}
```

The `KeyboardShortcuts.Name.togglePanel` is already defined in `HotkeyService.swift`. No additional setup needed.

SettingsView frame will need a height increase (currently 150pt) to accommodate the new section — approximately 220pt.

---

## Feature: Bulk-Clear Button with Confirmation

**API:** SwiftUI `.confirmationDialog(_, isPresented:, titleVisibility:)` + `Button(role: .destructive)`
**New dependency:** None

`.confirmationDialog` is the HIG-correct pattern for irreversible batch operations on macOS (available macOS 12+, confirmed on the macOS 14+ target). It automatically adds a Cancel button and applies `.destructive` styling to danger actions.

Placement: A "Clear Completed" button in a toolbar or footer of `ContentView`/`TaskListView`. Disable it when there are no completed tasks.

```swift
// In ContentView or TaskListView
@State private var showClearConfirmation = false

// Button placement — footer or toolbar
Button("Clear Completed") {
    showClearConfirmation = true
}
.disabled(store.tasks.filter(\.isCompleted).isEmpty)
.confirmationDialog(
    "Remove all completed tasks?",
    isPresented: $showClearConfirmation,
    titleVisibility: .visible
) {
    Button("Remove Completed", role: .destructive) {
        store.clearCompleted()
    }
}
```

`TaskStore` needs a new `clearCompleted()` method:

```swift
func clearCompleted() {
    tasks.removeAll(where: \.isCompleted)
    persist()
}
```

---

## v1.1 What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Third-party badge library (BadgeHub, swift-badge) | These target UIKit/iOS. No maintained macOS NSStatusItem badge library exists. AppKit NSImage compositing is ~20 lines. | Pure AppKit `NSImage` drawing |
| `NSStatusItem.button?.title` for badge | Replaces the SF Symbol icon with plain text. Cannot combine icon + count as a title string. | Composite `NSImage` (icon + badge circle + count) set as `button.image` |
| `NSStatusItem.view` (custom NSView) for badge | Deprecated macOS 10.14+. Apple docs warn against using it. Loses Retina handling and dark mode tinting. | `button.image` with composed NSImage |
| `image.isTemplate = true` on the badge image | Template rendering strips color. The red badge circle becomes invisible in template mode. | Set `isTemplate = false` on the composed badge image |
| `List(store.tasks) { }.onMove(...)` | `.onMove` on bare `List` initializer does not work — confirmed macOS behavior. Only `ForEach` inside `List` supports `.onMove`. | `List { ForEach(...) { }.onMove(...) }` |
| Full-row drag (no handle, no `.moveDisabled`) | On macOS, any mousedown on the row can trigger drag, blocking checkbox clicks and causing interaction ambiguity. | `.moveDisabled(!isHoveringHandle)` + `.onHover` on handle icon |
| `NSTableView` for drag reorder | Requires dropping out of SwiftUI entirely. The `.onHover` handle pattern solves the macOS drag-vs-click problem cleanly within SwiftUI. | SwiftUI `.onMove` + `.moveDisabled` + `.onHover` |
| `.alert` for bulk-clear confirmation | `.alert` supports destructive buttons but `.confirmationDialog` is the HIG-correct pattern for multi-action destructive operations on macOS. | `.confirmationDialog` |
| Undo manager for bulk-clear | `UndoManager` integration is disproportionate in scope for this milestone. Confirmation dialog is the right safeguard. | `.confirmationDialog` |
| `KeyboardShortcuts` v1.10.0 with Recorder UI | `exact: "1.10.0"` pin will block SPM from resolving 2.4.0. Both `Recorder` and `RecorderCocoa` exist in 1.x too, but 2.x adds macOS 15 Option-key fixes and `isEnabled()`/`removeHandler()` — use 2.4.0. | `from: "2.4.0"` in Package.swift |

---

## v1.1 Version Compatibility

| Technology | Version | Confidence | Notes |
|------------|---------|------------|-------|
| KeyboardShortcuts 2.4.0 | macOS 14+ target | HIGH | Verified on GitHub releases page: https://github.com/sindresorhus/KeyboardShortcuts/releases |
| `KeyboardShortcuts.Recorder` SwiftUI view | KeyboardShortcuts 2.4.0 | HIGH | Verified in source: `Sources/KeyboardShortcuts/Recorder.swift` |
| SwiftUI `.onMove` on `ForEach` | macOS 14+ | HIGH | Available since macOS 11. Confirmed macOS drag behavior (no long-press). |
| SwiftUI `.moveDisabled` | macOS 14+ | HIGH | Available since macOS 12. |
| SwiftUI `.onHover` | macOS 14+ | HIGH | macOS-only API, available since macOS 11. |
| SwiftUI `.confirmationDialog` | macOS 12+, targeting macOS 14+ | HIGH | Apple docs confirm macOS 12+ availability. |
| `NSImage.init(size:flipped:drawingHandler:)` | macOS 14+ | HIGH | AppKit API available since macOS 10.8. |
| `Array.move(fromOffsets:toOffset:)` | Swift 5.10 | HIGH | Standard library method, no version concern. |

---

## v1.1 Sources

- https://github.com/sindresorhus/KeyboardShortcuts/releases — 2.4.0 confirmed as current stable release (Sep 18, 2024)
- https://github.com/sindresorhus/KeyboardShortcuts/blob/main/Sources/KeyboardShortcuts/Recorder.swift — `Recorder` initializer signatures confirmed; `LabeledContent` Form integration confirmed
- https://github.com/sindresorhus/KeyboardShortcuts/blob/main/readme.md — `KeyboardShortcuts.Recorder("Toggle Unicorn Mode:", name:)` usage pattern in Form confirmed
- https://nilcoalescing.com/blog/ListReorderingWhileStillBeingAbleToEditTheListItems/ — `.moveDisabled` + `.onHover` drag handle pattern; macOS-specific interaction fix — MEDIUM confidence (independent blog, verified against Apple API docs)
- https://swiftdevjournal.com/moving-list-items-using-drag-and-drop-in-swiftui-mac-apps/ — `.onMove` requires `ForEach` inside `List` on macOS confirmed — MEDIUM confidence
- https://developer.apple.com/documentation/appkit/nsstatusitem — `button.image` API, deprecation of `.view` — HIGH confidence
- https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisiblity:actions:) — macOS 12+ availability confirmed — HIGH confidence

---

*v1.1 stack additions for: QuickTask badge, drag-reorder, configurable hotkey, bulk-clear*
*Researched: 2026-02-18*
