import Foundation

@main struct AlarmActionsTests {
    @MainActor static func main() async throws {
        let morning = AlarmRecord(hour: 7, minute: 30, title: "출근 Work")
        let evening = AlarmRecord(hour: 19, minute: 30, title: "운동")
        let other = AlarmRecord(hour: 8, minute: 0, title: "Work break", isEnabled: false)
        let records = [evening, other, morning]
        func find(_ query: String) -> [UUID] {
            AlarmSearch.results(in: records, query: query, language: .korean).map(\.id)
        }
        precondition(find("07:30") == [morning.id])
        precondition(find("7:30") == [morning.id])
        precondition(find("0730") == [morning.id])
        precondition(find("730") == [morning.id])
        precondition(find("WORK") == [morning.id, other.id])
        precondition(find("  출근   7:30  ") == [morning.id])
        precondition(find("19:30") == [evening.id])
        precondition(find("no match").isEmpty)
        precondition(find(" \n ") == [morning.id, other.id, evening.id])
        let ids = find("Work")
        var visited: [UUID] = []
        enum Failure: Error { case expected }
        let result = await AlarmBatchOperation.run(ids: ids + [ids[0]]) { id in
            visited.append(id)
            if id == morning.id { throw Failure.expected }
        }
        precondition(visited == ids, "Never touch non-matching or duplicate alarms")
        precondition(result.succeeded == 1 && result.failures.map(\.0) == [morning.id])
        let empty = await AlarmBatchOperation.run(ids: []) { _ in fatalError("Empty search must not modify alarms") }
        precondition(empty.succeeded == 0 && empty.failures.isEmpty)
        print("PASS: time formats, names, mixed queries, empty results, scoped batches, deduplication, partial failure continuation")
    }
}
