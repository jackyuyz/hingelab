import Testing
@testable import HingeL10n

@Suite("Language catalog")
struct CatalogTests {
    @Test("English is the default")
    func defaultLanguage() {
        #expect(AppLanguage.default == .en)
        #expect(L10nKey.appName.text(in: .en) == "HingeLab")
        #expect(L10nKey.settingsTitle.text(in: .en) == "Settings")
    }

    @Test("Every language has the same non-empty keys")
    func completeCatalogs() {
        let english = Set(L10nKey.allCases.map(\.rawValue))
        for language in AppLanguage.allCases {
            let keys = StringCatalog.keys(in: language)
            #expect(keys == english, "\(language.rawValue) keys differ")
            for key in L10nKey.allCases {
                let value = key.text(in: language)
                #expect(!value.isEmpty)
                #expect(value != key.rawValue, "Missing \(key.rawValue) in \(language.rawValue)")
            }
        }
    }

    @Test("Chinese translations differ")
    func translationsDiffer() {
        #expect(L10nKey.pickerTitle.text(in: .zhHans) == "选择乐器")
        #expect(L10nKey.instrumentAccordion.text(in: .zhHans) != L10nKey.instrumentAccordion.text(in: .en))
    }

    @Test("Unknown codes fall back")
    func fallback() {
        #expect(AppLanguage(languageCode: "de") == nil)
        #expect(AppLanguage(languageCode: "zh_CN") == .zhHans)
        #expect(AppLanguage(languageCode: "zh") == .zhHans)
    }
}
