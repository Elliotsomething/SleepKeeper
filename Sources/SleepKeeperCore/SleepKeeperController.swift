import Foundation

public final class SleepKeeperController {
    public static let defaultReason = "SleepKeeper is keeping background work alive."
    public static let displayAwakeReason = "SleepKeeper is keeping the display awake."

    private let provider: PowerAssertionProviding
    private var assertionID: UInt32?
    private var displayAssertionID: UInt32?

    public var isEnabled: Bool {
        assertionID != nil
    }

    public var isDisplayAwakeEnabled: Bool {
        displayAssertionID != nil
    }

    public init(provider: PowerAssertionProviding = IOKitPowerAssertionProvider()) {
        self.provider = provider
    }

    deinit {
        releaseAssertionIfNeeded()
        releaseDisplayAssertionIfNeeded()
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try createAssertionIfNeeded()
        } else {
            releaseAssertionIfNeeded()
        }
    }

    public func setDisplayAwakeEnabled(_ enabled: Bool) throws {
        if enabled {
            try createDisplayAssertionIfNeeded()
        } else {
            releaseDisplayAssertionIfNeeded()
        }
    }

    private func createAssertionIfNeeded() throws {
        guard assertionID == nil else { return }
        assertionID = try provider.createAssertion(kind: .idleSleep, reason: Self.defaultReason)
    }

    private func releaseAssertionIfNeeded() {
        guard let assertionID else { return }
        provider.releaseAssertion(id: assertionID)
        self.assertionID = nil
    }

    private func createDisplayAssertionIfNeeded() throws {
        guard displayAssertionID == nil else { return }
        displayAssertionID = try provider.createAssertion(kind: .displaySleep, reason: Self.displayAwakeReason)
    }

    private func releaseDisplayAssertionIfNeeded() {
        guard let displayAssertionID else { return }
        provider.releaseAssertion(id: displayAssertionID)
        self.displayAssertionID = nil
    }
}
