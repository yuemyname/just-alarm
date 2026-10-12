import AlarmKit
import SwiftUI

struct JikimMetadata: AlarmMetadata {}

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
        do { activeIDs = Set(try manager.alarms.map(\.id)) }
        catch { errorMessage = AppLanguage.current.text("알람 상태를 확인하지 못했습니다.") + "\n" + error.localizedDescription }
    }

    private func schedule(_ record: AlarmRecord) async throws {
        let days: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let schedule = Alarm.Schedule.relative(.init(
            time: .init(hour: record.hour, minute: record.minute),
            repeats: record.weekdays.isEmpty ? .never : .weekly(record.weekdays.map { days[$0 - 1] })
        ))
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: record.displayTitle(in: .current)),
            stopButton: AlarmButton(text: LocalizedStringResource("중단", locale: AppLanguage.current.locale), textColor: .white, systemImageName: "stop.fill")
        )
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: JikimMetadata(), tintColor: .orange)
        _ = try await manager.schedule(id: record.id, configuration: .alarm(schedule: schedule, attributes: attributes))
    }

    private func write(_ record: AlarmRecord, deleting: Bool = false) async throws {
        guard !loadFailed else { throw StoreError.storage }
        if record.isEnabled && !deleting {
            let state = try await manager.requestAuthorization()
            guard state == .authorized else { throw StoreError.permission }
        }
        let previous = records.first { $0.id == record.id }
        let wasScheduled = try manager.alarms.contains { $0.id == record.id }
        var updated = records
        if deleting { updated.removeAll { $0.id == record.id } }
        else if let index = updated.firstIndex(where: { $0.id == record.id }) { updated[index] = record }
        else { updated.append(record) }
        var reservation = record
        if deleting { reservation.isEnabled = false }
        try await AlarmEditOperation.save(
            reservation, previous: previous, wasScheduled: wasScheduled,
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
        do { try await write(record); return true }
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
            if try manager.alarms.contains(where: { $0.id == id }) { return }
            record.isEnabled = true
            try await write(record)
        case .disable:
            record.isEnabled = false
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

    enum StoreError: LocalizedError {
        case permission, storage
        var errorDescription: String? {
            switch self {
            case .permission: AppLanguage.current.text("설정에서 지킴의 알람 권한을 허용해 주세요.")
            case .storage: AppLanguage.current.text("저장 데이터를 읽지 못해 변경을 중단했습니다.")
            }
        }
    }
}
