import Foundation

struct AlarmRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var hour = 7
    var minute = 0
    var title = ""
    var weekdays: [Int] = [] // Calendar: Sunday = 1
    var isEnabled = true

    var timeText: String { String(format: "%02d:%02d", hour, minute) }
    func displayTitle(in language: AppLanguage) -> String {
        title.isEmpty ? language.text("알람") : title
    }

    func repeatText(in language: AppLanguage) -> String {
        if weekdays.isEmpty { return language.text("한 번") }
        if weekdays.count == 7 { return language.text("매일") }
        if weekdays.sorted() == [2, 3, 4, 5, 6] { return language.text("평일") }
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        return weekdays.sorted().map { language.text(names[$0 - 1]) }.joined(separator: " · ")
    }
}
