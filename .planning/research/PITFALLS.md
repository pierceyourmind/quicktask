# Pitfalls Research

**Domain:** macOS menu bar task/checklist app — v1.1 milestone (badge, drag-reorder, configurable hotkey, bulk-clear)
**Researched:** 2026-02-18
**Confidence:** MEDIUM-HIGH (claims cross-referenced against official Apple docs, Apple Developer Forums feedback reports, and practitioner blogs; macOS-specific SwiftUI behavior verified with multiple sources)

---

## Scope Note

This file covers pitfalls for **adding four specific v1.1 features to the existing QuickTask codebase**:
1. Task count badge on `NSStatusItem`
2. Drag-to-reorder in SwiftUI `List` inside `NSPanel`
3. Configurable hotkey recorder (`KeyboardShortcuts.Recorder`) in the Settings window
4. Bulk-clear that modifies the `@Observable TaskStore` array

The existing system is: AppKit `NSStatusItem` + `NSPanel` (.nonactivatingPanel) + SwiftUI content + `@Observable TaskStore` + JSON persistence. v1 pitfalls (NSPanel subclassing, hotkey permission model, etc.) are documented in prior research and are assumed solved.

---

## Critical Pitfalls

### Pitfall 1: Badge Composite Image Breaks `isTemplate` — Dark Mode Inversion

**What goes wrong:**
The existing `NSStatusItem` button uses `image.isTemplate = true`, which is correct for the plain checkmark icon — the system handles light/dark mode automatically. When a badge (colored red circle with a white number) is composited onto the image to create a badge count display, the badge color inverts in dark mode. A red badge in light mode becomes a dark smear or disappears entirely in dark mode because the template rendering pipeline applies tinting to the entire image.

**Why it happens:**
Template images are processed by macOS to render as a single-color silhouette (using only the alpha channel). Any color information in the composited badge is discarded. The compositing must happen *after* template processing, but the NSStatusItem button's `image` property applies template rendering before display — so pre-compositing the badge into the image loses all color fidelity.

**How to avoid:**
Two viable approaches:

Option A (recommended): Use `button.title` alongside `button.image` to display the count as text. Set `button.imagePosition = .imageLeft` and configure the title with an `NSAttributedString` for font sizing. The text renders as a standard menu bar text element and handles dark/light mode correctly. This avoids image compositing entirely.

Option B: Switch from `squareLength` to `variableLength` for the `NSStatusItem`, build a composite `NSImage` using `NSImage.init(size:flipped:drawingHandler:)` where you draw the SF Symbol *without* `isTemplate = true` and then draw the badge circle on top. Set `image.isTemplate = false` on the composite. Manually handle dark mode by reading `NSApplication.shared.effectiveAppearance` and choosing badge colors accordingly. This is more complex and must be re-drawn when the system appearance changes (observe `NSNotification.Name.NSWorkspaceAccessibilityDisplayOptionsDidChange` or `effectiveAppearanceDidChange`).

**Warning signs:**
- Badge looks correct in light mode but vanishes or turns black in dark mode
- Badge renders correctly in Xcode preview but breaks on a real device
- Badge appears to flicker when switching between light and dark modes

**Phase to address:**
Badge phase (v1.1 Phase 1) — choose the approach before writing any badge code; retrofitting the approach after implementing the image pipeline is a full rewrite of the badge logic.

---

### Pitfall 2: `NSStatusItem` Width Mismatch — `squareLength` Clips Badge Text

**What goes wrong:**
The existing `NSStatusItem` is initialized with `NSStatusItem.squareLength`, which fixes the item to a square (approximately 22x22 points). Adding a text label or compositing a larger badge image causes the content to be clipped — the badge number is not visible, or the item overflows into neighboring icons.

**Why it happens:**
`squareLength` creates a fixed-dimension item. It was appropriate for a single SF Symbol icon. A badge requires additional horizontal space. The length is set at initialization time; changing it later is possible via `statusItem.length = NSStatusItem.variableLength` but can cause a visible layout jump if done while the menu bar is visible.

**How to avoid:**
If using `button.title` for the badge count (Option A from Pitfall 1), change `NSStatusItem.squareLength` to `NSStatusItem.variableLength` in `AppDelegate.setupStatusItem()`. Then set `button.imagePosition = .imageLeft` and `button.title` to the count string. `variableLength` lets macOS size the item to fit. When the task count is zero, set `button.title = ""` so the item collapses back to icon-only width. The transition is seamless.

If keeping a composite image (Option B), pre-size the composite `NSImage` to include the badge area, and ensure the image's intrinsic size matches its intended display size by setting `image.size` explicitly.

**Warning signs:**
- Badge number is partially clipped on the right edge
- Menu bar icon width jumps when tasks are added or removed
- `button.title` is set but the item stays the same width as before

**Phase to address:**
Badge phase (v1.1 Phase 1) — the length must be chosen alongside the badge rendering strategy.

---

### Pitfall 3: Badge Not Updated on Main Thread — AppKit Threading Violation

**What goes wrong:**
The `TaskStore.tasks` array changes drive the badge update. If a store mutation fires from a background context (e.g., future async persistence refactor, or a Task that isn't dispatched to `@MainActor`), updating `statusItem.button?.title` or `statusItem.button?.image` from a non-main thread causes a runtime warning (`UIKit was called from a background thread`) or silent corruption. The badge shows stale data or the app logs thread-checker warnings.

**Why it happens:**
All `NSStatusItem.button` property mutations are AppKit calls and must occur on the main thread. The `@Observable` framework itself is thread-safe for observation tracking, but UI writes are not. The current codebase always mutates on the main thread (all mutations are synchronous), but future refactors adding `Task { }` or `async` without explicit `@MainActor` annotations can silently break this.

**How to avoid:**
Add `@MainActor` annotation to the badge update method. Since `AppDelegate` already runs on the main actor by convention (it is an `NSApplicationDelegate`), the badge update function is safe as long as it's called from store observation code that is also main-actor-bound. When observing `TaskStore.tasks` to drive the badge, use `withObservationTracking` on the main actor, or drive updates from a SwiftUI-layer publisher. Example pattern:

```swift
// In AppDelegate or a dedicated BadgeController, call this on task count change:
@MainActor
func updateBadge(count: Int) {
    guard let button = statusItem.button else { return }
    button.title = count > 0 ? "\(count)" : ""
}
```

**Warning signs:**
- Xcode thread sanitizer (TSan) reports data races in `NSStatusItem`
- Badge count lags by one update behind actual task count
- Console prints "must be used from main thread only" warnings

**Phase to address:**
Badge phase (v1.1 Phase 1) — enforce from the first line of badge code; do not add `@MainActor` as a remediation after races are observed.

---

### Pitfall 4: `onMove` Drag Gesture Conflicts with `TextField` Tap-to-Focus in `NSPanel`

**What goes wrong:**
Adding `.onMove()` to the SwiftUI `List` makes every row draggable, which SwiftUI implements by attaching a drag gesture recognizer to each row. This gesture recognizer intercepts taps, introducing a significant delay before a tapped `TextField` (or interactive element) receives focus. Users must tap and hold for ~0.5 seconds before the text cursor appears. On macOS inside an `NSPanel`, this delay is more noticeable because the panel already has a custom activation model.

**Why it happens:**
SwiftUI's `onMove` implementation uses a unified drag recognizer that must distinguish between a tap (intent: focus a field) and a drag (intent: reorder). The recognizer adds a delay before forwarding the tap to the underlying control. There is no SwiftUI API to restrict the drag recognizer to a sub-region of the row.

The existing `TaskRowView` contains a `Toggle` (checkbox) and a task title label — not currently a `TextField`. However, if `TaskRowView` gains any interactive control (e.g., inline rename), this delay becomes immediately user-visible.

**How to avoid:**
Do not apply `.onMove()` globally to all rows. Instead, use the conditional `moveDisabled()` + hover-triggered drag handle pattern:

```swift
ForEach($store.tasks) { $task in
    TaskRowView(task: task)
        .overlay(alignment: .trailing) {
            if isHovering(task.id) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
            }
        }
        .onHover { hovering in
            hoveredID = hovering ? task.id : nil
        }
        .moveDisabled(!isHovering(task.id))
}
.onMove { from, to in store.move(from: from, to: to) }
```

Only rows where the user is hovering over the drag handle region are movable. This prevents the drag gesture from delaying taps elsewhere.

**Warning signs:**
- Clicking a checkbox or interactive element requires a visible pause before it responds
- Users report "sluggish" click response after reorder is added
- The drag handle appears but tapping anywhere on the row triggers the delay

**Phase to address:**
Drag-reorder phase (v1.1 Phase 2) — use the drag handle pattern from the first implementation; do not ship the naive `.onMove()` and expect to add handles later.

---

### Pitfall 5: `.onMove` Crashes if the `List` Can Receive Cross-List Drops

**What goes wrong:**
With `.onMove()` active, if any drag source external to the list (system file drag, another list, even a drag from the dock in some configurations) drops onto the `TaskListView`, the app crashes with: `Fatal error: Attempting to insert row (destination: X) with no associated insert action`.

**Why it happens:**
SwiftUI's `.onMove()` implicitly enables `onDrop` for the list. When a drop it cannot handle arrives, SwiftUI tries to forward it to `.onInsert`. If no `.onInsert` handler exists, it crashes rather than silently rejecting the drop. This is a long-standing SwiftUI bug (reported 2021, still reproducible in 2024 per community reports).

The `NSPanel` environment is particularly susceptible because the panel floats above other apps, and users may accidentally drag files or text from other windows onto the panel.

**How to avoid:**
Add an empty `.onInsert` handler to the `ForEach` immediately whenever `.onMove()` is added:

```swift
ForEach(store.tasks) { task in
    TaskRowView(task: task)
}
.onMove { from, to in store.move(from: from, to: to) }
.onInsert(of: ["com.apple.SwiftUI.listReorder"]) { _, _ in
    // Intentionally empty — prevents crash on foreign drops
}
```

This provides a no-op handler that SwiftUI forwards to instead of crashing.

**Warning signs:**
- App crashes when dragging a file or text from another app onto the panel
- Crash only occurs when there are two or more items in the list
- Works fine in isolation but crashes when other drag sources are nearby

**Phase to address:**
Drag-reorder phase (v1.1 Phase 2) — add the `.onInsert` guard at the same time as `.onMove`; never ship one without the other.

---

### Pitfall 6: `TaskStore.move()` Must Use `Array.move(fromOffsets:toOffset:)` — Not Manual Index Arithmetic

**What goes wrong:**
A developer implementing `TaskStore.move()` manually swaps elements using index arithmetic (e.g., `tasks.swapAt(from, to)` or a remove-then-insert). SwiftUI's `onMove` callback provides an `IndexSet` (source indices) and `Int` (destination), which does not directly map to a single swap operation. Manual arithmetic produces wrong results for multi-element moves and off-by-one errors at the array boundaries. The task order appears to jump unpredictably.

**Why it happens:**
The `destination` integer in `onMove` uses the "target slot" convention (insert *before* this index after removals), which is not the same as the final index after mutation. Swift's standard library `Array.move(fromOffsets:toOffset:)` handles this correctly. It is easy to miss this method and write manual index logic.

**How to avoid:**
Use `Array.move(fromOffsets:toOffset:)` directly:

```swift
func move(from source: IndexSet, to destination: Int) {
    tasks.move(fromOffsets: source, toOffset: destination)
    persist()
}
```

This is a one-liner and is the canonical implementation. Do not rewrite it.

**Warning signs:**
- Moving a task to the bottom of the list places it second-to-last instead
- Moving multiple selected tasks at once produces wrong order
- Moving a task to position 0 crashes with an index out of bounds

**Phase to address:**
Drag-reorder phase (v1.1 Phase 2) — use `Array.move(fromOffsets:toOffset:)` from day one; do not write custom index arithmetic.

---

### Pitfall 7: `KeyboardShortcuts.Recorder` Does Not Respond in the `NSWindow`-Hosted Settings View

**What goes wrong:**
The `SettingsView` is hosted in a manually-created `NSWindow` via `NSHostingView` (not a SwiftUI `Settings` scene — the existing code does this correctly to work around `SettingsLink` failures). When `KeyboardShortcuts.Recorder` is placed inside this hosted view, clicking the recorder to start recording a new shortcut does nothing. The recorder appears but ignores mouse and keyboard input.

**Why it happens:**
`KeyboardShortcuts.Recorder` uses `NSViewRepresentable` wrapping `RecorderCocoa` (an `NSControl` subclass). For the recorder to receive input, its parent `NSWindow` must be key. The settings `NSWindow` is shown with `.regular` activation policy and `makeKeyAndOrderFront(nil)`, which should make it key. However, the `NSPanel` floating panel (`canBecomeKey = true`) can intercept key window status if it is visible when the settings window opens. The panel's `resignKey()` implementation immediately calls `PanelManager.shared.hide()`, but if the panel is hidden *after* the settings window becomes key, a timing race can leave the settings window in a non-key state.

**How to avoid:**
In `AppDelegate.openSettingsFromMenu()`, ensure the floating panel is explicitly hidden *before* the settings window is made key:

```swift
@objc private func openSettingsFromMenu() {
    PanelManager.shared.hide()          // Dismiss panel first
    // ... existing window creation / reuse code ...
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

This eliminates the race. The panel's `resignKey()` still fires but operates on an already-hidden panel (idempotent). The settings window then becomes key without competition.

Additionally: `KeyboardShortcuts.Recorder` does not support `.frame(width:height:)` resizing via SwiftUI modifiers (confirmed open GitHub issue #133). Do not attempt to resize it; design the settings form layout around its fixed intrinsic size (approximately 130pt wide).

**Warning signs:**
- Recorder field is visible but clicking it has no effect
- Recorder works after manually hiding the panel then opening Settings
- Recorder works when opened from a fresh launch but not after using the panel hotkey first

**Phase to address:**
Configurable hotkey phase (v1.1 Phase 3) — add the explicit `PanelManager.shared.hide()` call in the settings open handler before embedding the recorder; do not discover the race during testing.

---

### Pitfall 8: `KeyboardShortcuts.Recorder` Captures the Panel Toggle Hotkey as a New Shortcut

**What goes wrong:**
When the user opens the Settings window and clicks the recorder to start recording, then presses the current panel toggle hotkey (e.g., Ctrl+Option+Space), two things happen simultaneously: (1) the recorder captures the shortcut as the new value, and (2) `HotkeyService` fires and toggles the panel. The panel opens on top of the Settings window, the recorder receives no `keyUp` event because the panel is now key, and the shortcut is recorded as an empty or partial value.

**Why it happens:**
`KeyboardShortcuts.Recorder` begins listening for a key event when clicked. `HotkeyService` uses a global `CGEventTap` (via the `KeyboardShortcuts` library) that fires *regardless* of which window is key. Both handlers receive the same key event. The recorder's capture phase does not suppress global hotkey listeners.

**How to avoid:**
Temporarily pause the global hotkey registration while the recorder is active. `KeyboardShortcuts` provides `KeyboardShortcuts.disable(.togglePanel)` / `KeyboardShortcuts.enable(.togglePanel)` for exactly this purpose. Call `disable` when the recorder becomes active (use the `onChange` of the recorder's binding to detect recording state) and `enable` when it becomes inactive:

```swift
KeyboardShortcuts.Recorder("Toggle Panel", name: .togglePanel)
    .onChange(of: isRecording) { recording in
        if recording {
            KeyboardShortcuts.disable(.togglePanel)
        } else {
            KeyboardShortcuts.enable(.togglePanel)
        }
    }
```

Note: the `KeyboardShortcuts.Recorder` SwiftUI component does not natively expose an `isRecording` binding. Use `RecorderCocoa` directly via `NSViewRepresentable` if you need to observe recording state, or check the library's current API for `onRecordingChange` callbacks.

**Warning signs:**
- Pressing the existing hotkey while the recorder is focused triggers the panel instead of recording the shortcut
- Shortcut is recorded as empty after pressing the existing combination
- Settings window loses key status unexpectedly when recording

**Phase to address:**
Configurable hotkey phase (v1.1 Phase 3) — design the disable/enable flow as part of the recorder integration; do not discover the conflict during QA.

---

### Pitfall 9: Bulk-Clear Does Not Animate Row Removal — List Jumps

**What goes wrong:**
Calling `store.clearCompleted()` (which calls `tasks.removeAll { $0.isCompleted }`) removes all completed tasks at once. SwiftUI's `List` re-renders the full row set with no transition — completed rows disappear instantly. This looks like a bug and is visually jarring, especially with 5+ completed tasks.

**Why it happens:**
`@Observable` property changes trigger view updates synchronously. When `tasks` is mutated with `removeAll`, SwiftUI sees the new array all at once and does a full diff with no time to run per-row exit animations. `withAnimation { }` wrapping the mutation does *not* reliably trigger per-row animations for `List` items on macOS — this is a known SwiftUI/macOS `List` animation limitation documented in Apple Developer Forums.

**How to avoid:**
Use a two-step animated removal: first mark completed tasks as "pending removal" with a local state flag, animate them out (opacity to 0), then remove them from the store after the animation completes. Alternatively, wrap the mutation in `withAnimation(.default) { }` and explicitly set a `transition` on the rows — some macOS versions do respect `.transition(.opacity)` on List rows when wrapped in `withAnimation`.

The pragmatic path for v1.1: wrap in `withAnimation` and test on-device. If animation is correct, ship it. If it jumps, add the two-step approach. Do not over-engineer until the behavior is observed on a real macOS build.

Minimum viable implementation:
```swift
Button("Clear Completed") {
    withAnimation {
        store.clearCompleted()
    }
}
```

**Warning signs:**
- List rows vanish instantaneously without any fade when "Clear Completed" is tapped
- `withAnimation` has no visible effect on the removal
- The empty state (`ContentUnavailableView`) appears without a crossfade

**Phase to address:**
Bulk-clear phase (v1.1 Phase 4) — test animation on macOS before shipping; if `withAnimation` is insufficient, add the two-step removal.

---

### Pitfall 10: Bulk-Clear Without Confirmation Destroys Unfocused Completed Tasks

**What goes wrong:**
A "Clear Completed" button without a confirmation dialog is a destructive one-tap action. Users who have completed tasks they want to review before clearing (or who tapped the button accidentally) have no recourse. The action immediately modifies the JSON-persisted store with no undo.

**Why it happens:**
Single-action bulk deletes feel fast to implement and seem "clean" in a minimal app. The destructive consequence is not obvious until a user accidentally clears 15 tasks they had mentally queued for reference.

**How to avoid:**
Gate bulk-clear behind a `confirmationDialog` (SwiftUI native, macOS 12+):

```swift
.confirmationDialog(
    "Clear all completed tasks?",
    isPresented: $showingClearConfirmation,
    titleVisibility: .visible
) {
    Button("Clear \(completedCount) Completed", role: .destructive) {
        withAnimation { store.clearCompleted() }
    }
    Button("Cancel", role: .cancel) { }
}
```

This is one modal interaction with standard system styling and is the expected macOS pattern for destructive bulk actions.

**Warning signs:**
- "Clear Completed" button immediately clears tasks with no dialog
- No visual indication of how many tasks will be deleted
- No undo possible after clear

**Phase to address:**
Bulk-clear phase (v1.1 Phase 4) — include confirmation from the first implementation; do not add it as a polish step after feedback.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Apply `.onMove()` without drag handles | Simpler — one line | Tap-to-focus delay on every interactive row element; hard to remove later | Never — drag handles are required from day one |
| Use `squareLength` and composite badge into image | Reuses existing icon setup | Template rendering inverts badge color in dark mode; requires per-OS appearance observation | Never — switch to `variableLength` + `button.title` for badge text |
| Skip `.onInsert` empty handler alongside `.onMove` | One less line | Crashes when any external drag lands on the panel | Never — costs one line; prevents a crash |
| No confirmation on bulk-clear | Faster to implement | Users accidentally destroy completed task history | Never for v1.1; add dialog from the start |
| Skip disabling hotkey during recorder capture | No extra code | Current hotkey fires and opens panel during recorder interaction | Never — one `KeyboardShortcuts.disable()` call prevents this |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `NSStatusItem` badge + `@Observable TaskStore` | Observing `store.tasks.count` from AppKit (AppDelegate is not a SwiftUI view and does not auto-observe `@Observable`) | Use `NotificationCenter` or add a dedicated `taskCountDidChange` callback from `TaskStore` to `AppDelegate.updateBadge()`, or use `withObservationTracking` explicitly |
| `KeyboardShortcuts.Recorder` in `NSHostingView`-hosted `SettingsView` | Recorder appears but is unresponsive — settings window is not key | Call `PanelManager.shared.hide()` before making the settings window key; panel `resignKey()` may race with window becoming key |
| `.onMove` + `@Observable TaskStore` | `store.tasks` is not a `Binding<[Task]>` — `onMove` requires a `ForEach` bound to a mutable binding | Expose `tasks` as a `Binding` or use `$tasks` on `@Bindable` wrapper; alternatively drive `onMove` off a local `@State` copy and sync back to store |
| Bulk-clear animation + `ContentUnavailableView` overlay | Empty state overlay appears before removal animation completes, causing overlap flicker | Delay overlay appearance by 1 animation frame using `.animation(.default.delay(0.15), value: store.tasks.isEmpty)` |
| `KeyboardShortcuts` disable/enable around recorder | Disabling at recorder focus and re-enabling on dismiss only — misses the case where Settings window closes while recording | Observe `NSWindow.willCloseNotification` for the settings window and call `KeyboardShortcuts.enable(.togglePanel)` as a safety net |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Recompositing badge `NSImage` on every task count change | CPU spike on every `toggle()` / `add()` / `delete()` call, especially during rapid task entry | Cache the badge image per count value (0-99 is finite); only recomposite when count changes | Immediately visible with >5 task operations per second |
| `TaskStore.clearCompleted()` calling `persist()` once is sufficient | `persist()` called multiple times per clear (e.g., once per removed task if implemented with `forEach { delete($0) }`) | Implement `clearCompleted()` as a single `tasks.removeAll { }` + single `persist()` — not as repeated `delete()` calls | Any bulk-clear operation; scales with number of completed tasks |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Badge shows zero when there are no tasks (displays "0" in menu bar) | Cluttered, confusing — users expect no badge when nothing is pending | Only show badge when count > 0; set `button.title = ""` when count is 0 to collapse the item |
| Badge counts completed tasks alongside active tasks | Badge includes items the user already handled; feels inaccurate | Badge should count only *incomplete* (active) tasks: `store.tasks.filter { !$0.isCompleted }.count` |
| Drag handle is always visible (not hover-triggered) | Visual clutter; every row has a drag affordance at all times | Show drag handle only on row hover via `onHover` — standard macOS table row pattern |
| "Clear Completed" button is visible when there are no completed tasks | Confusing empty action; invites tapping a disabled or no-op button | Hide or disable the button when `store.tasks.filter { $0.isCompleted }.isEmpty` |
| Configurable hotkey resets to default when user clears the recorder field | User loses their custom shortcut; must re-enter it | Allow "no shortcut" as a valid state; do not auto-revert to default; let `KeyboardShortcuts` store nil shortcut |

---

## "Looks Done But Isn't" Checklist

- [ ] **Badge:** Shows correct count of *incomplete* tasks only — verify by completing all tasks and confirming badge disappears
- [ ] **Badge dark mode:** Badge is readable in both light and dark menu bar — test with Appearance set to Dark in System Settings
- [ ] **Badge threading:** Badge updates on main actor — verify with Xcode Thread Sanitizer enabled
- [ ] **Drag-reorder:** Tapping a checkbox immediately toggles it — no delay after drag-reorder is added
- [ ] **Drag-reorder crash guard:** Drag a file from Finder onto the panel while the task list is visible — no crash
- [ ] **Drag-reorder persistence:** Task order after reorder survives app quit + relaunch
- [ ] **KeyboardShortcuts.Recorder responsive:** Clicking the recorder field in Settings starts recording immediately — verified after opening Settings while panel was previously visible
- [ ] **Hotkey not stolen during recording:** Pressing current hotkey combination while recorder is active does not toggle the panel
- [ ] **Bulk-clear confirmation:** "Clear Completed" shows a confirmation dialog before destroying data
- [ ] **Bulk-clear count:** Confirmation dialog states how many tasks will be deleted
- [ ] **Bulk-clear animation:** Rows animate out rather than disappearing instantly (test on real macOS hardware)
- [ ] **Bulk-clear persistence:** After clear, relaunching the app does not bring back cleared tasks

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Badge composite breaks dark mode | LOW | Switch from image compositing to `button.title` text approach; 1-2 hours |
| `squareLength` clips badge | LOW | Change to `variableLength`; update image positioning; 30 minutes |
| `.onMove` without drag handles ships and causes UX complaints | MEDIUM | Add drag handle + `moveDisabled()` overlay to `TaskRowView`; requires testing on device |
| `.onInsert` missing, crash on external drop | LOW | Add one `.onInsert(of:perform:)` call; 5 minutes |
| Recorder unresponsive in Settings | LOW | Add `PanelManager.shared.hide()` before `makeKeyAndOrderFront`; 15 minutes |
| Hotkey fires during recorder capture | LOW | Add `KeyboardShortcuts.disable(.togglePanel)` wrapper; 30 minutes |
| Bulk-clear has no confirmation | LOW | Add `confirmationDialog` modifier; 30 minutes |
| Bulk-clear calls `persist()` N times instead of once | LOW | Refactor to `removeAll` + single `persist()`; 10 minutes |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Badge composite breaks `isTemplate` dark mode | v1.1 Phase 1: Badge | Toggle system appearance while app is running; badge remains readable |
| Badge clips with `squareLength` | v1.1 Phase 1: Badge | Add 10 tasks; confirm badge number is fully visible in menu bar |
| Badge updated off main thread | v1.1 Phase 1: Badge | Run with TSan enabled; no thread-checker warnings |
| `onMove` delays tap-to-focus | v1.1 Phase 2: Drag-reorder | Tap checkbox immediately after enabling reorder; response must be instant |
| Cross-list drop crash | v1.1 Phase 2: Drag-reorder | Drag a file from Finder onto the panel; no crash |
| Wrong `move()` index arithmetic | v1.1 Phase 2: Drag-reorder | Move tasks to top, bottom, and middle; verify correct final order |
| Recorder unresponsive in Settings | v1.1 Phase 3: Configurable hotkey | Open Settings immediately after using panel hotkey; recorder must be clickable |
| Hotkey stolen during recorder capture | v1.1 Phase 3: Configurable hotkey | Press current shortcut while recorder is active; panel must not open |
| Bulk-clear has no animation | v1.1 Phase 4: Bulk-clear | Clear 5+ completed tasks; rows must animate out |
| Bulk-clear has no confirmation | v1.1 Phase 4: Bulk-clear | Tap "Clear Completed"; confirmation dialog must appear before any deletion |

---

## Sources

- [SwiftUI List reordering with text field conflict — NilCoalescing](https://nilcoalescing.com/blog/ListReorderingWhileStillBeingAbleToEditTheListItems/) — onMove + hover drag handle pattern, `moveDisabled()` approach; MEDIUM confidence
- [FB7367473: SwiftUI onMove stops working with tap gesture on macOS (feedback-assistant/reports)](https://github.com/feedback-assistant/reports/issues/46) — gesture conflict confirmed open as of October 2024; MEDIUM confidence
- [SwiftUI onMove crash without onInsert (SmallDeskSoftware)](https://software.small-desk.com/en/swiftui-en/2021/03/28/swiftui-how-to-prevent-unexpected-crash-from-using-onmove-with-swiftui-list-foreach-investigation-memo/) — "Fatal error: Attempting to insert row" root cause and `.onInsert` guard; MEDIUM confidence
- [KeyboardShortcuts library README (sindresorhus/KeyboardShortcuts)](https://github.com/sindresorhus/KeyboardShortcuts) — Recorder SwiftUI integration, `disable()`/`enable()` API; HIGH confidence
- [KeyboardShortcuts Issue #133 — Recorder size in SwiftUI](https://github.com/sindresorhus/KeyboardShortcuts/issues/133) — `.frame()` sizing does not work on Recorder; enhancement open; MEDIUM confidence
- [NSStatusItem Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsstatusitem) — `squareLength`, `variableLength`, `button.title`, `button.image` API; HIGH confidence
- [NSImage.isTemplate Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsimage/istemplate) — template image rendering behavior; HIGH confidence
- [The Curious Case of NSPanel's Nonactivating Style Mask Flag (philz.blog)](https://philz.blog/nspanel-nonactivating-style-mask-flag/) — NSPanel key window timing behavior with style mask; MEDIUM confidence
- [SwiftUI confirmationDialog — Swift with Majid](https://swiftwithmajid.com/2021/07/28/confirmation-dialogs-in-swiftui/) — macOS 12+ `confirmationDialog` pattern for destructive bulk actions; MEDIUM confidence
- [Array.move(fromOffsets:toOffset:) — Swift Standard Library](https://developer.apple.com/documentation/swift/array/move(fromoffsets:tooffset:)) — canonical implementation for onMove callback; HIGH confidence

---
*Pitfalls research for: QuickTask v1.1 milestone — badge, drag-reorder, configurable hotkey, bulk-clear*
*Researched: 2026-02-18*
