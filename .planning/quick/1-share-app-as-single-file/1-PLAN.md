---
phase: quick
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - QuickTask/create-dmg.sh
autonomous: true
requirements: [QUICK-1]

must_haves:
  truths:
    - "Running create-dmg.sh produces a single QuickTask.dmg file"
    - "The DMG contains QuickTask.app with the correct bundle structure"
    - "A recipient can mount the DMG and drag QuickTask.app to Applications"
  artifacts:
    - path: "QuickTask/create-dmg.sh"
      provides: "Single-file distribution script"
  key_links:
    - from: "QuickTask/create-dmg.sh"
      to: "QuickTask/build-app.sh"
      via: "calls build-app.sh first, then packages result"
      pattern: "build-app\\.sh"
---

<objective>
Create a script that packages the QuickTask.app into a single .dmg file for distribution.

Purpose: The user wants to share QuickTask with others as a single file they can download and run. A .dmg (disk image) is the standard macOS distribution format — recipients double-click to mount it, then drag the app to Applications.

Output: `QuickTask/create-dmg.sh` that builds the app and produces `QuickTask.dmg`
</objective>

<execution_context>
@/home/rob/.claude/get-shit-done/workflows/execute-plan.md
@/home/rob/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@QuickTask/build-app.sh
@QuickTask/Package.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create DMG packaging script</name>
  <files>QuickTask/create-dmg.sh</files>
  <action>
Create `QuickTask/create-dmg.sh` that does the following:

1. Run the existing `build-app.sh` to produce `QuickTask.app` (call it via `bash build-app.sh` since both scripts live in the same directory).

2. Copy the SPM-built resource bundle into the app bundle. SPM compiles resources into a `QuickTask_QuickTask.bundle` file at `.build/release/QuickTask_QuickTask.bundle`. Copy this into `QuickTask.app/Contents/Resources/` so the app can find its assets at runtime.

3. Create a temporary directory for DMG staging. Inside it:
   - Place `QuickTask.app`
   - Create a symbolic link to `/Applications` (so the user sees a drag-to-install target)

4. Use `hdiutil create` to build the DMG:
   ```
   hdiutil create -volname "QuickTask" -srcfolder "$STAGING_DIR" -ov -format UDZO "QuickTask.dmg"
   ```
   - UDZO = compressed, read-only (standard for distribution)
   - `-ov` = overwrite if exists

5. Clean up the staging directory.

6. Print the output path and file size.

The script should:
- Use `set -e` for fail-fast
- Run from the QuickTask/ directory (same as build-app.sh)
- Be executable (`chmod +x`)
- NOT require any third-party tools — `hdiutil` ships with macOS

Do NOT use `create-dmg` npm package or any Homebrew tools. `hdiutil` is built into macOS and is all that is needed.
  </action>
  <verify>
Run `cat QuickTask/create-dmg.sh` and confirm it:
- Calls build-app.sh
- Copies the resource bundle into the .app
- Creates staging dir with .app and /Applications symlink
- Calls hdiutil create with UDZO format
- Cleans up staging dir
- Is marked executable (check with `ls -la QuickTask/create-dmg.sh`)
  </verify>
  <done>
`QuickTask/create-dmg.sh` exists, is executable, and contains the complete DMG creation pipeline. The script uses only built-in macOS tools (hdiutil) and produces a single `QuickTask.dmg` file suitable for sharing.
  </done>
</task>

</tasks>

<verification>
- `QuickTask/create-dmg.sh` exists and is executable
- Script sources build-app.sh for the .app build step
- Script uses hdiutil (no third-party dependencies)
- Script includes resource bundle copy step
- Script creates Applications symlink in DMG for drag-to-install UX
</verification>

<success_criteria>
A single script exists that the user can run (`bash create-dmg.sh` from the QuickTask directory) to produce a `QuickTask.dmg` file. That DMG, when mounted, shows QuickTask.app alongside an Applications shortcut for standard macOS drag-to-install distribution.
</success_criteria>

<output>
After completion, create `.planning/quick/1-share-app-as-single-file/1-SUMMARY.md`
</output>
