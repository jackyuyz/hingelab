import Foundation
import HingeInput
import MIDIOut

public enum AudioBufferMode: String, Codable, Sendable, CaseIterable {
    case lowLatency
    case normal

    public var frames: Int {
        switch self {
        case .lowLatency: return 128
        case .normal: return 256
        }
    }
}

public enum ScaleMode: String, Codable, Sendable, CaseIterable {
    case off
    case chromatic
    case major
    case minor
    case pentatonic

    /// Quantize a MIDI note number onto this scale. `off` leaves it continuous.
    public func quantize(_ midiNote: Double) -> Double {
        switch self {
        case .off:
            return midiNote
        case .chromatic:
            return midiNote.rounded()
        case .major:
            return quantize(midiNote, intervals: [0, 2, 4, 5, 7, 9, 11])
        case .minor:
            return quantize(midiNote, intervals: [0, 2, 3, 5, 7, 8, 10])
        case .pentatonic:
            return quantize(midiNote, intervals: [0, 2, 4, 7, 9])
        }
    }

    private func quantize(_ midiNote: Double, intervals: [Int]) -> Double {
        let nearest = midiNote.rounded()
        let pc = Int(nearest) %% 12
        var best = nearest
        var bestDist = 12.0
        for oct in -1...1 {
            for interval in intervals {
                let candidate = Double((Int(nearest) - pc) + interval + oct * 12)
                let dist = abs(candidate - midiNote)
                if dist < bestDist {
                    bestDist = dist
                    best = candidate
                }
            }
        }
        return best
    }
}

infix operator %% : MultiplicationPrecedence
private func %% (left: Int, right: Int) -> Int {
    let r = left % right
    return r >= 0 ? r : r + right
}

public struct UserSettings: Codable, Equatable, Sendable {
    public var audioBuffer: AudioBufferMode
    public var pitchBendRangeSemitones: Double
    public var scale: ScaleMode
    public var a4Hz: Double
    public var hapticsEnabled: Bool
    public var leftHanded: Bool
    public var calibration: HingeCalibration
    public var midiMapping: MIDIMapping
    public var languageCode: String
    public var splitAxesHorizontal: Bool

    public init(
        audioBuffer: AudioBufferMode = .lowLatency,
        pitchBendRangeSemitones: Double = 2,
        scale: ScaleMode = .off,
        a4Hz: Double = 440,
        hapticsEnabled: Bool = true,
        leftHanded: Bool = false,
        calibration: HingeCalibration = .unverifiedDefault,
        midiMapping: MIDIMapping = MIDIMapping(),
        languageCode: String = "en",
        splitAxesHorizontal: Bool = true
    ) {
        self.audioBuffer = audioBuffer
        self.pitchBendRangeSemitones = pitchBendRangeSemitones
        self.scale = scale
        self.a4Hz = a4Hz
        self.hapticsEnabled = hapticsEnabled
        self.leftHanded = leftHanded
        self.calibration = calibration
        self.midiMapping = midiMapping
        self.languageCode = languageCode
        self.splitAxesHorizontal = splitAxesHorizontal
    }

    public static let `default` = UserSettings()
}

public protocol SettingsStoring: Sendable {
    func load() -> UserSettings
    func save(_ settings: UserSettings)
}

public final class MemorySettingsStore: SettingsStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var settings: UserSettings

    public init(_ settings: UserSettings = .default) {
        self.settings = settings
    }

    public func load() -> UserSettings {
        lock.lock(); defer { lock.unlock() }
        return settings
    }

    public func save(_ settings: UserSettings) {
        lock.lock()
        self.settings = settings
        lock.unlock()
    }
}

public final class UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    public static let key = "hingelab.userSettings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> UserSettings {
        guard let data = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: UserSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
