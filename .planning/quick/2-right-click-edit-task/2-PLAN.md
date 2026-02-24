---
phase: quick
plan: 2
type: execute
wave: 1
depends_on: []
files_modified:
  - QuickTask/Sources/Store/TaskStore.swift
  - QuickTask/Sources/Views/TaskRowView.swift
autonomous: true
requirements: []

must_haves:
  truths:
    - "User can right-click a task row and see an Edit option in the context menu"
    - "Selecting Edit replaces the task title text with an editable TextField containing the current title"
    - "Pressing Return commits the edit and the title updates"
    - "Clicking away (focus loss) commits the edit and the title updates"
    - "Empty or whitespace-only edits are rejected and the original title is restored"
    - "The edited title persists across app restarts"
  artifacts:
    - path: "QuickTask/Sources/Store/TaskStore.swift"
      provides: "rename mutation"
      contains: "func rename"
    - path: "QuickTask/Sources/Views/TaskRowView.swift"
      provides: "Inline editing with context menu trigger"
      contains: "contextMenu"
  key_links:
    - from: "TaskRowView.swift"
      to: "TaskStore.rename"
      via: "store.rename(task, to: editText)"
      pattern: "store\\.rename"
---

<objective>
Add inline task title editing triggered by a right-click context menu "Edit" item on each task row.

Purpose: Users need to fix typos or update task titles without delete-and-recreate friction.
Output: Updated TaskStore with rename mutation, updated TaskRowView with context menu and inline editing.
</objective>

<execution_context>
@/home/rob/.claude/get-shit-done/workflows/execute-plan.md
@/home/rob/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@QuickTask/Sources/Store/TaskStore.swift
@QuickTask/Sources/Views/TaskRowView.swift
@QuickTask/Sources/Views/TaskListView.swift
@QuickTask/Sources/Model/Task.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add rename mutation to TaskStore</name>
  <files>QuickTask/Sources/Store/TaskStore.swift</files>
  <action>
Add a `rename(_ task: Task, to newTitle: String)` method to TaskStore in the `// MARK: - Mutations` section, after the existing `delete` method.

Implementation:
1. Guard that `newTitle.trimmingCharacters(in: .whitespaces)` is not empty — if empty, return without changes (preserves original title).
2. Find the task index via `tasks.firstIndex(where: { $0.id == task.id })` — guard-let, return if not found.
3. Set `tasks[index].title = newTitle.trimmingCharacters(in: .whitespaces)` (trim whitespace from the committed title).
4. Call `persist()`.

Add a doc comment matching the existing style:
```swift
/// Renames the given task. Silently ignores empty/whitespace-only titles to preserve the existing name.
```

Do NOT modify any existing methods. This is purely additive.
  </action>
  <verify>Build the project: `cd /home/rob/projects/todo-app && swift build 2>&1`. Must compile with zero errors.</verify>
  <done>TaskStore has a `rename(_ task: Task, to newTitle: String)` method that validates non-empty input, updates the title, and persists.</done>
</task>

<task type="auto">
  <name>Task 2: Add context menu and inline editing to TaskRowView</name>
  <files>QuickTask/Sources/Views/TaskRowView.swift</files>
  <action>
Modify TaskRowView to support inline title editing triggered by a right-click context menu.

**State additions** — add three properties inside the struct, before `body`:
```swift
@State private var isEditing = false
@State private var editText = ""
@FocusState private var isTextFieldFocused: Bool
```

**Replace the static title Text with a conditional view.** Inside the Toggle label (where `Text(task.title)` currently is), replace with:

```swift
if isEditing {
    TextField("Task title", text: $editText)
        .focused($isTextFieldFocused)
        .onSubmit { commitEdit() }
        .onChange(of: isTextFieldFocused) { _, focused in
            if !focused { commitEdit() }
        }
        .textFieldStyle(.plain)
} else {
    Text(task.title)
        .strikethrough(task.isCompleted)
}
```

Note: the `.strikethrough` modifier moves inside the `else` branch since it only applies to the display Text, not the editing TextField.

**Add a `.contextMenu` modifier** on the outer HStack (after `.animation`):
```swift
.contextMenu {
    Button("Edit") {
        beginEdit()
    }
}
```

**Add two private helper methods** inside the struct:

```swift
private func beginEdit() {
    editText = task.title
    isEditing = true
    // Delay focus assignment to next run loop so TextField is mounted
    DispatchQueue.main.async {
        isTextFieldFocused = true
    }
}

private func commitEdit() {
    guard isEditing else { return }
    isEditing = false
    isTextFieldFocused = false
    let trimmed = editText.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty && trimmed != task.title {
        store.rename(task, to: trimmed)
    }
}
```

Key behaviors:
- `beginEdit()` seeds `editText` with the current title, sets `isEditing = true`, then focuses the TextField on the next run loop (TextField must be in the view hierarchy before it can receive focus).
- `commitEdit()` guards against double-commit (both onSubmit and focus loss can fire). It checks the trimmed text is non-empty and actually changed before calling `store.rename`. If empty or unchanged, the original title is preserved by simply exiting edit mode.
- The Toggle wrapping is preserved — the conditional view replaces only the label content.

Do NOT add Delete or other items to the context menu — keep it minimal with just "Edit" for now.
Do NOT change the drag handle, checkbox, delete button, or opacity animation.
  </action>
  <verify>Build the project: `cd /home/rob/projects/todo-app && swift build 2>&1`. Must compile with zero errors. Manually verify: right-click a task row, select Edit, type a new title, press Return — title updates. Click away from a focused TextField — edit commits. Try submitting an empty edit — original title preserved.</verify>
  <done>Right-clicking a task row shows a context menu with "Edit". Selecting it swaps the title for an editable TextField. Return or focus loss commits the edit. Empty edits are rejected. The rename persists to disk.</done>
</task>

</tasks>

<verification>
1. `swift build` compiles without errors
2. Launch app, add a task, right-click it — context menu appears with "Edit" item
3. Click "Edit" — title becomes an editable TextField with current text, cursor focused
4. Type a new title, press Return — title updates, TextField disappears, new title shown
5. Edit another task, click somewhere else (lose focus) — edit commits
6. Edit a task, clear the text, press Return — original title preserved (no empty tasks)
7. Edit a task, quit and relaunch — edited title persists
8. Existing features unaffected: checkbox toggle, delete, drag reorder, bulk clear
</verification>

<success_criteria>
- Context menu with "Edit" appears on right-click of any task row
- Inline TextField replaces title text during editing
- Edit commits on Return key and on focus loss
- Empty/whitespace edits are rejected (original title kept)
- Edited titles persist across app restarts
- No regressions to existing task row behavior
</success_criteria>

<output>
After completion, create `.planning/quick/2-right-click-edit-task/2-SUMMARY.md`
</output>
