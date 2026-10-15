import SwiftUI
import HingeL10n
import Instruments
import ThemeKit

extension ThemeColor {
    var swiftUI: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension ThemeProviding {
    /// SwiftUI color for a token.
    func ui(_ token: ColorToken) -> Color {
        color(token).swiftUI
    }
}

extension View {
    func hingelabStageBackground(_ theme: any ThemeProviding) -> some View {
        background(theme.color(.stageBackground).swiftUI.ignoresSafeArea())
    }
}

/// Type roles from the visual spec: SF Pro Rounded for instrument faces and
/// titles, monospaced digits for angle / Hz / BPM readouts.
enum StageFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func keyFace(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static let label = Font.system(.caption, design: .rounded).weight(.semibold)
    static let caption = Font.system(.caption2, design: .rounded)

    static func readout(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

/// Instrument surfaces stay a fixed size; their labels scale up to a limit.
extension View {
    func instrumentSurfaceTypeLimit() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    /// Small uppercase section label used on every instrument half.
    func stageLabelStyle(_ theme: any ThemeProviding) -> some View {
        font(StageFont.label)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(theme.ui(.secondaryText))
    }
}

extension InstrumentID {
    var hueToken: ColorToken {
        switch self {
        case .accordion: return .accordionHue
        case .pitchBendGuitar: return .guitarHue
        case .filterSweep: return .filterHue
        case .theremin: return .thereminHue
        }
    }

    var symbolSlot: SymbolSlot {
        switch self {
        case .accordion: return .accordion
        case .pitchBendGuitar: return .guitar
        case .filterSweep: return .filter
        case .theremin: return .theremin
        }
    }

    var titleKey: L10nKey {
        switch self {
        case .accordion: return .instrumentAccordion
        case .pitchBendGuitar: return .instrumentGuitar
        case .filterSweep: return .instrumentFilter
        case .theremin: return .instrumentTheremin
        }
    }

    var taglineKey: L10nKey {
        switch self {
        case .accordion: return .cardAccordion
        case .pitchBendGuitar: return .cardGuitar
        case .filterSweep: return .cardFilter
        case .theremin: return .cardTheremin
        }
    }

    /// Scope trace shape: 0 sine … 1 saw.
    var scopeShape: Double {
        switch self {
        case .accordion: return 0.75
        case .pitchBendGuitar: return 0.45
        case .filterSweep: return 0.9
        case .theremin: return 0.05
        }
    }
}
