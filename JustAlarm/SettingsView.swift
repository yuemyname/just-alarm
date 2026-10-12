import SwiftUI

struct SettingsView: View {
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.defaultLanguage.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("언어", selection: $language) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(verbatim: option.name).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityIdentifier("languagePicker")
                } header: {
                    Label("앱 언어", systemImage: "globe")
                } footer: {
                    Text("선택한 언어는 바로 적용되며 다음에도 유지됩니다. 직접 입력한 알람 이름은 바뀌지 않습니다.")
                }
                Section("알람 사용하기") {
                    Text("+ 버튼으로 알람을 추가하고 시간, 이름, 반복 요일을 설정하세요. 목록의 스위치로 알람을 켜고 끌 수 있습니다.")
                    Text("알람을 누르면 편집할 수 있습니다. 삭제는 편집 화면에서 할 수 있습니다.")
                }
                Section("검색과 빠른 작업") {
                    Text("왼쪽으로 밀면 삭제, 반복 알람을 오른쪽으로 밀면 다음 한 번을 건너뛰거나 취소할 수 있습니다.")
                    Text("시간이나 이름으로 검색한 뒤 아래의 일괄 작업에서 검색 결과를 모두 켜기, 끄기, 삭제할 수 있습니다.")
                }
                Section("한 번 건너뛰기") {
                    Text("다음 알람 한 번을 제외한 이후 8회분을 미리 예약합니다. 목록의 예약 기한 이후에는 알람이 울리지 않습니다.")
                    Text("건너뛸 시간이 지난 뒤 앱을 열면 원래 반복 예약으로 복원됩니다. 예약 기한 전에 앱을 다시 열어 주세요.")
                    Text("시간이나 반복 요일을 편집하거나 알람을 끄면 건너뛰기가 해제됩니다. 여행으로 시간대가 바뀌면 알람을 다시 확인해 주세요.")
                }
                Section("기본 시계와 별도 관리") {
                    Text("just alarm에 등록한 알람은 이 앱에서 관리합니다. 기본 시계 앱의 알람을 가져오거나 변경하지 않습니다.")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
        .environment(\.locale, (AppLanguage(rawValue: language) ?? .defaultLanguage).locale)
    }
}
