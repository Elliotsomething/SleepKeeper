import AppKit
import Foundation
import SleepKeeperCore

final class SystemPerformanceService {
    func captureMetrics() async -> PerformanceMetrics {
        await Task.detached(priority: .userInitiated) {
            Self.captureMetricsSynchronously()
        }.value
    }

    func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app", isDirectory: true)
        NSWorkspace.shared.open(url)
    }

    private static func captureMetricsSynchronously() -> PerformanceMetrics {
        let memoryPressureOutput = run("/usr/bin/memory_pressure")
        let swapOutput = run("/usr/sbin/sysctl", arguments: ["vm.swapusage"])
        let uptimeOutput = run("/usr/bin/uptime")
        let psOutput = run("/bin/ps", arguments: ["-axo", "pid=,pcpu=,pmem=,rss=,comm="])
        let disk = diskCapacity()

        return PerformanceMetrics(
            memoryFreePercentage: parseMemoryFreePercentage(memoryPressureOutput) ?? 0,
            swapUsedBytes: parseSwapUsedBytes(swapOutput) ?? 0,
            diskAvailableBytes: disk.available,
            diskTotalBytes: disk.total,
            loadAverage1Minute: parseLoadAverage(uptimeOutput) ?? 0,
            processorCount: ProcessInfo.processInfo.activeProcessorCount,
            topProcesses: parseProcesses(psOutput)
        )
    }

    private static func run(_ launchPath: String, arguments: [String] = []) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parseMemoryFreePercentage(_ output: String) -> Double? {
        guard let range = output.range(of: #"System-wide memory free percentage:\s*([0-9.]+)%"#, options: .regularExpression) else {
            return nil
        }

        let match = String(output[range])
        let numberText = match
            .split(separator: " ")
            .last?
            .trimmingCharacters(in: CharacterSet(charactersIn: "%"))

        guard let numberText else { return nil }
        return Double(numberText)
    }

    private static func parseSwapUsedBytes(_ output: String) -> Int64? {
        guard let range = output.range(of: #"used = [0-9.]+[MGT]"#, options: .regularExpression) else {
            return nil
        }

        let match = String(output[range]).replacingOccurrences(of: "used = ", with: "")
        let unit = match.last.map(String.init) ?? "M"
        let numberText = String(match.dropLast())
        guard let value = Double(numberText) else { return nil }

        let multiplier: Double
        switch unit {
        case "T":
            multiplier = 1024 * 1024 * 1024 * 1024
        case "G":
            multiplier = 1024 * 1024 * 1024
        default:
            multiplier = 1024 * 1024
        }

        return Int64(value * multiplier)
    }

    private static func parseLoadAverage(_ output: String) -> Double? {
        guard let markerRange = output.range(of: "load averages:") else { return nil }
        let tail = output[markerRange.upperBound...]
        return tail
            .split(separator: " ")
            .first
            .flatMap { Double($0.trimmingCharacters(in: .punctuationCharacters)) }
    }

    private static func parseProcesses(_ output: String) -> [PerformanceProcess] {
        output
            .split(separator: "\n")
            .compactMap(parseProcessLine)
            .sorted { $0.cpuPercentage > $1.cpuPercentage }
            .prefix(8)
            .map { $0 }
    }

    private static func parseProcessLine(_ line: Substring) -> PerformanceProcess? {
        let parts = line.split(maxSplits: 4, omittingEmptySubsequences: true) { character in
            character == " " || character == "\t"
        }

        guard parts.count == 5,
              let pid = Int32(parts[0]),
              let cpu = Double(parts[1]),
              let memory = Double(parts[2]),
              let rssKilobytes = Int64(parts[3]) else {
            return nil
        }

        let name = String(parts[4]).split(separator: "/").last.map(String.init) ?? String(parts[4])
        return PerformanceProcess(
            pid: pid,
            name: name,
            cpuPercentage: cpu,
            memoryPercentage: memory,
            residentMemoryBytes: rssKilobytes * 1024
        )
    }

    private static func diskCapacity() -> (available: Int64, total: Int64) {
        let url = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ])

        return (
            Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0),
            Int64(values?.volumeTotalCapacity ?? 0)
        )
    }
}
