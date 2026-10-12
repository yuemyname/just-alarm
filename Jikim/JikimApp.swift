import SwiftUI

@main struct JikimApp: App {
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.defaultLanguage.rawValue

    var body: some Scene {
        WindowGroup {
            AlarmListView()
                .environment(\.locale, (AppLanguage(rawValue: language) ?? .defaultLanguage).locale)
        }
    }
}
