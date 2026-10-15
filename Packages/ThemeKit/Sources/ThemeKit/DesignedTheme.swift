import Foundation

/// HingeLab's shipping look: a dark lab stage, ivory precision dials, and one
/// lacquer hue per instrument (accordion red, guitar amber, filter cyan,
/// theremin violet). Instrument surfaces are drawn in code from these tokens
/// so they track the hinge and the runtime display size.
///
/// `imageAssetName` returns the catalog name for slots that ship as files.
/// Slots drawn in code return "" (the views then use their vector drawing);
/// a later artwork pass can return a catalog name here without view changes.
public struct DesignedTheme: ThemeProviding, Sendable {
    public let name = "hingelab"

    public init() {}

    public func color(_ token: ColorToken) -> ThemeColor {
        switch token {
        case .stageBackground: return .hex(0x0C0D12)
        case .surface: return .hex(0x161821)
        case .surfaceRaised: return .hex(0x20232F)
        case .hairline: return .hex(0x2E3242)
        case .onHue: return .hex(0x0C0D12)
        case .primaryText: return .hex(0xF2EFE8)
        case .secondaryText: return .hex(0x9C9DAA)
        case .creaseGuide: return .hex(0x3B3F52)
        case .gauge: return .hex(0xE9DFC6)
        case .accordionHue: return .hex(0xE5483C)
        case .guitarHue: return .hex(0xF0A332)
        case .filterHue: return .hex(0x2FC4D6)
        case .thereminHue: return .hex(0xA274F2)
        case .lock: return .hex(0x6F7183)
        case .destructive: return .hex(0xFF5F52)
        case .waveform: return .hex(0x7EF2B0)
        }
    }

    public func imageAssetName(_ slot: ImageSlot) -> String {
        switch slot {
        case .appIcon: return "AppIcon"
        case .particleSpark: return "hl.particleSpark"
        case .accordionBellows, .accordionSkin, .guitarFretboard, .guitarSkin,
             .filterSkin, .thereminAntenna, .thereminSkin, .angleGaugeFace,
             .waveformOverlay, .paywallHero:
            return ""
        }
    }

    public func systemImage(_ slot: SymbolSlot) -> String {
        switch slot {
        case .accordion: return "pianokeys"
        case .guitar: return "guitars"
        case .filter: return "slider.vertical.3"
        case .theremin: return "waveform"
        case .looper: return "repeat.circle"
        case .midi: return "cable.connector.horizontal"
        case .settings: return "gearshape"
        case .lock: return "lock.fill"
        case .ribbon: return "slider.horizontal.below.rectangle"
        case .calibrate: return "angle"
        case .export: return "square.and.arrow.up"
        }
    }

    public func animationName(_ slot: AnimationSlot) -> String {
        "hl.\(slot.rawValue)"
    }
}

extension ThemeColor {
    public static func hex(_ value: UInt32, opacity: Double = 1) -> ThemeColor {
        ThemeColor(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// WCAG relative luminance, for contrast checks in tests.
    public var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    public func contrastRatio(against other: ThemeColor) -> Double {
        let a = relativeLuminance + 0.05
        let b = other.relativeLuminance + 0.05
        return max(a, b) / min(a, b)
    }
}

/// Built-in sounds: the free accordion ships four looped reed roots. Other
/// slots belong to optional packs and fall back to the synth ("" name).
public struct BuiltinAudioAssets: AudioAssetProviding, Sendable {
    public init() {}

    public func sampleName(_ slot: SampleSlot) -> String {
        switch slot {
        case .accordionReedC3: return "hl_builtin_accordion_C3_reed"
        case .accordionReedG3: return "hl_builtin_accordion_G3_reed"
        case .accordionReedC4: return "hl_builtin_accordion_C4_reed"
        case .accordionReedG4: return "hl_builtin_accordion_G4_reed"
        case .guitarPluckE2, .filterNoise, .thereminSine: return ""
        }
    }

    public func sampleFileExtension(_ slot: SampleSlot) -> String { "caf" }
}
