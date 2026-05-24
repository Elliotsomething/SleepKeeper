import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: SleepKeeperModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: model.isEnabled ? "checkmark.circle.fill" : "moon.zzz")
                    .font(.title2)
                    .foregroundStyle(model.isEnabled ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.statusTitle)
                        .font(.headline)
                    Text(model.isEnabled ? "Background work stays alive" : "Mac may sleep normally")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: Binding(
                get: { model.isEnabled },
                set: { model.setEnabled($0) }
            )) {
                Text("Keep Awake")
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { model.displayAwakeEnabled },
                set: { model.setDisplayAwakeEnabled($0) }
            )) {
                Text("Keep Display On")
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.setLaunchAtLoginEnabled($0) }
            )) {
                Text("Open at Login")
            }
            .toggleStyle(.switch)

            Divider()

            HStack {
                Button(model.isEnabled ? "Turn Off" : "Turn On") {
                    model.toggle()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Spacer()

                Button("Open Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
            }

            HStack {
                Button("Refresh") {
                    model.refreshLaunchAtLoginStatus()
                }

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
