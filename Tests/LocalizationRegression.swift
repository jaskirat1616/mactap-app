import Foundation
import Combine

@main
struct LocalizationRegression {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resourceURL = root.appendingPathComponent("MacTap/Resources/Localization")
        guard let bundle = Bundle(url: resourceURL) else { fatalError("Missing localization test bundle") }
        let suite = "app.mactap.localization-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let config = Data("existing gesture preferences".utf8)
        defaults.set(config, forKey: "app.mactap.config.v3")
        let localization = Localization(defaults: defaults, bundle: bundle, preferredLanguages: ["zh-Hans-CN"])
        precondition(localization.language == .simplifiedChinese)
        precondition(localization.text("Settings") == "设置")
        precondition(localization.text("Lock Screen") == "锁屏")
        precondition(localization.format("Left %d of 4", arguments: [3]) == "左侧：3 / 4")
        precondition(localization.format("Version %@", arguments: ["2.1.2"]) == "版本 2.1.2")
        print("PASS system language, Chinese UI keys and dynamic messages")
        var changes = 0
        let subscription = localization.$language.dropFirst().sink { _ in changes += 1 }
        localization.language = .english
        precondition(localization.text("Settings") == "Settings")
        precondition(localization.format("Left %d of 4", arguments: [3]) == "Left 3 of 4")
        precondition(changes == 1)
        let restored = Localization(defaults: defaults, bundle: bundle, preferredLanguages: ["zh-Hans"])
        precondition(restored.language == .english)
        precondition(defaults.data(forKey: "app.mactap.config.v3") == config)
        print("PASS instant change notification, persistence and gesture config preservation")
        precondition(localization.text("untranslated-key") == "untranslated-key")
        defaults.set("invalid", forKey: Localization.preferenceKey)
        precondition(Localization(defaults: defaults, bundle: bundle, preferredLanguages: ["en-US"]).language == .english)
        precondition(AppLanguage.initial(preferredLanguages: ["fr-FR"]) == .english)
        precondition(AppLanguage.initial(preferredLanguages: ["zh-Hant-TW", "en-US"]) == .english)
        print("PASS missing keys, unsupported preferences and languages fall back to English")
        let english = try catalog(resourceURL.appendingPathComponent("en.lproj/Localizable.strings"))
        let chinese = try catalog(resourceURL.appendingPathComponent("zh-Hans.lproj/Localizable.strings"))
        precondition(Set(english.keys) == Set(chinese.keys))
        let formats = try NSRegularExpression(pattern: #"%(?:\d+\$)?[-+#0 ]*(?:\d+|\*)?(?:\.\d+)?(?:ll|l)?[@diufg]"#)
        func placeholders(_ value: String) -> [String] {
            let range = NSRange(value.startIndex..., in: value)
            return formats.matches(in: value, range: range).map { (value as NSString).substring(with: $0.range) }.sorted()
        }
        for (key, translation) in chinese {
            precondition(!translation.isEmpty && placeholders(key) == placeholders(translation), "Invalid translation: \(key)")
            precondition(english[key] == key, "English source must stay stable: \(key)")
        }
        print("PASS \(english.count) translation pairs and format placeholders")
        withExtendedLifetime(subscription) {}
    }

    static func catalog(_ url: URL) throws -> [String: String] {
        try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: String]
    }
}
