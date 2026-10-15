import Foundation

extension L10nKey {
    /// Fills each `%@` in order. Keeps translators free to move the argument.
    public func text(in language: AppLanguage, _ arguments: String...) -> String {
        var result = text(in: language)
        for argument in arguments {
            guard let range = result.range(of: "%@") else { break }
            result.replaceSubrange(range, with: argument)
        }
        return result
    }
}

/// Note names stay letter names in every language (spec §5).
public enum NoteName {
    private static let sharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    /// "C4" for MIDI 60.
    public static func name(midi: Int) -> String {
        let pitchClass = ((midi % 12) + 12) % 12
        let octave = Int((Double(midi) / 12).rounded(.down)) - 1
        return "\(sharps[pitchClass])\(octave)"
    }

    /// Letter without octave, "C♯".
    public static func letter(midi: Int) -> String {
        sharps[((midi % 12) + 12) % 12]
    }

    /// Nearest note and the offset in cents, for tuner-style readouts.
    public static func nearest(hz: Double, a4: Double = 440) -> (midi: Int, cents: Double) {
        guard hz > 0, a4 > 0 else { return (69, 0) }
        let exact = 69 + 12 * log2(hz / a4)
        let midi = Int(exact.rounded())
        return (midi, (exact - Double(midi)) * 100)
    }
}

/// Chord symbols such as "C", "Am", "Bb". Displayed as letters; spoken and
/// subtitled in the user's language ("C 大调", "A minor chord").
public struct ChordLabel: Equatable, Sendable {
    public enum Quality: Sendable { case major, minor }

    public var root: String
    public var quality: Quality

    public init(symbol: String) {
        var text = symbol.trimmingCharacters(in: .whitespaces)
        if text.hasSuffix("m") {
            quality = .minor
            text.removeLast()
        } else {
            quality = .major
        }
        root = text.replacingOccurrences(of: "b", with: "♭").replacingOccurrences(of: "#", with: "♯")
    }

    /// "C", "Am", "B♭" for the key face.
    public var symbol: String {
        quality == .minor ? root + "m" : root
    }

    /// "major" / "大调" subtitle.
    public func qualityName(in language: AppLanguage) -> String {
        (quality == .major ? L10nKey.chordMajor : L10nKey.chordMinor).text(in: language)
    }

    /// "C major chord" / "C 大调和弦" for VoiceOver.
    public func accessibilityLabel(in language: AppLanguage) -> String {
        (quality == .major ? L10nKey.chordA11yMajor : L10nKey.chordA11yMinor).text(in: language, root)
    }
}
