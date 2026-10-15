import Foundation

/// Pure motion math behind the instrument visuals, kept here so it is tested
/// on Linux. Views only turn these numbers into shapes.
public enum InstrumentMotion {
    /// Matches the audio close release (AudioConstants.closeReleaseSeconds).
    public static let closeReleaseSeconds = 0.2

    /// Bellows pleat edges along the bellows axis, 0…1. The bellows fills
    /// 30 % of its track when shut and all of it when fully drawn, centred.
    public static func bellowsPleatEdges(openness: Double, pleats: Int) -> [Double] {
        let count = max(1, pleats)
        let o = clamp01(openness)
        let span = 0.3 + 0.7 * o
        let start = (1 - span) / 2
        return (0...count).map { start + span * Double($0) / Double(count) }
    }

    /// 0…1 bellows "pressure" glow from hinge speed. Matches the audio rest
    /// threshold (2°/s) so the visual is dark exactly when the sound is.
    public static func bellowsPressure(velocityDegPerSec: Double, restThreshold: Double = 2, scale: Double = 180) -> Double {
        let speed = abs(velocityDegPerSec)
        guard speed >= restThreshold else { return 0 }
        return min(1, speed / scale)
    }

    /// Spark particles per second from hinge speed. 0 at rest, 48 at 240°/s.
    public static func sparkRate(velocityDegPerSec: Double, reduceMotion: Bool = false) -> Double {
        guard !reduceMotion else { return 0 }
        let speed = abs(velocityDegPerSec)
        guard speed >= 2 else { return 0 }
        return min(48, speed / 240 * 48)
    }

    /// Needle position 0…1 on a dial that reads 0…`maximum` degrees.
    public static func gaugeFraction(angleDegrees: Double?, maximum: Double = 180) -> Double {
        guard let angle = angleDegrees else { return 0 }
        return clamp01(angle / max(maximum, 1))
    }

    public struct Tick: Equatable, Sendable {
        public var degrees: Double
        public var isMajor: Bool
    }

    /// Dial ticks every `minor` degrees, major every `major`.
    public static func gaugeTicks(maximum: Double = 180, major: Double = 30, minor: Double = 10) -> [Tick] {
        stride(from: 0.0, through: maximum, by: minor).map { degrees in
            Tick(degrees: degrees, isMajor: degrees.truncatingRemainder(dividingBy: major) == 0)
        }
    }

    /// Filter bloom 0…1 on the same exponential scale as the cutoff mapping
    /// (20 Hz…20 kHz), so the visual moves evenly with the hinge.
    public static func bloom(cutoffHz: Double, minHz: Double = 20, maxHz: Double = 20_000) -> Double {
        guard cutoffHz > 0 else { return 0 }
        return clamp01(log(cutoffHz / minHz) / log(maxHz / minHz))
    }

    /// Theremin glow position 0…1 along the antenna (log pitch C3…C6) and
    /// intensity from volume.
    public static func thereminGlow(frequencyHz: Double?, amplitude: Double, lowHz: Double = 130.81, highHz: Double = 1_046.5) -> (position: Double, intensity: Double) {
        guard let hz = frequencyHz, hz > 0 else { return (0, 0) }
        let position = clamp01(log(hz / lowHz) / log(highHz / lowHz))
        return (position, clamp01(amplitude))
    }

    /// String displacement envelope after a pluck: fast decay, matches a
    /// short visual "ring" (~0.6 s), frozen at 0 with Reduce Motion.
    public static func stringVibration(secondsSincePluck: Double, velocity: Double, reduceMotion: Bool = false) -> Double {
        guard !reduceMotion, secondsSincePluck >= 0 else { return 0 }
        return clamp01(velocity) * exp(-secondsSincePluck / 0.18)
    }

    /// Pitch-bend string offset −1…1 from semitones and the configured range.
    public static func bendOffset(semitones: Double, range: Double) -> Double {
        guard range > 0 else { return 0 }
        return max(-1, min(1, semitones / range))
    }

    /// Scope trace: a few cycles of the current voice shape, amplitude-scaled.
    /// `shape` 0 = sine … 1 = saw-like, so each instrument draws its own trace.
    public static func scopeTrace(points: Int, cycles: Double, amplitude: Double, shape: Double, phase: Double) -> [Double] {
        let n = max(2, points)
        let a = clamp01(amplitude)
        let s = clamp01(shape)
        return (0..<n).map { i in
            let t = Double(i) / Double(n - 1) * cycles + phase
            let frac = t - floor(t)
            let sine = sin(2 * Double.pi * t)
            let saw = 2 * frac - 1
            return a * ((1 - s) * sine + s * saw)
        }
    }

    @inline(__always)
    static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
}
