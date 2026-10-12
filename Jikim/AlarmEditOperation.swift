import Foundation

/// AlarmKit scheduling creates a reservation; editing must explicitly replace it.
@MainActor enum AlarmEditOperation {
    static func save(
        _ record: AlarmRecord,
        previous: AlarmRecord?,
        wasScheduled: Bool,
        schedule: (AlarmRecord) async throws -> Void,
        cancel: (UUID) throws -> Void,
        commit: () throws -> Void
    ) async throws {
        // If cancellation fails, leave the previous reservation and storage alone.
        if wasScheduled { try cancel(record.id) }
        var replacementScheduled = false
        do {
            if record.isEnabled {
                try await schedule(record)
                replacementScheduled = true
            }
            try commit()
        } catch {
            let originalError = error
            do {
                if replacementScheduled { try cancel(record.id) }
                if wasScheduled, let previous { try await schedule(previous) }
            } catch {
                throw RecoveryFailure(saveError: originalError, recoveryError: error)
            }
            throw originalError
        }
    }

    struct RecoveryFailure: LocalizedError {
        let saveError: Error
        let recoveryError: Error
        var errorDescription: String? {
            AppLanguage.current.text("기존 알람을 복구하지 못했습니다. 알람 목록에서 시간을 확인하고 다시 켜 주세요.")
                + "\n" + saveError.localizedDescription + "\n" + recoveryError.localizedDescription
        }
    }
}
