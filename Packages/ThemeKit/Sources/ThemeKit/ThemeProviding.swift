import Foundation

/// Semantic color tokens. Views never hardcode RGB; Claude Design fills the
/// real palette by swapping the theme provider.
public enum ColorToken: String, CaseIterable, Sendable {
    case stageBackground
    case surface
    case surfaceRaised
    case hairline
    /// Ink on top of an instrument hue (key labels on a lit key).
    case onHue
    case primaryText
    case secondaryText
    case creaseGuide
    case gauge
    case accordionHue
    case guitarHue
    case filterHue
    case thereminHue
    case lock
    case destructive
    case waveform
}

/// Asset catalog names. Drop files into `Assets.xcassets` using these names.
public enum ImageSlot: String, CaseIterable, Sendable {
    case appIcon
    case accordionBellows
    case accordionSkin
    case guitarFretboard
    case guitarSkin
    case filterSkin
    case thereminAntenna
    case thereminSkin
    case particleSpark
    case angleGaugeFace
    case waveformOverlay
    case paywallHero
}

public enum SymbolSlot: String, CaseIterable, Sendable {
    case accordion
    case guitar
    case filter
    case theremin
    case looper
    case midi
    case settings
    case lock
    case ribbon
    case calibrate
    case export
}

public enum AnimationSlot: String, CaseIterable, Sendable {
    case bellowsPulse
    case stringVibrate
    case filterBloom
    case thereminGlow
    case foldParticle
}

public struct ThemeColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var opacity: Double

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }
}

/// Views consume assets only through this protocol. Replacing PlaceholderTheme
/// with a designed theme must not require engine changes.
public protocol ThemeProviding: Sendable {
    var name: String { get }
    func color(_ token: ColorToken) -> ThemeColor
    /// Asset catalog name for a slot. Empty string means "not yet provided".
    func imageAssetName(_ slot: ImageSlot) -> String
    func systemImage(_ slot: SymbolSlot) -> String
    func animationName(_ slot: AnimationSlot) -> String
}

public struct PlaceholderTheme: ThemeProviding, Sendable {
    public let name = "placeholder"

    public init() {}

    public func color(_ token: ColorToken) -> ThemeColor {
        switch token {
        case .stageBackground: return ThemeColor(red: 0.07, green: 0.07, blue: 0.09)
        case .surface: return ThemeColor(red: 0.14, green: 0.14, blue: 0.16)
        case .surfaceRaised: return ThemeColor(red: 0.20, green: 0.20, blue: 0.22)
        case .hairline: return ThemeColor(red: 0.30, green: 0.30, blue: 0.33)
        case .onHue: return ThemeColor(red: 0.07, green: 0.07, blue: 0.09)
        case .primaryText: return ThemeColor(red: 0.96, green: 0.96, blue: 0.97)
        case .secondaryText: return ThemeColor(red: 0.70, green: 0.70, blue: 0.73)
        case .creaseGuide: return ThemeColor(red: 0.40, green: 0.40, blue: 0.45)
        case .gauge: return ThemeColor(red: 0.85, green: 0.85, blue: 0.88)
        case .accordionHue: return ThemeColor(red: 0.82, green: 0.22, blue: 0.22)
        case .guitarHue: return ThemeColor(red: 0.90, green: 0.62, blue: 0.18)
        case .filterHue: return ThemeColor(red: 0.18, green: 0.72, blue: 0.82)
        case .thereminHue: return ThemeColor(red: 0.62, green: 0.32, blue: 0.86)
        case .lock: return ThemeColor(red: 0.55, green: 0.55, blue: 0.58)
        case .destructive: return ThemeColor(red: 0.90, green: 0.25, blue: 0.20)
        case .waveform: return ThemeColor(red: 0.45, green: 0.85, blue: 0.55)
        }
    }

    public func imageAssetName(_ slot: ImageSlot) -> String {
        "placeholder.\(slot.rawValue)"
    }

    public func systemImage(_ slot: SymbolSlot) -> String {
        switch slot {
        case .accordion: return "rectangle.split.2x1"
        case .guitar: return "guitars"
        case .filter: return "slider.horizontal.3"
        case .theremin: return "waveform.path"
        case .looper: return "repeat"
        case .midi: return "cable.connector"
        case .settings: return "gearshape"
        case .lock: return "lock.fill"
        case .ribbon: return "line.3.horizontal"
        case .calibrate: return "angle"
        case .export: return "square.and.arrow.up"
        }
    }

    public func animationName(_ slot: AnimationSlot) -> String {
        "placeholder.animation.\(slot.rawValue)"
    }
}

public enum SampleSlot: String, CaseIterable, Sendable {
    case accordionReedC3
    case accordionReedG3
    case accordionReedC4
    case accordionReedG4
    case guitarPluckE2
    case filterNoise
    case thereminSine
}

extension SampleSlot {
    /// MIDI root of the recording, used when a file has no `inst` chunk.
    public var rootMIDINote: Double {
        switch self {
        case .accordionReedC3: return 48
        case .accordionReedG3: return 55
        case .accordionReedC4: return 60
        case .accordionReedG4: return 67
        case .guitarPluckE2: return 40
        case .filterNoise: return 48
        case .thereminSine: return 69
        }
    }

    public var isAccordionReed: Bool {
        switch self {
        case .accordionReedC3, .accordionReedG3, .accordionReedC4, .accordionReedG4: return true
        default: return false
        }
    }
}

public protocol AudioAssetProviding: Sendable {
    /// Bundle-relative sample name, without extension. Empty = synth fallback.
    func sampleName(_ slot: SampleSlot) -> String
    func sampleFileExtension(_ slot: SampleSlot) -> String
}

public struct PlaceholderAudioAssets: AudioAssetProviding, Sendable {
    public init() {}

    public func sampleName(_ slot: SampleSlot) -> String {
        "placeholder.\(slot.rawValue)"
    }

    public func sampleFileExtension(_ slot: SampleSlot) -> String { "caf" }
}
