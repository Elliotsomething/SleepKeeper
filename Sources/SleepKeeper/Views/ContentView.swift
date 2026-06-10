import SleepKeeperCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: SleepKeeperModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HeaderView()

                StatusPanel(model: model)

                DisplayPanel(model: model)

                LaunchPanel(model: model)

                PerformanceOptimizerPanel(model: model)

                StorageCleanerPanel(model: model)

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
        }
        .alert("SleepKeeper Error", isPresented: errorBinding) {
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

private struct PerformanceOptimizerPanel: View {
    @ObservedObject var model: SleepKeeperModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "speedometer")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance optimizer")
                        .font(.headline)
                    Text(model.performanceTitleText)
                        .font(.callout.weight(.medium))
                    Text(model.performanceSummaryText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if model.isPerformanceAnalysisRunning {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    model.analyzePerformance()
                } label: {
                    Label("Analyze", systemImage: "waveform.path.ecg")
                }
                .disabled(model.isPerformanceAnalysisRunning)

                Button {
                    model.openActivityMonitor()
                } label: {
                    Label("Activity Monitor", systemImage: "app.badge")
                }
            }

            if !model.performanceMetricRows.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(model.performanceMetricRows, id: \.0) { row in
                        PerformanceMetricTile(title: row.0, value: row.1)
                    }
                }

                Text(model.performanceRecommendationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.performanceTopProcesses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Highest CPU processes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(model.performanceTopProcesses) { process in
                        PerformanceProcessRow(model: model, process: process)
                    }
                }
            }

            HStack {
                Text("Optimization actions are manual to avoid data loss.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    model.scanQuickStorage()
                } label: {
                    Label("Quick Clean", systemImage: "bolt.fill")
                }
                .disabled(model.isStorageScanRunning)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PerformanceMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit().weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PerformanceProcessRow: View {
    @ObservedObject var model: SleepKeeperModel
    let process: PerformanceProcess

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cpu")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("PID \(process.pid)  Memory \(model.formatByteCount(process.residentMemoryBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.1f%% CPU", process.cpuPercentage))
                .font(.callout.monospacedDigit())
                .foregroundStyle(process.cpuPercentage >= 40 ? .orange : .secondary)
                .frame(minWidth: 86, alignment: .trailing)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StorageCleanerPanel: View {
    @ObservedObject var model: SleepKeeperModel
    @State private var isConfirmingTrash = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage cleaner")
                        .font(.headline)
                    Text(model.storageResultsSummaryText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.storageSkippedItemCount > 0 {
                        Text("\(model.storageSkippedItemCount) items skipped because they could not be accessed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if model.isStorageScanRunning {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    model.scanQuickStorage()
                } label: {
                    Label("Quick Scan", systemImage: "bolt.fill")
                }
                .disabled(model.isStorageScanRunning)

                Button {
                    model.scanEntireDisk()
                } label: {
                    Label("Deep Scan", systemImage: "internaldrive")
                }
                .disabled(model.isStorageScanRunning)
            }

            if !model.storageFiles.isEmpty {
                VStack(spacing: 10) {
                    ForEach(model.storageFiles) { file in
                        StorageFileRow(model: model, file: file)
                    }
                }

                HStack {
                    Text(model.selectedStorageFileIDs.isEmpty ? "Select items to move them to Trash." : "Selected \(model.selectedStorageSummaryText).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(role: .destructive) {
                        isConfirmingTrash = true
                    } label: {
                        Label("Move to Trash", systemImage: "trash")
                    }
                    .disabled(model.selectedStorageFileIDs.isEmpty || model.isStorageScanRunning)
                }
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .alert("Move Items to Trash?", isPresented: $isConfirmingTrash) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    await model.moveSelectedStorageFilesToTrash()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Move \(model.selectedStorageSummaryText) to Trash. You can recover these files from the Trash.")
        }
    }
}

private struct StorageFileRow: View {
    @ObservedObject var model: SleepKeeperModel
    let file: StorageFile

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { model.isStorageFileSelected(file) },
                set: { model.setStorageFile(file, selected: $0) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)

            Image(systemName: file.kind == .folder ? "folder.fill" : "doc.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.url.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text(file.cleanupReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(file.url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Text(model.formatByteCount(file.byteCount))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 86, alignment: .trailing)

            Button {
                model.revealStorageFile(file)
            } label: {
                Label("Show", systemImage: "magnifyingglass")
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
