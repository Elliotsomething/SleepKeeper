import XCTest
@testable import SleepKeeperCore

final class SleepKeeperControllerTests: XCTestCase {
    func testEnablingCreatesOneAssertionUntilDisabled() throws {
        let provider = RecordingAssertionProvider()
        let controller = SleepKeeperController(provider: provider)

        try controller.setEnabled(true)
        try controller.setEnabled(true)

        XCTAssertTrue(controller.isEnabled)
        XCTAssertEqual(provider.createdReasons, ["SleepKeeper is keeping background work alive."])
        XCTAssertEqual(provider.releasedIDs, [])

        try controller.setEnabled(false)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(provider.releasedIDs, [42])
    }

    func testEnablingDisplayAwakeCreatesSeparateAssertionUntilDisabled() throws {
        let provider = RecordingAssertionProvider()
        let controller = SleepKeeperController(provider: provider)

        try controller.setDisplayAwakeEnabled(true)
        try controller.setDisplayAwakeEnabled(true)

        XCTAssertTrue(controller.isDisplayAwakeEnabled)
        XCTAssertEqual(provider.createdAssertions, [
            .init(kind: .displaySleep, reason: "SleepKeeper is keeping the display awake.")
        ])
        XCTAssertEqual(provider.releasedIDs, [])

        try controller.setDisplayAwakeEnabled(false)

        XCTAssertFalse(controller.isDisplayAwakeEnabled)
        XCTAssertEqual(provider.releasedIDs, [42])
    }

    func testBackgroundAndDisplayAssertionsCanBeControlledIndependently() throws {
        let provider = RecordingAssertionProvider()
        let controller = SleepKeeperController(provider: provider)

        try controller.setEnabled(true)
        try controller.setDisplayAwakeEnabled(true)
        try controller.setEnabled(false)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertTrue(controller.isDisplayAwakeEnabled)
        XCTAssertEqual(provider.createdAssertions.map(\.kind), [.idleSleep, .displaySleep])
        XCTAssertEqual(provider.releasedIDs, [42])

        try controller.setDisplayAwakeEnabled(false)

        XCTAssertEqual(provider.releasedIDs, [42, 43])
    }

    func testDisableWithoutAssertionIsANoOp() throws {
        let provider = RecordingAssertionProvider()
        let controller = SleepKeeperController(provider: provider)

        try controller.setEnabled(false)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(provider.createdReasons, [])
        XCTAssertEqual(provider.releasedIDs, [])
    }
}

private final class RecordingAssertionProvider: PowerAssertionProviding {
    var createdReasons: [String] = []
    var createdAssertions: [CreatedAssertion] = []
    var releasedIDs: [UInt32] = []
    private var nextID: UInt32 = 42

    func createAssertion(kind: PowerAssertionKind, reason: String) throws -> UInt32 {
        createdReasons.append(reason)
        createdAssertions.append(.init(kind: kind, reason: reason))
        defer { nextID += 1 }
        return nextID
    }

    func releaseAssertion(id: UInt32) {
        releasedIDs.append(id)
    }
}

private struct CreatedAssertion: Equatable {
    let kind: PowerAssertionKind
    let reason: String
}
