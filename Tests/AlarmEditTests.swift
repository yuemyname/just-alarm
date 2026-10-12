import Foundation

@MainActor final class FakeAlarmSystem {
    enum Failure: Error { case duplicate, scheduling, cancellation, disk }
    var reservations: [UUID: AlarmRecord] = [:]
    var disk: [AlarmRecord] = []
    var rejectHours: Set<Int> = []
    var rejectCancellation = false
    var rejectCommit = false
    var events: [String] = []

    func schedule(_ record: AlarmRecord) async throws {
        events.append("schedule:\(record.hour)")
        guard reservations[record.id] == nil else { throw Failure.duplicate }
        guard !rejectHours.contains(record.hour) else { throw Failure.scheduling }
        reservations[record.id] = record
    }
    func cancel(_ id: UUID) throws {
        events.append("cancel")
        if rejectCancellation { throw Failure.cancellation }
        reservations.removeValue(forKey: id)
    }
    func save(_ record: AlarmRecord, previous: AlarmRecord?) async throws {
        try await AlarmEditOperation.save(
            record, previous: previous, wasScheduled: reservations[record.id] != nil,
            schedule: { try await self.schedule($0) }, cancel: { try self.cancel($0) },
            commit: {
                if self.rejectCommit { throw Failure.disk }
                self.disk = [record]
            }
        )
    }
}

@main struct AlarmEditTests {
    @MainActor static func main() async throws {
        let old = AlarmRecord(hour: 7, minute: 30, title: "출근", weekdays: [2,3,4,5,6])
        var changed = old
        changed.hour = 8; changed.minute = 15; changed.title = "Work"; changed.weekdays = [1,7]
        func system() -> FakeAlarmSystem {
            let result = FakeAlarmSystem()
            result.reservations[old.id] = old
            result.disk = [old]
            return result
        }
        let success = system()
        try await success.save(changed, previous: old)
        precondition(success.events == ["cancel", "schedule:8"])
        precondition(success.reservations == [old.id: changed] && success.disk == [changed])
        // Consecutive edits must never accumulate reservations or duplicate IDs.
        try await success.save(old, previous: changed)
        precondition(success.reservations.count == 1 && success.disk == [old])

        let failedSchedule = system(); failedSchedule.rejectHours = [8]
        do { try await failedSchedule.save(changed, previous: old); fatalError("Expected rejection") }
        catch FakeAlarmSystem.Failure.scheduling {}
        precondition(failedSchedule.reservations == [old.id: old] && failedSchedule.disk == [old])

        let failedCancel = system(); failedCancel.rejectCancellation = true
        do { try await failedCancel.save(changed, previous: old); fatalError("Expected rejection") }
        catch FakeAlarmSystem.Failure.cancellation {}
        precondition(failedCancel.events == ["cancel"] && failedCancel.reservations == [old.id: old])

        let failedDisk = system(); failedDisk.rejectCommit = true
        do { try await failedDisk.save(changed, previous: old); fatalError("Expected rejection") }
        catch FakeAlarmSystem.Failure.disk {}
        precondition(failedDisk.reservations == [old.id: old] && failedDisk.disk == [old])

        let failedRecovery = system(); failedRecovery.rejectHours = [7,8]
        do { try await failedRecovery.save(changed, previous: old); fatalError("Expected rejection") }
        catch is AlarmEditOperation.RecoveryFailure {}
        precondition(failedRecovery.disk == [old])

        var disabled = changed; disabled.isEnabled = false
        let disabledEdit = FakeAlarmSystem()
        try await disabledEdit.save(disabled, previous: old)
        precondition(disabledEdit.reservations.isEmpty && disabledEdit.events.isEmpty)
        let enabled = FakeAlarmSystem()
        try await enabled.save(changed, previous: disabled)
        precondition(enabled.events == ["schedule:8"] && enabled.reservations == [changed.id: changed])
        let failedNew = FakeAlarmSystem(); failedNew.rejectCommit = true
        do { try await failedNew.save(changed, previous: nil); fatalError("Expected rejection") }
        catch FakeAlarmSystem.Failure.disk {}
        precondition(failedNew.reservations.isEmpty && failedNew.disk.isEmpty)
        print("PASS: consecutive edits; no duplicate reservations; schedule/cancel/disk failures; restoration and restoration failure; disabled edits; re-enable; new-alarm rollback")
    }
}
