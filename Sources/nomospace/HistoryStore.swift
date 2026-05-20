import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [CleanupHistoryRecord] = []

    private let defaultsKey = "cleanupHistory"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        records = Self.loadRecords(from: defaults, key: defaultsKey)
    }

    func record(result: CleanupResult, movedFindings: [StorageFinding]) {
        guard result.movedCount > 0 else { return }

        let record = CleanupHistoryRecord(
            movedCount: result.movedCount,
            reclaimedBytes: result.reclaimedBytes,
            itemTitles: movedFindings.map(\.title),
            itemPaths: movedFindings.map(\.path)
        )

        records.insert(record, at: 0)
        records = Array(records.prefix(20))
        save()
    }

    func clear() {
        records.removeAll()
        defaults.removeObject(forKey: defaultsKey)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private static func loadRecords(from defaults: UserDefaults, key: String) -> [CleanupHistoryRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([CleanupHistoryRecord].self, from: data) else {
            return []
        }
        return records
    }
}
