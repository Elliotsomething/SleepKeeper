import XCTest
@testable import SleepKeeperCore

final class PerformanceAdvisorTests: XCTestCase {
    func testHighSwapIsDiagnosedAsMemoryPressure() {
        let metrics = PerformanceMetrics(
            memoryFreePercentage: 62,
            swapUsedBytes: 12 * 1024 * 1024 * 1024,
            diskAvailableBytes: 120 * 1024 * 1024 * 1024,
            diskTotalBytes: 512 * 1024 * 1024 * 1024,
            loadAverage1Minute: 3,
            processorCount: 10,
            topProcesses: []
        )

        let diagnosis = PerformanceAdvisor().diagnose(metrics)

        XCTAssertTrue(diagnosis.concerns.contains(.memoryPressure))
        XCTAssertEqual(diagnosis.title, "Memory pressure likely")
        XCTAssertTrue(diagnosis.recommendations.contains("Quit memory-heavy apps or restart after saving work to clear heavy swap usage."))
    }

    func testHighLoadAndHotProcessesAreDiagnosedAsCpuPressure() {
        let metrics = PerformanceMetrics(
            memoryFreePercentage: 40,
            swapUsedBytes: 1 * 1024 * 1024 * 1024,
            diskAvailableBytes: 120 * 1024 * 1024 * 1024,
            diskTotalBytes: 512 * 1024 * 1024 * 1024,
            loadAverage1Minute: 8.5,
            processorCount: 10,
            topProcesses: [
                .init(pid: 123, name: "Simulator", cpuPercentage: 76, memoryPercentage: 2, residentMemoryBytes: Int64(700 * 1024 * 1024))
            ]
        )

        let diagnosis = PerformanceAdvisor().diagnose(metrics)

        XCTAssertTrue(diagnosis.concerns.contains(.cpuPressure))
        XCTAssertTrue(diagnosis.concerns.contains(.hotProcess))
        XCTAssertEqual(diagnosis.title, "CPU pressure likely")
        XCTAssertTrue(diagnosis.recommendations.contains("Open Activity Monitor and review the highest CPU processes before quitting anything."))
    }

    func testLowDiskSpaceIsDiagnosedSeparately() {
        let metrics = PerformanceMetrics(
            memoryFreePercentage: 35,
            swapUsedBytes: 1 * 1024 * 1024 * 1024,
            diskAvailableBytes: 8 * 1024 * 1024 * 1024,
            diskTotalBytes: 512 * 1024 * 1024 * 1024,
            loadAverage1Minute: 2,
            processorCount: 10,
            topProcesses: []
        )

        let diagnosis = PerformanceAdvisor().diagnose(metrics)

        XCTAssertTrue(diagnosis.concerns.contains(.lowStorage))
        XCTAssertEqual(diagnosis.title, "Low storage may contribute")
        XCTAssertTrue(diagnosis.recommendations.contains("Run Storage Cleaner Quick Scan and move reviewed cache or build folders to Trash."))
    }

    func testHealthyMetricsReturnNoMajorIssue() {
        let metrics = PerformanceMetrics(
            memoryFreePercentage: 45,
            swapUsedBytes: 512 * 1024 * 1024,
            diskAvailableBytes: 160 * 1024 * 1024 * 1024,
            diskTotalBytes: 512 * 1024 * 1024 * 1024,
            loadAverage1Minute: 2,
            processorCount: 10,
            topProcesses: []
        )

        let diagnosis = PerformanceAdvisor().diagnose(metrics)

        XCTAssertEqual(diagnosis.concerns, [])
        XCTAssertEqual(diagnosis.title, "No major pressure detected")
    }
}
