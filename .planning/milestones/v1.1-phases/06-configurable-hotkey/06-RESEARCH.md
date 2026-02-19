# Phase 6: Configurable Hotkey - Research

**Researched:** 2026-02-18
**Domain:** macOS global hotkey customization — KeyboardShortcuts SPM package upgrade and Recorder UI integration
**Confidence:** HIGH

---

## Summary

Phase 6 adds a hotkey recorder to the existing Settings window so users can replace the default global shortcut (currently `Ctrl+Option+Space` in code, described as `Cmd+Shift+Space` in the phase brief — see Open Questions). The implementation has a single external dependency: the `KeyboardShortcuts` package by sindresorhus, already in use at v1.10.0 and bumped to `from: "2.4.0"` as a first-commit requirement.

The core technical work is straightforward: (1) update the SPM dependency pin, (2) drop `KeyboardShortcuts.Recorder(for: .togglePanel)` into the existing `SettingsView`, and (3) add a "Reset to Default" button that calls `KeyboardShortcuts.reset(.togglePanel)`. Immediate effect is automatic — the library's Carbon layer unregisters the old hotkey and registers the new one as soon as `UserDefaults` is updated by the `Recorder`, with no handler re-registration needed in app code.

The prior-decision warning about `onRecordingChange` is resolved: **this parameter does not exist**. The correct optional callback parameter on `Recorder` is `onChange: ((KeyboardShortcuts.Shortcut?) -> Void)?`. The `RecorderCocoa` fallback mentioned in prior decisions is not needed because `KeyboardShortcuts.Recorder` is a native SwiftUI view in v2.x and works directly in `SettingsView` without `NSViewRepresentable`.

**Primary recommendation:** Bump the dependency pin, add `KeyboardShortcuts.Recorder(for: .togglePanel)` to `SettingsView` alongside a `KeyboardShortcuts.reset(.togglePanel)` button. No HotkeyService changes are needed.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HOTK-01 | User can change the global hotkey via recorder in Settings | `KeyboardShortcuts.Recorder(for: .togglePanel)` dropped into `SettingsView` Form — the library handles recording, conflict detection, and UserDefaults persistence automatically |
| HOTK-02 | New hotkey takes effect immediately after recording | Verified: the library's Carbon layer auto-unregisters old + registers new when UserDefaults changes; `HotkeyService.onKeyUp(for:)` handler is preserved without re-registration |
| HOTK-03 | User can reset hotkey to default (Ctrl+Option+Space) | `KeyboardShortcuts.reset(.togglePanel)` restores the `default:` shortcut defined in `KeyboardShortcuts.Name.togglePanel`; a Button in Settings triggers this |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| KeyboardShortcuts | `from: "2.4.0"` | Global hotkey recording, storage, and activation | Already in project; contains `Recorder` SwiftUI view; handles Carbon/CGEventTap, conflict detection, UserDefaults persistence |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI (system) | macOS 14+ | Host `Recorder` in `SettingsView` Form | Already used; `Recorder` renders natively in Form/Section |
| UserDefaults (system) | — | `KeyboardShortcuts` stores shortcuts here automatically | No direct app usage needed; library manages key `"KeyboardShortcuts_togglePanel"` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `KeyboardShortcuts.Recorder` (SwiftUI) | `KeyboardShortcuts.RecorderCocoa` via `NSViewRepresentable` | Only needed if Recorder had a SwiftUI bug; it does not in v2.x — use the SwiftUI view directly |
| `KeyboardShortcuts.reset(.togglePanel)` | `KeyboardShortcuts.setShortcut(nil, for: .togglePanel)` | `setShortcut(nil)` removes the shortcut entirely (even overrides the default); `reset()` restores to the `default:` value — always prefer `reset()` for HOTK-03 |

**Installation:**
In `Package.swift`, change:
```swift
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.10.0"),
```
to:
```swift
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
```

---

## Architecture Patterns

### Recommended Project Structure

No new files or directories are needed. All changes are in existing files:

```
QuickTask/Sources/
├── Hotkey/
│   └── HotkeyService.swift      # No changes required
├── Settings/
│   └── SettingsView.swift       # Add Recorder + Reset Button
└── Package.swift                # Bump dependency pin (first commit)
```

### Pattern 1: Recorder in SwiftUI Form

**What:** Drop `KeyboardShortcuts.Recorder(for:)` into the existing `Form` in `SettingsView`. The recorder renders as a labeled field showing the current shortcut, and clicking it enters recording mode.

**When to use:** Always — this is the one-line integration for HOTK-01.

**Example:**
```swift
// Source: https://github.com/sindresorhus/KeyboardShortcuts (readme.md)
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                // Existing content...
                Toggle("Launch at login", isOn: $launchAtLogin)
            } header: {
                Text("General")
            }

            Section {
                KeyboardShortcuts.Recorder("Global Hotkey:", name: .togglePanel)
                Button("Reset to Default") {
                    KeyboardShortcuts.reset(.togglePanel)
                }
            } header: {
                Text("Keyboard Shortcut")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 250)  // Increase height for new section
    }
}
```

### Pattern 2: Reset to Default

**What:** `KeyboardShortcuts.reset(_:)` restores the shortcut to the `default:` value defined in the `KeyboardShortcuts.Name` extension. If the `Name` has no default, it clears the shortcut.

**When to use:** For HOTK-03. Call it from a Button in the same Settings section as the Recorder.

**Example:**
```swift
// Source: KeyboardShortcuts v2.4.0 source (KeyboardShortcuts.swift)
Button("Reset to Default") {
    KeyboardShortcuts.reset(.togglePanel)
}
```

The default is already encoded in `HotkeyService.swift`:
```swift
static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.control, .option]))
```

### Pattern 3: Immediate Effect — No Handler Re-registration Needed

**What:** The Carbon layer inside `KeyboardShortcuts` observes `UserDefaults` changes. When the `Recorder` saves a new shortcut, the library automatically unregisters the old `EventHotKeyRef` and registers a new one. The `onKeyUp(for:)` closure registered in `HotkeyService.register()` remains active.

**When to use:** Always — this is passive behavior. No code is needed. Do not add `KeyboardShortcuts.removeHandler(for:)` or call `HotkeyService.shared.register()` again.

**Why this matters:** The prior phase description requires "no restart" (HOTK-02). This is already satisfied by the library design without extra code.

### Anti-Patterns to Avoid

- **Using `setShortcut(nil, for: .togglePanel)` for reset:** This removes the shortcut entirely even when a `default:` value exists. `reset(.togglePanel)` is the correct API for HOTK-03.
- **Calling `removeAllHandlers()` then re-registering after shortcut change:** Unnecessary. The library handles Carbon re-registration internally. Calling `removeAllHandlers()` would break the hotkey until the next app launch.
- **Using `onChange:` on `Recorder` to re-register the handler:** Unnecessary for HOTK-02. Immediate effect is automatic. The `onChange:` callback is only needed if storing the shortcut outside of `UserDefaults` (not applicable here).
- **Setting a fixed `SettingsView` frame height that truncates the new section:** The existing frame is `height: 150`. A new "Keyboard Shortcut" section requires increasing this (estimate: 250).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Conflict detection | Custom check against system shortcuts | `KeyboardShortcuts.Recorder` (built-in) | Library shows user-friendly alert if shortcut is taken by system or app menu |
| UserDefaults persistence | Manual encode/decode of shortcut | `KeyboardShortcuts.Recorder` (built-in) | Library stores to `"KeyboardShortcuts_togglePanel"` key automatically |
| Carbon re-registration | `removeHandler` + `onKeyUp` on `onChange:` | Library internal (automatic) | Library observes UserDefaults and re-registers Carbon handler without app code |
| Visual shortcut display | Custom key-combination view | `KeyboardShortcuts.Recorder` (built-in) | Recorder renders the current shortcut as a standard macOS badge |

**Key insight:** The entire recording + persistence + activation cycle is handled by one line: `KeyboardShortcuts.Recorder(for: .togglePanel)`. The reset is one additional line. The planner should resist adding logic that the library already owns.

---

## Common Pitfalls

### Pitfall 1: Confusing `reset()` with `setShortcut(nil)`

**What goes wrong:** Using `setShortcut(nil, for: .togglePanel)` for the reset button clears the shortcut permanently, leaving the user with no hotkey at all rather than restoring the default.

**Why it happens:** Both APIs write to `UserDefaults`. `setShortcut(nil)` deliberately disables the shortcut even when a default exists (it stores a sentinel "disabled" value). `reset()` calls `setShortcut(name.defaultShortcut, for: name)` internally.

**How to avoid:** Always use `KeyboardShortcuts.reset(.togglePanel)` for HOTK-03.

**Warning signs:** After pressing reset, the Recorder shows empty/no shortcut instead of the default.

### Pitfall 2: The `onRecordingChange` Parameter Does Not Exist

**What goes wrong:** The prior decision asked to verify `onRecordingChange` — this is a fictional parameter. Using it causes a compile error.

**Why it happens:** The correct parameter is `onChange: ((KeyboardShortcuts.Shortcut?) -> Void)?`. It is optional (defaults to `nil`) and is not needed for this phase because `UserDefaults` storage and Carbon re-registration are automatic.

**How to avoid:** Use `KeyboardShortcuts.Recorder("Label", name: .togglePanel)` with no callback. Do not add `onRecordingChange:`.

### Pitfall 3: Frame Height Not Updated for New Settings Section

**What goes wrong:** Adding a new Form section to `SettingsView` without increasing the `.frame(width: 400, height: 150)` clips or misrenders the Settings window.

**Why it happens:** The existing window is sized for one section only. The AppDelegate creates the `NSWindow` with a fixed `contentRect` matching the `SettingsView` frame.

**How to avoid:** Update `SettingsView` frame height (estimate 250) and the `NSWindow` `contentRect` in `AppDelegate.openSettingsFromMenu()` to match.

### Pitfall 4: Applying `from: "2.4.0"` Without Resolving the Package Graph

**What goes wrong:** After editing `Package.swift`, Xcode or `swift build` may fail if the package cache still holds v1.10.0.

**Why it happens:** SPM caches resolved versions in `Package.resolved`. Changing from `exact:` to `from:` requires resolution.

**How to avoid:** After editing `Package.swift`, run `swift package resolve` (or use Xcode > File > Packages > Resolve Package Versions) before building.

---

## Code Examples

Verified patterns from official sources:

### Recorder Initializer Signatures (v2.x)

```swift
// Source: KeyboardShortcuts Recorder.swift (main branch, verified 2026-02-18)

// With text label (most common for Settings Form):
public init(
    _ title: LocalizedStringKey,
    name: KeyboardShortcuts.Name,
    onChange: ((KeyboardShortcuts.Shortcut?) -> Void)? = nil
)

// Without label (custom layout):
public init(
    for name: KeyboardShortcuts.Name,
    onChange: ((KeyboardShortcuts.Shortcut?) -> Void)? = nil
)

// With Binding (manual storage, NOT needed here):
public init(
    shortcut: Binding<KeyboardShortcuts.Shortcut?>,
    onChange: ((KeyboardShortcuts.Shortcut?) -> Void)? = nil
)
```

### Reset Shortcut to Default

```swift
// Source: KeyboardShortcuts.swift (main branch, verified 2026-02-18)
// reset() calls setShortcut(name.defaultShortcut, for: name) internally
KeyboardShortcuts.reset(.togglePanel)

// Variadic form (multiple shortcuts at once):
KeyboardShortcuts.reset(.togglePanel, .anotherShortcut)
```

### UserDefaults Storage Key (for debugging)

```swift
// Key format: "KeyboardShortcuts_" + name.rawValue
// For .togglePanel: "KeyboardShortcuts_togglePanel"
// Source: KeyboardShortcuts.swift (userDefaultsPrefix constant)
```

### Minimal SettingsView Integration

```swift
// Source: Derived from KeyboardShortcuts readme.md + existing SettingsView.swift
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                // ... existing SMAppService code ...
            } header: {
                Text("General")
            }

            Section {
                KeyboardShortcuts.Recorder("Toggle Panel:", name: .togglePanel)
                Button("Reset to Default") {
                    KeyboardShortcuts.reset(.togglePanel)
                }
            } header: {
                Text("Keyboard Shortcut")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 250)
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `exact: "1.10.0"` in Package.swift | `from: "2.4.0"` | Phase 6 first commit | Enables `removeHandler()`, `isEnabled()`, `resetAll()` APIs new in v2.x |
| `onRecordingChange:` (fictional) | `onChange:` (optional, nil by default) | Always was `onChange` — prior decision had a typo | No behavioral change; just use correct parameter name |
| Manual handler re-registration on shortcut change | None needed (automatic) | Library design from v1 | Simplifies app code; no `removeHandler` + `onKeyUp` cycle needed |

**Added in v2.4.0 (relevant):**
- `removeHandler(for: Name)` — removes a specific handler by name (not needed for this phase, but available if handler management is ever required)
- `isEnabled(for: Name) -> Bool` — queries handler state
- Fixed `RecorderCocoa` zero-size issues (relevant: the SwiftUI `Recorder` wraps this internally)

**Added in v2.2.0 (relevant):**
- `resetAll()` — resets all registered shortcut names to their defaults (not needed for this phase, but available)

---

## Open Questions

1. **Default shortcut discrepancy: Ctrl+Option+Space vs Cmd+Shift+Space**
   - What we know: `HotkeyService.swift` line 10 defines `default: .init(.space, modifiers: [.control, .option])` — that is `Ctrl+Option+Space`. The phase description and additional context say the default is "Cmd+Shift+Space".
   - What's unclear: Which is correct? The code is authoritative for what ships. The phase description may be stale or refer to an earlier design.
   - Recommendation: The planner should note the actual default from the code (`Ctrl+Option+Space`) as the canonical default. HOTK-03's reset button restores whatever `default:` is in the `Name` definition — no code change needed either way. If the user intended `Cmd+Shift+Space`, the `HotkeyService.swift` `default:` should be corrected, but that is out of scope for this phase.

2. **`Defaults` package is imported but unused**
   - What we know: `Package.swift` imports `Defaults` from `9.0.0` as a dependency; no `.swift` file in `Sources/` imports or uses it.
   - What's unclear: Is it a leftover from an earlier phase or planned for a future use?
   - Recommendation: Leave it untouched. It does not affect this phase.

3. **Settings window NSWindow contentRect vs SettingsView frame**
   - What we know: `AppDelegate.openSettingsFromMenu()` creates `NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 150), ...)` and `SettingsView` has `.frame(width: 400, height: 150)`. Both must grow to accommodate the new section.
   - What's unclear: Exact pixel height needed for the new "Keyboard Shortcut" section with `formStyle(.grouped)`.
   - Recommendation: Planner should include a task to update both the `SettingsView` frame and the `NSWindow` `contentRect` height. Start with `height: 250` and adjust during implementation if the Form clips.

---

## Sources

### Primary (HIGH confidence)

- `/sindresorhus/keyboardshortcuts` (Context7) — Recorder SwiftUI API, RecorderCocoa API, onKeyUp pattern
- `https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/main/Sources/KeyboardShortcuts/Recorder.swift` — Verified all `Recorder` initializer signatures including `onChange:` (not `onRecordingChange`)
- `https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/main/Sources/KeyboardShortcuts/KeyboardShortcuts.swift` — Verified `reset()`, `setShortcut()`, `removeHandler()`, `isEnabled()`, UserDefaults key format
- `https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/main/Package.swift` — Confirmed macOS 10.15+ minimum (QuickTask targets macOS 14, no compatibility issue)
- `/home/rob/projects/todo-app/QuickTask/Sources/Hotkey/HotkeyService.swift` — Existing default shortcut is `Ctrl+Option+Space`, not `Cmd+Shift+Space`
- `/home/rob/projects/todo-app/QuickTask/Sources/Settings/SettingsView.swift` — Existing Settings structure to integrate into
- `/home/rob/projects/todo-app/QuickTask/Package.swift` — Current dependency: `exact: "1.10.0"`

### Secondary (MEDIUM confidence)

- `https://github.com/sindresorhus/KeyboardShortcuts/releases` — v2.x release timeline and feature additions per version
- `https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/main/Sources/KeyboardShortcuts/CarbonKeyboardShortcuts.swift` — Confirmed automatic Carbon unregister/re-register on shortcut change (immediate effect without app code)

### Tertiary (LOW confidence)

- WebSearch results for migration/breaking changes v1→v2: No explicit migration guide found; the releases page shows only incremental additions, no documented breaking changes from v1 to v2.0.0. LOW risk for this project — the `Recorder` and `onKeyUp` APIs used in QuickTask are unchanged.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — API verified directly from source files on main branch
- Architecture: HIGH — Derived from existing project source + verified library API
- Pitfalls: HIGH (reset vs setShortcut, onChange parameter name) / MEDIUM (frame height estimate)

**Research date:** 2026-02-18
**Valid until:** 2026-04-18 (library is stable; APIs verified from source, not cached training data)
