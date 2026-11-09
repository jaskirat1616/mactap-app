import Foundation
import Combine

// Keep language preference separate from gesture configuration and its migrations.
enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var nativeName: String { self == .english ? "English" : "简体中文" }

    static func initial(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let value = identifier.lowercased()
            if value.hasPrefix("zh-hans") || value == "zh" || value.hasPrefix("zh-cn") || value.hasPrefix("zh-sg") {
                return .simplifiedChinese
            }
            if value.hasPrefix("en") { return .english }
        }
        return .english
    }
}

final class Localization: ObservableObject {
    static let shared = Localization()
    static let preferenceKey = "app.mactap.language"

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Self.preferenceKey) }
    }
    private let defaults: UserDefaults
    private let languageBundles: [AppLanguage: Bundle]

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main,
         preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        languageBundles = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.compactMap { language in
            guard let path = bundle.path(forResource: language.rawValue, ofType: "lproj"),
                  let translations = Bundle(path: path) else { return nil }
            return (language, translations)
        })
        language = defaults.string(forKey: Self.preferenceKey).flatMap(AppLanguage.init(rawValue:))
            ?? AppLanguage.initial(preferredLanguages: preferredLanguages)
    }

    func text(_ key: String) -> String {
        languageBundles[language]?.localizedString(forKey: key, value: key, table: nil) ?? key
    }

    func format(_ key: String, arguments: [CVarArg]) -> String {
        let translated = text(key)
        guard !arguments.isEmpty else { return translated }
        return String(format: translated, locale: Locale(identifier: language.rawValue), arguments: arguments)
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    Localization.shared.format(key, arguments: arguments)
}

/// Keep keys and arguments until display so an in-progress message can switch language too.
struct LocalizedMessage {
    let key: String
    let arguments: [CVarArg]
    init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }
    var text: String { Localization.shared.format(key, arguments: arguments) }
}
