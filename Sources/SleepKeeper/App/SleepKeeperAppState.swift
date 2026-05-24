import Foundation

@MainActor
final class SleepKeeperAppState: ObservableObject {
    let model: SleepKeeperModel
    private let statusItem: SleepKeeperStatusItem

    init() {
        let model = SleepKeeperModel()
        self.model = model
        self.statusItem = SleepKeeperStatusItem(model: model)
    }
}
