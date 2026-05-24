import SwiftUI

struct ContentView: View {
    @ObservedObject var model: SleepKeeperModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HeaderView()

            StatusPanel(model: model)

            DisplayPanel(model: model)

            LaunchPanel(model: model)

            Spacer(minLength: 0)

            HStack {
                Text("Shortcut: Command Shift K")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    model.toggle()
                } label: {
                    Label(model.isEnabled ? "Turn Off" : "Turn On", systemImage: model.isEnabled ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(28)
        .alert("Power Assertion Failed", isPresented: errorBinding) {
            Button("OK") {
                model.clearError()
            }
        } message: {
            Text(model.lastError ?? "Unknown error")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.clearError() } }
        )
    }
}

private struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("SleepKeeper", systemImage: "bolt.circle.fill")
                .font(.largeTitle.weight(.semibold))

            Text("Keep background tasks running after the display turns off.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusPanel: View {
    @ObservedObject var model: SleepKeeperModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: model.isEnabled ? "checkmark.circle.fill" : "moon.zzz")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(model.isEnabled ? .green : .secondary)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.statusTitle)
                        .font(.title2.weight(.semibold))
                    Text(model.statusDetail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(isOn: Binding(
                get: { model.isEnabled },
                set: { model.setEnabled($0) }
            )) {
                Text("Enable background keep-awake")
                    .font(.headline)
            }
            .toggleStyle(.switch)
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DisplayPanel: View {
    @ObservedObject var model: SleepKeeperModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: model.displayAwakeEnabled ? "display" : "display.trianglebadge.exclamationmark")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(model.displayAwakeEnabled ? .green : .secondary)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text("Keep display on")
                    .font(.headline)
                Text("Prevent the screen from turning off while SleepKeeper is enabled.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(isOn: Binding(
                get: { model.displayAwakeEnabled },
                set: { model.setDisplayAwakeEnabled($0) }
            )) {
                EmptyView()
            }
            .toggleStyle(.switch)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LaunchPanel: View {
    @ObservedObject var model: SleepKeeperModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "power.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(model.launchAtLoginEnabled ? .green : .secondary)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text("Open at login")
                    .font(.headline)
                Text("Start SleepKeeper automatically when you sign in to macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.setLaunchAtLoginEnabled($0) }
            )) {
                EmptyView()
            }
            .toggleStyle(.switch)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
