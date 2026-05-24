import Foundation
import IOKit.pwr_mgt

public final class IOKitPowerAssertionProvider: PowerAssertionProviding {
    public init() {}

    public func createAssertion(kind: PowerAssertionKind, reason: String) throws -> UInt32 {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            assertionType(for: kind),
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw PowerAssertionError.createFailed(code: Int32(result))
        }

        return assertionID
    }

    public func releaseAssertion(id: UInt32) {
        IOPMAssertionRelease(IOPMAssertionID(id))
    }

    private func assertionType(for kind: PowerAssertionKind) -> CFString {
        switch kind {
        case .idleSleep:
            kIOPMAssertionTypeNoIdleSleep as CFString
        case .displaySleep:
            kIOPMAssertionTypeNoDisplaySleep as CFString
        }
    }
}
