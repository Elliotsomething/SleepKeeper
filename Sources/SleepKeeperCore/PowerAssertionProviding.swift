import Foundation

public protocol PowerAssertionProviding {
    func createAssertion(kind: PowerAssertionKind, reason: String) throws -> UInt32
    func releaseAssertion(id: UInt32)
}

public enum PowerAssertionKind: Equatable {
    case idleSleep
    case displaySleep
}

public enum PowerAssertionError: LocalizedError, Equatable {
    case createFailed(code: Int32)

    public var errorDescription: String? {
        switch self {
        case let .createFailed(code):
            "Unable to create macOS power assertion. IOKit returned \(code)."
        }
    }
}
