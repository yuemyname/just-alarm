import Foundation

enum AlarmSearch {
    static func results(in records: [AlarmRecord], query: String, language: AppLanguage) -> [AlarmRecord] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return records.filter { record in
            let name = record.displayTitle(in: language)
            let times = [record.timeText,
                         String(format: "%d:%02d", record.hour, record.minute),
                         String(format: "%02d%02d", record.hour, record.minute),
                         String(format: "%d%02d", record.hour, record.minute),
                         "\(record.hour)시\(record.minute)분"]
            return terms.allSatisfy { term in
                name.localizedCaseInsensitiveContains(term) || times.contains { $0.contains(term) }
            }
        }.sorted { ($0.hour, $0.minute, $0.id.uuidString) < ($1.hour, $1.minute, $1.id.uuidString) }
    }
}

enum AlarmBatchAction { case enable, disable, delete }

@MainActor enum AlarmBatchOperation {
    struct Result {
        var succeeded = 0
        var failures: [(UUID, Error)] = []
    }

    static func run(ids: [UUID], operation: (UUID) async throws -> Void) async -> Result {
        var result = Result()
        var visited = Set<UUID>()
        // Snapshot IDs keep the operation scoped to the user's selected results.
        for id in ids where visited.insert(id).inserted {
            do { try await operation(id); result.succeeded += 1 }
            catch { result.failures.append((id, error)) }
        }
        return result
    }
}
