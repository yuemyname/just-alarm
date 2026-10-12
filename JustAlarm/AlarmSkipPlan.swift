import Foundation

struct AlarmSkipPlan: Codable, Equatable {
    struct Occurrence: Codable, Equatable, Identifiable {
        var id: UUID
        var date: Date
    }
    var skippedDate: Date
    var occurrences: [Occurrence]
    var endDate: Date? { occurrences.last?.date }

    static func make(for record: AlarmRecord, after now: Date = .now, calendar: Calendar = .current) -> AlarmSkipPlan? {
        guard !record.weekdays.isEmpty, record.isEnabled else { return nil }
        func next(after date: Date) -> Date? {
            record.weekdays.compactMap { day in
                calendar.nextDate(after: date,
                    matching: DateComponents(hour: record.hour, minute: record.minute, second: 0, weekday: day),
                    matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
            }.min()
        }
        guard let skipped = next(after: now) else { return nil }
        var cursor = skipped
        var occurrences: [Occurrence] = []
        for index in 0..<8 {
            guard let date = next(after: cursor) else { return nil }
            occurrences.append(.init(id: index == 0 ? record.id : UUID(), date: date))
            cursor = date
        }
        return .init(skippedDate: skipped, occurrences: occurrences)
    }
}

/// Replaces a group of reservations, restoring only those actually removed on failure.
@MainActor enum AlarmReservationOperation {
    static func replace<Reservation>(
        old: [Reservation], new: [Reservation],
        id: (Reservation) -> UUID,
        schedule: (Reservation) async throws -> Void,
        cancel: (UUID) throws -> Void,
        commit: () throws -> Void
    ) async throws {
        var removed: [Reservation] = []
        var added: [Reservation] = []
        do {
            for reservation in old { try cancel(id(reservation)); removed.append(reservation) }
            for reservation in new { try await schedule(reservation); added.append(reservation) }
            try commit()
        } catch {
            let original = error
            var recoveryErrors: [Error] = []
            for reservation in added.reversed() {
                do { try cancel(id(reservation)) } catch { recoveryErrors.append(error) }
            }
            for reservation in removed {
                do { try await schedule(reservation) } catch { recoveryErrors.append(error) }
            }
            if let failure = recoveryErrors.first {
                throw AlarmEditOperation.RecoveryFailure(saveError: original, recoveryError: failure)
            }
            throw original
        }
    }
}
