import SwiftUI

struct AlarmListView: View {
    @State private var store = AlarmStore.shared
    @State private var editing: AlarmRecord?
    @State private var showSettings = false
    @State private var query = ""
    @State private var deletionIDs: [UUID] = []
    @State private var confirmDeletion = false
    @State private var skipID: UUID?
    @State private var confirmSkip = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.locale) private var locale
    private var language: AppLanguage { AppLanguage(locale: locale) }

    private var results: [AlarmRecord] { AlarmSearch.results(in: store.records, query: query, language: language) }
    private var searching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.records.isEmpty && !searching {
                        ContentUnavailableView("지키고 싶은 시간을 추가하세요", systemImage: "alarm", description: Text("오른쪽 위 + 버튼으로 첫 알람을 만드세요."))
                    }
                    if searching && results.isEmpty {
                        ContentUnavailableView("검색 결과가 없어요", systemImage: "magnifyingglass", description: Text("다른 시간이나 알람 이름으로 검색해 보세요."))
                    }
                    ForEach(results) { record in
                        HStack(spacing: 16) {
                            Button { editing = record } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.timeText).font(.system(size: 38, weight: .light, design: .rounded)).monospacedDigit()
                                        .foregroundStyle(store.activeIDs.contains(record.id) ? .primary : .secondary)
                                    HStack(spacing: 6) {
                                        Text(verbatim: record.displayTitle(in: language))
                                        Text(verbatim: "· " + record.repeatText(in: language))
                                    }.font(.subheadline).foregroundStyle(.secondary)
                                    if let plan = record.skipPlan, record.isEnabled {
                                        Label {
                                            Text("다음 알람 건너뜀")
                                            Text(plan.skippedDate, format: .dateTime.month().day().hour().minute())
                                        } icon: { Image(systemName: "forward.end") }
                                        .font(.caption).foregroundStyle(.orange)
                                        if let end = plan.endDate {
                                            HStack(spacing: 4) {
                                                Text("예약 기한")
                                                Text(end, format: .dateTime.year().month().day().hour().minute())
                                            }.font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    if record.isEnabled && !store.activeIDs.contains(record.id) {
                                        Text("예약 없음 · 다시 켜려면 스위치를 누르세요")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Toggle(isOn: Binding(
                                get: { store.activeIDs.contains(record.id) },
                                set: { enabled in
                                    Task { _ = await store.perform(enabled ? .enable : .disable, ids: [record.id]) }
                                }
                            )) { Text(verbatim: record.displayTitle(in: language)) }.labelsHidden().tint(.green)
                        }.padding(.vertical, 6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deletionIDs = [record.id]; confirmDeletion = true
                            } label: { Label("삭제", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !record.weekdays.isEmpty && record.isEnabled && (store.activeIDs.contains(record.id) || record.skipPlan != nil) {
                                Button {
                                    if record.skipPlan == nil { skipID = record.id; confirmSkip = true }
                                    else { Task { await store.toggleSkip(record.id) } }
                                } label: {
                                    Label(LocalizedStringKey(record.skipPlan == nil ? "한 번 건너뛰기" : "건너뛰기 취소"),
                                          systemImage: record.skipPlan == nil ? "forward.end" : "arrow.uturn.backward")
                                }.tint(.orange)
                            }
                        }
                    }
                } header: {
                    Text(verbatim: searching ? language.text("검색 결과") + " · \(results.count)" : language.text("나의 알람"))
                }

            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "시간 또는 알람 이름")
            .safeAreaInset(edge: .bottom) {
                if searching && !results.isEmpty {
                    HStack {
                        Text(verbatim: language.text("검색 결과") + " · \(results.count)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            Button("모두 켜기", systemImage: "bell") { runBatch(.enable) }
                            Button("모두 끄기", systemImage: "bell.slash") { runBatch(.disable) }
                            Button("모두 삭제", systemImage: "trash", role: .destructive) {
                                deletionIDs = results.map(\.id); confirmDeletion = true
                            }
                        } label: { Label("일괄 작업", systemImage: "ellipsis.circle") }
                        .disabled(store.busy)
                    }.padding().background(.bar)
                }
            }
            .navigationTitle("알람")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("설정", systemImage: "gearshape") { showSettings = true } }
                ToolbarItem(placement: .topBarTrailing) { Button("알람 추가", systemImage: "plus") { editing = AlarmRecord() } }
            }
            .disabled(store.busy)
            .overlay { if store.busy { ProgressView("저장 중…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .sheet(item: $editing) { AlarmEditor(record: $0, store: store) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .confirmationDialog("다음 한 번을 건너뛸까요?", isPresented: $confirmSkip, titleVisibility: .visible) {
                Button("한 번 건너뛰기") {
                    if let id = skipID { Task { await store.toggleSkip(id) } }
                }
                Button("취소", role: .cancel) { skipID = nil }
            } message: {
                Text("이후 8회분만 미리 예약합니다. 예약 기한 전에 앱을 다시 열어 반복 예약을 복원해 주세요.")
            }
            .confirmationDialog("선택한 알람을 삭제할까요?", isPresented: $confirmDeletion, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    let ids = deletionIDs
                    Task { _ = await store.perform(.delete, ids: ids) }
                }
                Button("취소", role: .cancel) { deletionIDs = [] }
            } message: {
                Text(verbatim: String(format: language.text("%d개의 알람이 삭제됩니다. 이 작업은 되돌릴 수 없습니다."), deletionIDs.count))
            }
            .alert("확인이 필요해요", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("확인") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }.tint(.orange)
        .task { await store.observe() }
        .task {
            while !Task.isCancelled {
                if phase == .active { await store.restoreRecurringIfNeeded() }
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
            }
        }
        .onChange(of: phase) { _, value in
            if value == .active { store.refresh(); Task { await store.restoreRecurringIfNeeded() } }
        }
    }

    private func runBatch(_ action: AlarmBatchAction) {
        let ids = results.map(\.id)
        Task { _ = await store.perform(action, ids: ids) }
    }

}

struct AlarmEditor: View {
    @State var record: AlarmRecord
    let store: AlarmStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private var language: AppLanguage { AppLanguage(locale: locale) }
    @State private var confirmDelete = false
    private var original: AlarmRecord? { store.records.first { $0.id == record.id } }
    private var time: Binding<Date> {
        Binding(get: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: record.hour, minute: record.minute)) ?? .now }, set: {
            record.hour = Calendar.current.component(.hour, from: $0)
            record.minute = Calendar.current.component(.minute, from: $0)
        })
    }
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("시간", selection: time, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                Section {
                    TextField("알람 이름", text: $record.title)
                    NavigationLink {
                        List {
                            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                                Toggle(LocalizedStringKey(["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"][day - 1]), isOn: Binding(
                                    get: { record.weekdays.contains(day) },
                                    set: { on in if on { record.weekdays.append(day) } else { record.weekdays.removeAll { $0 == day } } }
                                ))
                            }
                        }.navigationTitle("반복")
                    } label: { LabeledContent("반복", value: record.repeatText(in: language)) }
                    LabeledContent { Text("시스템 기본 알람음") } label: { Text("사운드") }
                }
                if original != nil {
                    Section { Button("알람 삭제", role: .destructive) { confirmDelete = true }.frame(maxWidth: .infinity) }
                }
            }
            .navigationTitle(LocalizedStringKey(original == nil ? "알람 추가" : "알람 편집"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") {
                    save()
                }.fontWeight(.semibold) }
            }
            .disabled(store.busy)
            .confirmationDialog("이 알람을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    Task { if await store.perform(.delete, ids: [record.id]) { dismiss() } }
                }
                Button("취소", role: .cancel) {}
            }
            .alert("저장하지 못했어요", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("확인") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }.interactiveDismissDisabled(store.busy)
    }
    private func save() {
        record.title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { if await store.save(record) { dismiss() } }
    }
}
