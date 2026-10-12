import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    static let preferenceKey = "appLanguage"
    var id: String { rawValue }
    var name: String { self == .korean ? "한국어" : "English" }
    var locale: Locale { Locale(identifier: rawValue) }

    init(locale: Locale) {
        self = locale.language.languageCode?.identifier == "ko" ? .korean : .english
    }

    static var defaultLanguage: AppLanguage {
        defaultLanguage(preferredLanguages: Locale.preferredLanguages)
    }

    static func defaultLanguage(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
            if let language = AppLanguage(rawValue: code ?? "") { return language }
        }
        return .english
    }

    static var current: AppLanguage {
        saved(in: .standard)
    }

    static func saved(in defaults: UserDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? defaultLanguage
    }

    func text(_ key: String, bundle: Bundle = .main) -> String {
        guard let path = bundle.path(forResource: rawValue, ofType: "lproj"),
              let localized = Bundle(path: path) else { return key }
        return localized.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
