import Foundation

public struct PerformanceProcess: Equatable, Identifiable {
    public var id: Int32 { pid }

    public let pid: Int32
    public let name: String
    public let cpuPercentage: Double
    public let memoryPercentage: Double
    public let residentMemoryBytes: Int64

    public init(
        pid: Int32,
        name: String,
        cpuPercentage: Double,
        memoryPercentage: Double,
        residentMemoryBytes: Int64
    ) {
        self.pid = pid
        self.name = name
        self.cpuPercentage = cpuPercentage
        self.memoryPercentage = memoryPercentage
        self.residentMemoryBytes = residentMemoryBytes
    }
}

public struct PerformanceMetrics: Equatable {
    public let memoryFreePercentage: Double
    public let swapUsedBytes: Int64
    public let diskAvailableBytes: Int64
    public let diskTotalBytes: Int64
    public let loadAverage1Minute: Double
    public let processorCount: Int
    public let topProcesses: [PerformanceProcess]

    public init(
        memoryFreePercentage: Double,
        swapUsedBytes: Int64,
        diskAvailableBytes: Int64,
        diskTotalBytes: Int64,
        loadAverage1Minute: Double,
        processorCount: Int,
        topProcesses: [PerformanceProcess]
    ) {
        self.memoryFreePercentage = memoryFreePercentage
        self.swapUsedBytes = swapUsedBytes
        self.diskAvailableBytes = diskAvailableBytes
        self.diskTotalBytes = diskTotalBytes
        self.loadAverage1Minute = loadAverage1Minute
        self.processorCount = processorCount
        self.topProcesses = topProcesses
    }
}

public enum PerformanceConcern: String, Equatable {
    case memoryPressure
    case cpuPressure
    case hotProcess
    case lowStorage
}

public struct PerformanceDiagnosis: Equatable {
    public let title: String
    public let detail: String
    public let concerns: [PerformanceConcern]
    public let recommendations: [String]

    public init(
        title: String,
        detail: String,
        concerns: [PerformanceConcern],
        recommendations: [String]
    ) {
        self.title = title
        self.detail = detail
        self.concerns = concerns
        self.recommendations = recommendations
    }
}

public struct PerformanceAdvisor {
    private static let highSwapBytes: Int64 = 8 * 1024 * 1024 * 1024
    private static let lowMemoryFreePercentage = 15.0
    private static let lowDiskAvailableBytes: Int64 = 20 * 1024 * 1024 * 1024
    private static let lowDiskFreeRatio = 0.10
    private static let hotProcessCPUPercentage = 40.0

    public init() {}

    public func diagnose(_ metrics: PerformanceMetrics) -> PerformanceDiagnosis {
        var concerns: [PerformanceConcern] = []
        var recommendations: [String] = []

        let memoryPressure = metrics.memoryFreePercentage < Self.lowMemoryFreePercentage || metrics.swapUsedBytes >= Self.highSwapBytes
        if memoryPressure {
            concerns.append(.memoryPressure)
            recommendations.append("Quit memory-heavy apps or restart after saving work to clear heavy swap usage.")
        }

        let processorCount = max(metrics.processorCount, 1)
        let cpuPressure = metrics.loadAverage1Minute >= Double(processorCount) * 0.70
        if cpuPressure {
            concerns.append(.cpuPressure)
        }

        let hasHotProcess = metrics.topProcesses.contains { $0.cpuPercentage >= Self.hotProcessCPUPercentage }
        if hasHotProcess {
            concerns.append(.hotProcess)
        }

        if cpuPressure || hasHotProcess {
            recommendations.append("Open Activity Monitor and review the highest CPU processes before quitting anything.")
        }

        let diskFreeRatio = metrics.diskTotalBytes > 0 ? Double(metrics.diskAvailableBytes) / Double(metrics.diskTotalBytes) : 1
        let lowStorage = metrics.diskAvailableBytes < Self.lowDiskAvailableBytes || diskFreeRatio < Self.lowDiskFreeRatio
        if lowStorage {
            concerns.append(.lowStorage)
            recommendations.append("Run Storage Cleaner Quick Scan and move reviewed cache or build folders to Trash.")
        }

        if recommendations.isEmpty {
            recommendations.append("No immediate cleanup action is needed from these metrics.")
        }

        return PerformanceDiagnosis(
            title: title(for: concerns),
            detail: detail(for: metrics, concerns: concerns),
            concerns: concerns,
            recommendations: recommendations
        )
    }

    private func title(for concerns: [PerformanceConcern]) -> String {
        if concerns.contains(.memoryPressure) {
            return "Memory pressure likely"
        }
        if concerns.contains(.cpuPressure) || concerns.contains(.hotProcess) {
            return "CPU pressure likely"
        }
        if concerns.contains(.lowStorage) {
            return "Low storage may contribute"
        }
        return "No major pressure detected"
    }

    private func detail(for metrics: PerformanceMetrics, concerns: [PerformanceConcern]) -> String {
        if concerns.isEmpty {
            return "Memory, CPU load, and storage are within normal thresholds."
        }

        var parts: [String] = []
        if concerns.contains(.memoryPressure) {
            parts.append("Swap usage is high or free memory is low.")
        }
        if concerns.contains(.cpuPressure) || concerns.contains(.hotProcess) {
            parts.append("CPU load or a high-CPU process can make the system feel unresponsive.")
        }
        if concerns.contains(.lowStorage) {
            parts.append("Low free disk space can amplify memory swap and app launch delays.")
        }
        return parts.joined(separator: " ")
    }
}
