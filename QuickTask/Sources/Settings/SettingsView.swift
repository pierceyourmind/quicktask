import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        handleLaunchAtLoginChange(newValue)
                    }
                if SMAppService.mainApp.status == .requiresApproval {
                    Text("Approval required in System Settings > General > Login Items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, minHeight: 150)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func handleLaunchAtLoginChange(_ newValue: Bool) {
        #if DEBUG
        // SMAppService may fail in development builds without a proper app bundle identity.
        // In DEBUG mode, log a warning instead of calling register/unregister.
        print("[QuickTask] DEBUG: SMAppService.mainApp.register/unregister skipped in development build.")
        print("[QuickTask] DEBUG: Launch at login requires a properly bundled release build.")
        #else
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration failed — revert the toggle state
            launchAtLogin = !newValue
        }
        #endif
    }
}
