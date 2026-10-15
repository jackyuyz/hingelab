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

@Suite("Designed theme")
struct DesignedThemeTests {
    let theme = DesignedTheme()

    @Test("Every token, symbol and animation is provided")
    func complete() {
        for token in ColorToken.allCases {
            let c = theme.color(token)
            #expect((0...1).contains(c.red) && (0...1).contains(c.green) && (0...1).contains(c.blue))
        }
        for slot in SymbolSlot.allCases { #expect(!theme.systemImage(slot).isEmpty) }
        for slot in AnimationSlot.allCases { #expect(theme.animationName(slot) == "hl.\(slot.rawValue)") }
        #expect(theme.imageAssetName(.appIcon) == "AppIcon")
        #expect(theme.imageAssetName(.accordionBellows).isEmpty, "bellows are drawn in code")
    }

    @Test("Text and instrument hues are legible on the stage")
    func contrast() {
        let stage = theme.color(.stageBackground)
        let surface = theme.color(.surface)
        #expect(theme.color(.primaryText).contrastRatio(against: stage) >= 7)
        #expect(theme.color(.secondaryText).contrastRatio(against: surface) >= 4.5)
        for hue in [ColorToken.accordionHue, .guitarHue, .filterHue, .thereminHue] {
            // Hue as text/indicator on the stage, and dark ink on a lit key.
            #expect(theme.color(hue).contrastRatio(against: stage) >= 4.5, "\(hue)")
            #expect(theme.color(.onHue).contrastRatio(against: theme.color(hue)) >= 4.5, "ink on \(hue)")
        }
    }

    @Test("Instrument hues are distinct")
    func distinctHues() {
        let hues = [ColorToken.accordionHue, .guitarHue, .filterHue, .thereminHue].map { theme.color($0) }
        for i in 0..<hues.count {
            for j in (i + 1)..<hues.count {
                let d = abs(hues[i].red - hues[j].red) + abs(hues[i].green - hues[j].green) + abs(hues[i].blue - hues[j].blue)
                #expect(d > 0.4)
            }
        }
    }

    @Test("Built-in audio ships accordion reeds only")
    func builtinAudio() {
        let audio = BuiltinAudioAssets()
        for slot in SampleSlot.allCases {
            let name = audio.sampleName(slot)
            if slot.isAccordionReed {
                #expect(name.hasPrefix("hl_builtin_accordion_"))
                #expect(name.hasSuffix("_reed"))
            } else {
                #expect(name.isEmpty, "\(slot) is pack content")
            }
        }
        #expect(SampleSlot.accordionReedC3.rootMIDINote == 48)
        #expect(SampleSlot.accordionReedG4.rootMIDINote == 67)
    }
}

@Suite("Instrument motion")
struct InstrumentMotionTests {
    @Test("Bellows open with the hinge")
    func bellows() {
        let shut = InstrumentMotion.bellowsPleatEdges(openness: 0, pleats: 8)
        let open = InstrumentMotion.bellowsPleatEdges(openness: 1, pleats: 8)
        #expect(shut.count == 9)
        #expect(abs((shut.last! - shut.first!) - 0.3) < 1e-9)
        #expect(open.first == 0 && open.last == 1)
        #expect(zip(open, open.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("Visuals rest exactly when the sound rests")
    func rest() {
        #expect(InstrumentMotion.bellowsPressure(velocityDegPerSec: 1.9) == 0)
        #expect(InstrumentMotion.bellowsPressure(velocityDegPerSec: -90) == 0.5)
        #expect(InstrumentMotion.sparkRate(velocityDegPerSec: 1) == 0)
        #expect(InstrumentMotion.sparkRate(velocityDegPerSec: 500) == 48)
        #expect(InstrumentMotion.sparkRate(velocityDegPerSec: 500, reduceMotion: true) == 0)
        #expect(InstrumentMotion.stringVibration(secondsSincePluck: 0, velocity: 1, reduceMotion: true) == 0)
    }

    @Test("Gauge, bloom and glow scales")
    func scales() {
        #expect(InstrumentMotion.gaugeFraction(angleDegrees: 90) == 0.5)
        #expect(InstrumentMotion.gaugeFraction(angleDegrees: nil) == 0)
        let ticks = InstrumentMotion.gaugeTicks()
        #expect(ticks.count == 19)
        #expect(ticks.filter(\.isMajor).count == 7)
        #expect(InstrumentMotion.bloom(cutoffHz: 20) == 0)
        #expect(abs(InstrumentMotion.bloom(cutoffHz: 20_000) - 1) < 1e-9)
        #expect(abs(InstrumentMotion.bloom(cutoffHz: 632.46) - 0.5) < 0.001)
        let glow = InstrumentMotion.thereminGlow(frequencyHz: 261.63, amplitude: 0.5)
        #expect(abs(glow.position - 1.0 / 3) < 0.001)
        #expect(InstrumentMotion.bendOffset(semitones: -3, range: 2) == -1)
    }

    @Test("Scope trace is bounded by amplitude")
    func scope() {
        let trace = InstrumentMotion.scopeTrace(points: 64, cycles: 2, amplitude: 0.5, shape: 0.3, phase: 0)
        #expect(trace.count == 64)
        #expect(trace.allSatisfy { abs($0) <= 0.5 + 1e-9 })
    }
}
