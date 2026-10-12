import AlarmKit
import SwiftUI

struct JustAlarmMetadata: AlarmMetadata {}

@MainActor @Observable final class AlarmStore {
    static let shared = AlarmStore()
    private(set) var records: [AlarmRecord] = []
    private(set) var activeIDs: Set<UUID> = []
    private(set) var busy = false
    var errorMessage: String?
    private var loadFailed = false
    private let manager = AlarmManager.shared
    private let file: URL

    private init() {
        file = URL.applicationSupportDirectory.appending(path: "Jikim/alarms.json")
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                records = try JSONDecoder().decode([AlarmRecord].self, from: Data(contentsOf: file))
            }
        } catch {
            loadFailed = true
            errorMessage = AppLanguage.current.text("저장된 알람을 읽지 못했습니다. 기존 데이터를 보존했습니다.") + "\n" + error.localizedDescription
        }
    }

    func observe() async {
        refresh()
        for await _ in manager.alarmUpdates {
            if Task.isCancelled { return }
            if !busy { refresh() }
        }
    }

    func refresh() {
        do {
            let scheduled = Set(try manager.alarms.map(\.id))
            activeIDs = Set(records.filter { !$0.reservationIDs.isDisjoint(with: scheduled) }.map(\.id))
        }
        catch { errorMessage = AppLanguage.current.text("알람 상태를 확인하지 못했습니다.") + "\n" + error.localizedDescription }
    }

    private struct Reservation {
        var id: UUID
        var schedule: Alarm.Schedule
        var record: AlarmRecord
    }

    private func reservations(for record: AlarmRecord) -> [Reservation] {
        guard record.isEnabled else { return [] }
        if let plan = record.skipPlan {
            return plan.occurrences.filter { $0.date > .now }.map {
                Reservation(id: $0.id, schedule: .fixed($0.date), record: record)
            }
        }
        let days: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let schedule = Alarm.Schedule.relative(.init(
            time: .init(hour: record.hour, minute: record.minute),
            repeats: record.weekdays.isEmpty ? .never : .weekly(record.weekdays.map { days[$0 - 1] })
        ))
        return [Reservation(id: record.id, schedule: schedule, record: record)]
    }

    private func schedule(_ reservation: Reservation) async throws {
        let record = reservation.record
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: record.displayTitle(in: .current)),
            stopButton: AlarmButton(text: LocalizedStringResource("중단", locale: AppLanguage.current.locale), textColor: .white, systemImageName: "stop.fill")
        )
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: JustAlarmMetadata(), tintColor: .orange)
        _ = try await manager.schedule(id: reservation.id, configuration: .alarm(schedule: reservation.schedule, attributes: attributes))
    }

    private func write(_ record: AlarmRecord, deleting: Bool = false) async throws {
        guard !loadFailed else { throw StoreError.storage }
        if record.isEnabled && !deleting {
            let state = try await manager.requestAuthorization()
            guard state == .authorized else { throw StoreError.permission }
        }
        let previous = records.first { $0.id == record.id }
        let existingIDs = previous?.reservationIDs ?? record.reservationIDs
        let oldReservations = try manager.alarms.filter { existingIDs.contains($0.id) }.compactMap { alarm -> Reservation? in
            guard let schedule = alarm.schedule else { return nil }
            return Reservation(id: alarm.id, schedule: schedule, record: previous ?? record)
        }
        var updated = records
        if deleting { updated.removeAll { $0.id == record.id } }
        else if let index = updated.firstIndex(where: { $0.id == record.id }) { updated[index] = record }
        else { updated.append(record) }
        var reservation = record
        if deleting { reservation.isEnabled = false }
        try await AlarmReservationOperation.replace(
            old: oldReservations, new: reservations(for: reservation), id: { $0.id },
            schedule: { try await self.schedule($0) },
            cancel: { try self.manager.cancel(id: $0) },
            commit: {
                try FileManager.default.createDirectory(at: self.file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(updated).write(to: self.file, options: .atomic)
                self.records = updated
            }
        )
    }

    func save(_ record: AlarmRecord) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false; refresh() }
        do {
            var updated = record
            if let previous = records.first(where: { $0.id == record.id }),
               previous.hour != record.hour || previous.minute != record.minute || previous.weekdays != record.weekdays {
                updated.skipPlan = nil
            }
            try await write(updated)
            return true
        }
        catch {
            errorMessage = AppLanguage.current.text("알람을 저장하지 못했습니다. 알람 목록에서 상태를 확인해 주세요.") + "\n" + error.localizedDescription
            return false
        }
    }

    private func apply(_ action: AlarmBatchAction, to id: UUID) async throws {
        guard var record = records.first(where: { $0.id == id }) else { return }
        switch action {
        case .delete:
            try await write(record, deleting: true)
        case .enable:
            // Leave already-active reservations untouched, including their next fire time.
            if try manager.alarms.contains(where: { record.reservationIDs.contains($0.id) }) { return }
            record.skipPlan = nil
            record.isEnabled = true
            try await write(record)
        case .disable:
            record.isEnabled = false
            record.skipPlan = nil
            try await write(record)
        }
    }

    func perform(_ action: AlarmBatchAction, ids: [UUID]) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false; refresh() }
        let names = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.displayTitle(in: .current)) })
        let result = await AlarmBatchOperation.run(ids: ids) { try await self.apply(action, to: $0) }
        if !result.failures.isEmpty {
            let language = AppLanguage.current
            let summary = String(format: language.text("%d개 완료 · %d개 실패"), result.succeeded, result.failures.count)
            let details = result.failures.map { id, error in
                (names[id] ?? language.text("알람")) + ": " + error.localizedDescription
            }.joined(separator: "\n")
            errorMessage = summary + "\n" + details
            return false
        }
        return true
    }

    func toggleSkip(_ id: UUID) async {
        guard !busy, var record = records.first(where: { $0.id == id }),
              record.isEnabled, !record.weekdays.isEmpty else { return }
        busy = true
        defer { busy = false; refresh() }
        do {
            if try manager.alarms.contains(where: { record.reservationIDs.contains($0.id) && $0.state != .scheduled }) {
                errorMessage = AppLanguage.current.text("울리는 알람을 먼저 중단한 뒤 다시 시도해 주세요.")
                return
            }
        } catch { errorMessage = error.localizedDescription; return }
        if record.skipPlan != nil { record.skipPlan = nil }
        else {
            guard let plan = AlarmSkipPlan.make(for: record) else { return }
            record.skipPlan = plan
        }
        do { try await write(record) }
        catch {
            let detail = error is AlarmManager.AlarmError
                ? AppLanguage.current.text("예약 가능한 알람 개수 한도에 도달했습니다. 다른 알람을 정리한 뒤 다시 시도해 주세요.")
                : error.localizedDescription
            errorMessage = AppLanguage.current.text("건너뛰기를 변경하지 못했습니다.") + "\n" + detail
        }
    }

    func restoreRecurringIfNeeded() async {
        guard !busy else { return }
        guard let systemAlarms = try? manager.alarms else { return }
        let ringing = Set(systemAlarms.filter { $0.state != .scheduled }.map(\.id))
        let expired = records.filter {
            $0.isEnabled && ($0.skipPlan.map { $0.skippedDate < .now } ?? false)
                && $0.reservationIDs.isDisjoint(with: ringing)
        }
        guard !expired.isEmpty else { return }
        busy = true
        defer { busy = false; refresh() }
        for var record in expired {
            record.skipPlan = nil
            do { try await write(record) }
            catch {
                errorMessage = AppLanguage.current.text("반복 알람 복원에 실패했습니다. 표시된 예약 기한을 확인해 주세요.") + "\n" + error.localizedDescription
                break
            }
        }
    }

    enum StoreError: LocalizedError {
        case permission, storage
        var errorDescription: String? {
            switch self {
            case .permission: AppLanguage.current.text("설정에서 just alarm의 알람 권한을 허용해 주세요.")
            case .storage: AppLanguage.current.text("저장 데이터를 읽지 못해 변경을 중단했습니다.")
            }
        }
    }
}
