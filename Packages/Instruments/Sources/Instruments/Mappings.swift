import Foundation
import MIDIOut
import SettingsKit

public enum PitchMapping {
    /// Map 0…1 through ±range semitones. Center is 0.
    public static func semitones(value01: Double, range: Double) -> Double {
        let v = min(1, max(0, value01))
        return (v - 0.5) * 2 * range
    }

    public static func midi14(value01: Double) -> UInt16 {
        MIDIEncoder.pitchBend14(value01: value01)
    }

    public static func centsError(actualSemitones: Double, expectedSemitones: Double) -> Double {
        (actualSemitones - expectedSemitones) * 100
    }
}

public enum FilterMapping {
    public static func cutoffHz(value01: Double, minHz: Double = 20, maxHz: Double = 20_000) -> Double {
        let v = min(1, max(0, value01))
        return minHz * pow(maxHz / minHz, v)
    }

    public static func resonance(velocityDegPerSec: Double, scale: Double = 360) -> Double {
        min(1, abs(velocityDegPerSec) / max(scale, 1))
    }
}

public enum AccordionMapping {
    /// Bellows pressure from open/close speed. Rest is silence.
    public static func pressure(velocityDegPerSec: Double, restThreshold: Double = 2, scale: Double = 180) -> Double {
        let speed = abs(velocityDegPerSec)
        if speed < restThreshold { return 0 }
        return min(1, speed / scale)
    }

    public static func isDirectionChange(previous: Double, current: Double) -> Bool {
        previous != 0 && current != 0 && previous.sign != current.sign
    }
}

public enum ThereminMapping {
    public static func midiNote(value01: Double, minNote: Double = 48, maxNote: Double = 84) -> Double {
        let v = min(1, max(0, value01))
        return minNote + v * (maxNote - minNote)
    }

    public static func frequencyHz(
        value01: Double,
        minNote: Double = 48,
        maxNote: Double = 84,
        a4: Double = 440,
        scale: ScaleMode = .off
    ) -> Double {
        let midi = scale.quantize(midiNote(value01: value01, minNote: minNote, maxNote: maxNote))
        return midiToHz(midi, a4: a4)
    }

    public static func midiToHz(_ midi: Double, a4: Double = 440) -> Double {
        a4 * pow(2.0, (midi - 69.0) / 12.0)
    }
}

public enum GuitarLayout {
    public static let stringCount = 6
    public static let chordCount = 8
    public static let defaultChords: [UInt8] = [40, 45, 50, 55, 59, 64, 48, 52]
}

public enum AccordionLayout {
    public static let leftChords: [(name: String, root: UInt8)] = [
        ("C", 48), ("G", 43), ("F", 41), ("Am", 45),
        ("Dm", 50), ("Em", 40), ("Bb", 46), ("D", 50)
    ]
    public static let melodyRows = 2
    public static let melodyColumns = 6
    public static let melodyStart: UInt8 = 60
}
