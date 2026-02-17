# Architecture Research

**Domain:** macOS menu bar app with floating panel, global hotkeys, local persistence
**Researched:** 2026-02-17
**Confidence:** MEDIUM-HIGH (AppKit/SwiftUI patterns well-documented; specific component composition verified via multiple sources)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         App Entry Point                              │
│   @main QuickTaskApp: App                                            │
│   Scene: MenuBarExtra  (or NSStatusItem + AppDelegate)               │
│   Info.plist: LSUIElement = YES  (no Dock icon)                      │
├─────────────────────────────────────────────────────────────────────┤
│                     System Integration Layer                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │  NSStatusItem /  │  │  HotkeyService   │  │  AppDelegate /   │   │
│  │  MenuBarExtra    │  │  (global monitor)│  │  AppLifecycle    │   │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘  │
│           │ click                │ hotkey fired          │ lifecycle  │
├───────────┴──────────────────────┴──────────────────────┴───────────┤
│                        Panel Layer                                   │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │  FloatingPanel (NSPanel subclass)                             │   │
│  │   - .nonactivatingPanel (no focus steal)                      │   │
│  │   - .floatingWindowLevel (stays on top)                       │   │
│  │   - .fullScreenAuxiliary (works in fullscreen spaces)         │   │
│  │   - NSHostingView<ContentView> bridging AppKit → SwiftUI      │   │
│  └───────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                        UI / View Layer (SwiftUI)                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │  TaskInputView   │  │  TaskListView    │  │  TaskRowView     │   │
│  │  (text field,    │  │  (scrollable     │  │  (checkbox,      │   │
│  │   quick add)     │  │   checklist)     │  │   fade on done)  │   │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘  │
│           │                     │                       │            │
├───────────┴─────────────────────┴───────────────────────┴───────────┤
│                     ViewModel / State Layer                          │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │  TaskStore: ObservableObject                                  │   │
│  │   @Published var tasks: [Task]                                │   │
│  │   func add(_:)  toggle(_:)  delete(_:)  load()  save()       │   │
│  └────────────────────────────┬──────────────────────────────────┘  │
│                                │                                     │
├────────────────────────────────┴────────────────────────────────────┤
│                       Data / Persistence Layer                       │
│  ┌──────────────────────────┐  ┌──────────────────────────────────┐  │
│  │  TaskRepository          │  │  FileStore                       │  │
│  │  (CRUD operations,       │  │  (Codable → JSON                 │  │
│  │   business logic)        │  │   ~/Library/Application Support/ │  │
│  │                          │  │   QuickTask/tasks.json)          │  │
│  └──────────────────────────┘  └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| MenuBarExtra / NSStatusItem | Owns the icon in the system menu bar; entry point to UI | `MenuBarExtra("QuickTask", systemImage: "checkmark.circle")` or `NSStatusBar.system.statusItem(withLength:)` |
| HotkeyService | Registers global keyboard shortcut; fires panel show/hide regardless of app focus | `NSEvent.addGlobalMonitorForEventsMatchingMask(.keyDown)` or `KeyboardShortcuts` SPM package |
| FloatingPanel | NSPanel subclass; controls window layering, focus behavior, and lifecycle | `NSPanel` with `.nonactivatingPanel`, `.floatingWindowLevel`, `isReleasedWhenClosed = false` |
| NSHostingView bridge | Embeds SwiftUI view tree inside AppKit panel | `NSHostingView<ContentView>(rootView: contentView)` |
| TaskInputView | Text field for instant task capture; submits on Return | `TextField` + `.onSubmit` |
| TaskListView | Scrollable checklist; owns list rendering and empty state | `List` or `ScrollView` + `ForEach` over `TaskStore.tasks` |
| TaskRowView | Single task row with checkbox, label, fade-on-complete animation | `HStack` + `Toggle`/`Button`, `.opacity` animation |
| TaskStore | Single source of truth for task state; publishes changes to views | `class TaskStore: ObservableObject` with `@Published var tasks: [Task]` |
| TaskRepository | Encapsulates CRUD logic; coordinates persistence calls | Plain Swift class or struct; called by TaskStore |
| FileStore | Reads/writes JSON to disk using Codable | `JSONEncoder` / `JSONDecoder` + `FileManager` to `Application Support` |

## Recommended Project Structure

```
QuickTask/
├── App/
│   ├── QuickTaskApp.swift          # @main, MenuBarExtra scene declaration
│   ├── AppDelegate.swift           # Optional: lifecycle hooks, activation policy
│   └── Info.plist                  # LSUIElement = YES
├── Panel/
│   ├── FloatingPanel.swift         # NSPanel subclass
│   └── PanelManager.swift          # Show/hide logic, positioning near menu bar
├── Hotkey/
│   └── HotkeyService.swift         # Global hotkey registration and dispatch
├── Views/
│   ├── ContentView.swift           # Root SwiftUI view hosted in FloatingPanel
│   ├── TaskInputView.swift         # Quick-add text field
│   ├── TaskListView.swift          # Scrollable checklist
│   └── TaskRowView.swift           # Individual task row (checkbox + label)
├── ViewModel/
│   └── TaskStore.swift             # ObservableObject, @Published tasks, CRUD methods
├── Model/
│   └── Task.swift                  # Codable struct: id, title, isCompleted, createdAt
├── Persistence/
│   ├── TaskRepository.swift        # Business logic layer (add, toggle, delete)
│   └── FileStore.swift             # JSON encode/decode, disk I/O
└── Resources/
    └── Assets.xcassets             # Menu bar icon (template image)
```

### Structure Rationale

- **Panel/:** NSPanel code is AppKit-specific and changes independently of views; isolating it prevents AppKit from leaking into the SwiftUI tree.
- **Hotkey/:** Global event monitoring is a system-level concern with its own lifecycle (register on launch, deregister on quit); separation makes it easy to stub in tests.
- **ViewModel/:** One `TaskStore` acts as the single state container. Injected as `@StateObject` at the root so all views share the same instance.
- **Persistence/:** `FileStore` is deliberately kept dumb (no business logic), making it replaceable if the storage backend ever changes (e.g., SwiftData migration).
- **Model/:** `Task` is a plain `Codable` struct. Immutable value type keeps state reasoning simple.

## Architectural Patterns

### Pattern 1: NSPanel + NSHostingView (Floating Panel Bridge)

**What:** Subclass `NSPanel` to configure window behavior (floating, non-activating, fullscreen-compatible), then embed SwiftUI via `NSHostingView`. This is the standard way to achieve Spotlight-style floating UIs.
**When to use:** Any time you need a floating window that does not steal keyboard focus from other apps, and that works across all macOS spaces.
**Trade-offs:** Requires AppKit knowledge; adds a thin bridging layer. Pure SwiftUI `MenuBarExtra` with `.window` style is simpler but has less control over focus and layering behavior.

**Example:**
```swift
class FloatingPanel<Content: View>: NSPanel {
    init(contentView: Content) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior.insert(.fullScreenAuxiliary)
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.contentView = NSHostingView(rootView: contentView)
    }

    // Required so text fields inside SwiftUI can receive focus
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
```

### Pattern 2: ObservableObject TaskStore as Single Source of Truth

**What:** One `TaskStore` object is created at the app root (`@StateObject`) and passed down the view hierarchy. Views read `tasks` and call mutation methods. Mutations immediately write to disk via `FileStore`.
**When to use:** Simple local-only apps with one list. Keeps data flow unidirectional and eliminates sync bugs.
**Trade-offs:** Fine for hundreds of tasks; not designed for multi-list or sync scenarios.

**Example:**
```swift
@main
struct QuickTaskApp: App {
    @StateObject private var store = TaskStore()

    var body: some Scene {
        MenuBarExtra("QuickTask", systemImage: "checkmark.circle") {
            ContentView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

class TaskStore: ObservableObject {
    @Published var tasks: [Task] = []
    private let repository = TaskRepository()

    func add(title: String) {
        let task = Task(title: title)
        tasks.append(task)
        repository.save(tasks)
    }

    func toggle(_ task: Task) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isCompleted.toggle()
        repository.save(tasks)
    }
}
```

### Pattern 3: Global Hotkey via NSEvent Monitor

**What:** Register a global event monitor on launch that fires a closure when the hotkey combination is detected system-wide. The closure instructs `PanelManager` to show or toggle the floating panel.
**When to use:** Any time the panel must be accessible regardless of which app is in focus (the core value proposition of QuickTask).
**Trade-offs:** Requires `NSEvent.addGlobalMonitorForEventsMatchingMask` which works without Accessibility permissions for key-up events but may be sandboxing-constrained for key-down. Using `KeyboardShortcuts` SPM package (by sindresorhus) handles these edge cases and persists user-configured shortcuts to UserDefaults automatically.

**Example:**
```swift
// Using KeyboardShortcuts SPM package
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.option]))
}

class HotkeyService {
    func register() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) {
            PanelManager.shared.toggle()
        }
    }
}
```

## Data Flow

### Task Capture Flow (Happy Path)

```
User presses global hotkey (any app in foreground)
    ↓
HotkeyService fires closure
    ↓
PanelManager.shared.show()
    → FloatingPanel.orderFront(nil) + makeKey()
    → TaskInputView text field becomes first responder
    ↓
User types task title, presses Return
    ↓
TaskInputView calls store.add(title:)
    ↓
TaskStore appends Task to @Published tasks
    ↓
TaskRepository.save(tasks) called synchronously
    ↓
FileStore encodes [Task] → JSON → writes to disk
    ↓
SwiftUI re-renders TaskListView with new task visible
```

### Completion Toggle Flow

```
User taps checkbox on TaskRowView
    ↓
TaskRowView calls store.toggle(task)
    ↓
TaskStore mutates tasks[i].isCompleted = true
    ↓
FileStore writes updated JSON immediately
    ↓
SwiftUI re-renders: TaskRowView animates to faded/struck appearance
    (task remains in list — completed tasks are visible but de-emphasized)
```

### App Launch / Restore Flow

```
QuickTaskApp init → TaskStore init
    ↓
TaskRepository.load() → FileStore reads JSON from disk
    ↓
JSONDecoder decodes [Task]
    ↓
TaskStore.tasks = loaded tasks
    ↓
SwiftUI tree initialized with persisted state
```

### State Management

```
FileStore (disk)
    ↓ load on init
TaskStore (@Published tasks)
    ↓ (environmentObject)
Views (TaskListView, TaskInputView, TaskRowView)
    ↓ user actions
TaskStore mutation methods
    ↓ save after every mutation
FileStore (disk)
```

### Key Data Flows

1. **Hotkey → panel visibility:** HotkeyService → PanelManager (one-way command, no data returned)
2. **User input → persistence:** View → TaskStore → TaskRepository → FileStore (write-through, synchronous for small datasets)
3. **App launch → UI restore:** FileStore → TaskRepository → TaskStore → SwiftUI views (one-time load at startup)
4. **Completion → visual feedback:** TaskStore mutation → SwiftUI binding update → TaskRowView opacity/strikethrough animation

## Build Order (Dependencies)

Build these layers in order — each phase depends on the ones before it:

| Order | Component | Depends On | Notes |
|-------|-----------|------------|-------|
| 1 | `Task` model | Nothing | Pure Codable struct; foundation for everything |
| 2 | `FileStore` | Task model | Dumb I/O; testable in isolation |
| 3 | `TaskRepository` | FileStore, Task | Add/toggle/delete logic |
| 4 | `TaskStore` | TaskRepository | ObservableObject wrapping repository |
| 5 | `FloatingPanel` | Nothing (AppKit only) | Can be built in parallel with 1-4 |
| 6 | SwiftUI views | TaskStore | Views only bind to store; no direct persistence |
| 7 | `HotkeyService` | PanelManager | Global monitor wired last after panel exists |
| 8 | `MenuBarExtra` / App entry | All above | Wires everything together |

## Anti-Patterns

### Anti-Pattern 1: Using NSWindow Instead of NSPanel

**What people do:** Create a standard `NSWindow` and set its level to `.floating` to create a "floating" UI.
**Why it's wrong:** NSWindow steals key focus from the previously active app when shown. For QuickTask, this means the user's text editor or browser loses focus when the panel appears. NSPanel with `.nonactivatingPanel` avoids this entirely.
**Do this instead:** Subclass `NSPanel` and configure `isFloatingPanel = true` with the `.nonactivatingPanel` style mask.

### Anti-Pattern 2: Writing to Disk in View Body

**What people do:** Call `FileManager` or `JSONEncoder` directly inside SwiftUI view callbacks (`.onChange`, button actions).
**Why it's wrong:** Disk I/O in the view layer couples persistence to rendering, making the view untestable and the persistence logic scattered.
**Do this instead:** Views call `store.add()` / `store.toggle()`. TaskStore coordinates with TaskRepository. Views never touch FileStore directly.

### Anti-Pattern 3: Storing Tasks in UserDefaults

**What people do:** Serialize `[Task]` to `Data` and store in `UserDefaults` using `@AppStorage`.
**Why it's wrong:** UserDefaults is designed for small preference values. For a task list that can grow, the entire list is re-serialized on every write. JSON file in `Application Support` is the idiomatic approach for structured app data.
**Do this instead:** Use `FileManager` to write a JSON file to `~/Library/Application Support/QuickTask/tasks.json`. This also makes backup/export straightforward.

### Anti-Pattern 4: activateIgnoringOtherApps on Every Show

**What people do:** Call `NSApp.activate(ignoringOtherApps: true)` every time the panel is shown to ensure the text field can receive keyboard input.
**Why it's wrong:** This forcibly brings the entire app to the foreground, disrupting the user's current context. It also causes the previously active app to lose focus, breaking the "zero-friction" value proposition.
**Do this instead:** Configure `FloatingPanel.canBecomeKey = true` and call `panel.makeKey()` (not `makeKeyAndOrderFront`). This allows the panel's text field to receive input without stealing app activation.

### Anti-Pattern 5: Deleting Completed Tasks Immediately

**What people do:** Remove task from array when checkbox is ticked, for a "clean" list.
**Why it's wrong:** QuickTask's stated design is "completed tasks fade but persist." Immediate deletion removes the satisfaction of seeing completion and makes accidental check-offs unrecoverable.
**Do this instead:** Set `isCompleted = true` and use SwiftUI animations (`.opacity(task.isCompleted ? 0.4 : 1.0)`) to visually de-emphasize. Add explicit "clear completed" action if cleanup is needed.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| macOS System Menu Bar | `MenuBarExtra` scene (SwiftUI 13+) or `NSStatusBar.system.statusItem` (AppKit, wider compatibility) | `MenuBarExtra` requires macOS Ventura (13.0+); `NSStatusItem` works back to macOS 10.x |
| Global Event System | `NSEvent.addGlobalMonitorForEventsMatchingMask` or `KeyboardShortcuts` SPM package | KeyboardShortcuts preferred — handles sandboxing edge cases, persists user-defined shortcuts |
| macOS File System | `FileManager` + `JSONEncoder/JSONDecoder` to `Application Support` directory | Use `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| HotkeyService ↔ PanelManager | Direct method call (`PanelManager.shared.toggle()`) | Singleton pattern acceptable here; hotkey is a single global concern |
| Views ↔ TaskStore | SwiftUI `@EnvironmentObject` binding | Views never hold a reference to FileStore or TaskRepository |
| TaskStore ↔ TaskRepository | Synchronous method calls (`repository.save(tasks)`) | For this app scale, synchronous write is fine; no async overhead needed |
| TaskRepository ↔ FileStore | Synchronous read/write | Async warranted only if task count exceeds thousands; start synchronous |
| FloatingPanel ↔ SwiftUI Views | `NSHostingView<ContentView>` as `contentView` | One bridge point; SwiftUI owns everything inside the panel |

## Scaling Considerations

This is a single-user local app. Scaling concerns are primarily about list size, not concurrent users.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0–500 tasks | Synchronous JSON read/write, in-memory array — current architecture handles this trivially |
| 500–5,000 tasks | Add background queue for disk writes (`DispatchQueue.global(qos: .background)`); add search/filter in TaskStore; lazy list rendering with SwiftUI `List` (already lazy by default) |
| 5,000+ tasks | Migrate `FileStore` to SwiftData (`@Model` + `ModelContainer`); drop-in replacement for the persistence layer without touching views or TaskStore contract |

### Scaling Priorities

1. **First bottleneck:** Synchronous disk writes on every toggle. Prevention: background dispatch queue for saves, debounced write (e.g., 500ms coalesce).
2. **Second bottleneck:** SwiftUI re-rendering entire list on any change. Prevention: Use `List` (lazy) over `ScrollView+ForEach`; ensure `Task` is `Equatable` so SwiftUI can skip unchanged rows.

## Sources

- Cindori developer blog — Floating Panel implementation pattern: https://cindori.com/developer/floating-panel (MEDIUM confidence — well-maintained developer blog, pattern consistent with Apple docs)
- Markus Bodner — Spotlight-like NSPanel with SwiftUI: https://www.markusbodner.com/til/2021/02/08/create-a-spotlight/alfred-like-window-on-macos-with-swiftui/ (MEDIUM confidence)
- NilCoalescing — macOS menu bar utility in SwiftUI: https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ (MEDIUM confidence)
- sindresorhus/KeyboardShortcuts README — global hotkey architecture: https://github.com/sindresorhus/KeyboardShortcuts (HIGH confidence — official library documentation)
- Apple Developer Docs — NSPanel: https://developer.apple.com/documentation/appkit/nspanel (HIGH confidence)
- Apple Developer Docs — NSEvent monitoring: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html (HIGH confidence)
- Apple SwiftUI — MenuBarExtra (macOS Ventura+): https://developer.apple.com/documentation/SwiftUI/MenuBarExtra (HIGH confidence — official)
- Kyan — Modern macOS menu bar app with SwiftUI: https://kyan.com/insights/using-swift-swiftui-to-build-a-modern-macos-menu-bar-app (LOW confidence — agency blog)

---
*Architecture research for: macOS menu bar app with floating panel, global hotkeys, local persistence*
*Researched: 2026-02-17*
