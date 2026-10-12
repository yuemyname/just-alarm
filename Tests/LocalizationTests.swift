import Foundation

@main struct LocalizationTests {
    static func main() throws {
        precondition(AppLanguage.defaultLanguage(preferredLanguages: ["ko-KR", "en-US"]) == .korean)
        precondition(AppLanguage.defaultLanguage(preferredLanguages: ["en-GB", "ko-KR"]) == .english)
        precondition(AppLanguage.defaultLanguage(preferredLanguages: ["fr-FR"]) == .english)
        precondition(AppLanguage.korean.text("설정") == "설정")
        precondition(AppLanguage.english.text("설정") == "Settings")
        precondition(AppLanguage.english.text("월요일") == "Monday")
        let weekdays = AlarmRecord(weekdays: [2, 3, 4, 5, 6])
        precondition(weekdays.repeatText(in: .english) == "Weekdays")
        precondition(weekdays.repeatText(in: .korean) == "평일")
        precondition(AlarmRecord(weekdays: [1, 7]).repeatText(in: .english) == "Sun · Sat")
        precondition(AlarmRecord().displayTitle(in: .english) == "Alarm")
        let authored = AlarmRecord(title: "엄마 전화 / Call Mom")
        precondition(authored.displayTitle(in: .english) == authored.title)
        precondition(authored.displayTitle(in: .korean) == authored.title)
        let suite = "JikimLanguageTest." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("en", forKey: AppLanguage.preferenceKey)
        precondition(AppLanguage.saved(in: UserDefaults(suiteName: suite)!) == .english)
        defaults.set("ko", forKey: AppLanguage.preferenceKey)
        precondition(AppLanguage.saved(in: UserDefaults(suiteName: suite)!) == .korean)
        print("PASS: Korean/English resources, language selection persistence, locale fallback, repeat days, user-authored titles")
    }
}
