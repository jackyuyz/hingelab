import Testing
@testable import ThemeKit

@Suite("Placeholder theme")
struct PlaceholderThemeTests {
    @Test("Every token and slot has a value")
    func complete() {
        let theme = PlaceholderTheme()
        for token in ColorToken.allCases {
            let color = theme.color(token)
            #expect((0...1).contains(color.red))
            #expect((0...1).contains(color.green))
            #expect((0...1).contains(color.blue))
        }
        for slot in ImageSlot.allCases {
            #expect(theme.imageAssetName(slot).hasPrefix("placeholder."))
        }
        for slot in SymbolSlot.allCases {
            #expect(!theme.systemImage(slot).isEmpty)
        }
        for slot in AnimationSlot.allCases {
            #expect(theme.animationName(slot).contains(slot.rawValue))
        }
        let audio = PlaceholderAudioAssets()
        for slot in SampleSlot.allCases {
            #expect(audio.sampleFileExtension(slot) == "caf")
            #expect(!audio.sampleName(slot).isEmpty)
        }
    }
}
