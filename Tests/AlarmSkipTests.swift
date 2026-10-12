import Foundation

@main struct AlarmSkipTests {
    @MainActor static func main() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        let record = AlarmRecord(hour: 7, minute: 0, title: "기상", weekdays: [2,3,4,5,6])
        let plan = AlarmSkipPlan.make(for: record, after: date(2026,10,12,21), calendar: calendar)!
        precondition(plan.skippedDate == date(2026,10,13,7))
        precondition(plan.occurrences.first?.date == date(2026,10,14,7))
        precondition(plan.occurrences.count == 8)
        precondition(Set(plan.occurrences.map(\.id)).count == 8 && plan.occurrences[0].id == record.id)
        precondition(plan.occurrences.allSatisfy { ![1,7].contains(calendar.component(.weekday, from: $0.date)) })
        let weekly = AlarmRecord(hour: 7, weekdays: [2])
        let monday = AlarmSkipPlan.make(for: weekly, after: date(2026,10,11), calendar: calendar)!
        precondition(monday.skippedDate == date(2026,10,12,7))
        precondition(monday.occurrences[0].date == date(2026,10,19,7))
        precondition(AlarmSkipPlan.make(for: AlarmRecord(), calendar: calendar) == nil)
        precondition(AlarmSkipPlan.make(for: AlarmRecord(weekdays: [2], isEnabled: false), calendar: calendar) == nil)
        var skipped = record; skipped.skipPlan = plan
        let roundtrip = try JSONDecoder().decode(AlarmRecord.self, from: JSONEncoder().encode(skipped))
        precondition(roundtrip == skipped && roundtrip.reservationIDs.count == 8)
        var ny = Calendar(identifier: .gregorian); ny.timeZone = TimeZone(identifier: "America/New_York")!
        let beforeDST = ny.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12))!
        let dst = AlarmSkipPlan.make(for: AlarmRecord(hour: 7, weekdays: [1,2,3,4,5,6,7]), after: beforeDST, calendar: ny)!
        precondition(dst.occurrences.allSatisfy { ny.component(.hour, from: $0.date) == 7 })

        enum Failure: Error { case schedule, cancel, disk }
        let old = [UUID(), UUID()]
        let new = [UUID(), UUID(), UUID()]
        var active = Set(old)
        var stored = old
        var reject: UUID? = new[1]
        func schedule(_ id: UUID) async throws {
            if id == reject { throw Failure.schedule }
            precondition(!active.contains(id)); active.insert(id)
        }
        do {
            try await AlarmReservationOperation.replace(old: old, new: new, id: { $0 }, schedule: schedule,
                cancel: { active.remove($0) }, commit: { stored = new })
            fatalError("Expected scheduling failure")
        } catch Failure.schedule {}
        precondition(active == Set(old) && stored == old, "Partial new plans must be removed and originals restored")
        reject = nil
        do {
            try await AlarmReservationOperation.replace(old: old, new: new, id: { $0 }, schedule: schedule,
                cancel: { active.remove($0) }, commit: { throw Failure.disk })
            fatalError("Expected disk failure")
        } catch Failure.disk {}
        precondition(active == Set(old) && stored == old)
        do {
            try await AlarmReservationOperation.replace(old: old, new: new, id: { $0 }, schedule: schedule,
                cancel: { if $0 == old[1] { throw Failure.cancel }; active.remove($0) }, commit: { stored = new })
            fatalError("Expected cancellation failure")
        } catch Failure.cancel {}
        precondition(active == Set(old) && stored == old)
        try await AlarmReservationOperation.replace(old: old, new: new, id: { $0 }, schedule: schedule,
            cancel: { active.remove($0) }, commit: { stored = new })
        precondition(active == Set(new) && stored == new)
        // Cancel skip: replace all fixed reservations with the original weekly reservation.
        try await AlarmReservationOperation.replace(old: new, new: [record.id], id: { $0 }, schedule: schedule,
            cancel: { active.remove($0) }, commit: { stored = [record.id] })
        precondition(active == [record.id] && stored == [record.id])
        print("PASS: skip exactly one, 8 future alarms, weekdays, weekly schedules, DST, persistence, grouped replacement and rollback, cancellation")
    }
}
