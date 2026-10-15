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

@Suite("Music names")
struct MusicNameTests {
    @Test("Note names stay letters with octave")
    func noteNames() {
        #expect(NoteName.name(midi: 60) == "C4")
        #expect(NoteName.name(midi: 61) == "C♯4")
        #expect(NoteName.name(midi: 40) == "E2")
        #expect(NoteName.name(midi: 69) == "A4")
        #expect(NoteName.letter(midi: 70) == "A♯")
        let nearest = NoteName.nearest(hz: 446)
        #expect(nearest.midi == 69)
        #expect(abs(nearest.cents - 23.4) < 0.5)
    }

    @Test("Chord labels speak the quality in each language")
    func chords() {
        let c = ChordLabel(symbol: "C")
        #expect(c.symbol == "C")
        #expect(c.accessibilityLabel(in: .en) == "C major chord")
        #expect(c.accessibilityLabel(in: .zhHans) == "C 大调和弦")
        #expect(c.qualityName(in: .zhHans) == "大调")
        let am = ChordLabel(symbol: "Am")
        #expect(am.symbol == "Am")
        #expect(am.accessibilityLabel(in: .en) == "A minor chord")
        #expect(ChordLabel(symbol: "Bb").symbol == "B♭")
    }

    @Test("Format arguments fill in order")
    func formatting() {
        #expect(L10nKey.looperTracksUsed.text(in: .en, "1", "8") == "1 of 8 tracks")
        #expect(L10nKey.calStepOf.text(in: .zhHans, "2") == "第 2 / 3 步")
    }

    @Test("No placeholder copy ships")
    func noPlaceholderCopy() {
        for language in AppLanguage.allCases {
            for key in L10nKey.allCases {
                let value = key.text(in: language).lowercased()
                #expect(!value.contains("placeholder"), "\(key.rawValue)")
                #expect(!value.contains("占位"), "\(key.rawValue)")
            }
        }
    }
}
