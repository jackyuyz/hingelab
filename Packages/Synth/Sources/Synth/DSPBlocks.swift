import Foundation

// Realtime-safe building blocks for the designed patches. Value types, no
// allocations after init, no locks.

/// PolyBLEP residual that removes most aliasing from naive saw/pulse edges.
@inline(__always)
func polyBLEP(_ t: Double, _ dt: Double) -> Double {
    guard dt > 0 else { return 0 }
    if t < dt {
        let x = t / dt
        return x + x - x * x - 1
    }
    if t > 1 - dt {
        let x = (t - 1) / dt
        return x * x + x + x + 1
    }
    return 0
}

/// Cheap tanh-like soft clipper. Transparent below ~0.5, saturates toward ±1.
@inline(__always)
public func softClip(_ x: Double) -> Double {
    let c = min(3, max(-3, x))
    return c * (27 + c * c) / (27 + 9 * c * c)
}

/// Band-limited saw and pulse that share one phase.
public struct BLEPOscillator: Sendable, Equatable {
    public var phase: Double

    public init(phase: Double = 0) {
        self.phase = phase
    }

    /// Returns (saw, pulse) for the current phase and advances.
    public mutating func sawAndPulse(frequencyHz: Double, sampleRate: Double, width: Double = 0.5) -> (saw: Double, pulse: Double) {
        let dt = min(0.5, max(0, frequencyHz / max(sampleRate, 1)))
        let t = phase
        var saw = 2 * t - 1
        saw -= polyBLEP(t, dt)
        let w = min(0.95, max(0.05, width))
        var pulse = t < w ? 1.0 : -1.0
        pulse += polyBLEP(t, dt)
        var shifted = t + 1 - w
        if shifted >= 1 { shifted -= 1 }
        pulse -= polyBLEP(shifted, dt)
        phase += dt
        if phase >= 1 { phase -= 1 }
        return (saw, pulse)
    }

    public mutating func saw(frequencyHz: Double, sampleRate: Double) -> Double {
        sawAndPulse(frequencyHz: frequencyHz, sampleRate: sampleRate).saw
    }
}

/// Zero-delay-feedback (TPT) state-variable filter. Stable for any cutoff
/// below Nyquist and any Q > 0.
public struct StateVariableFilter: Sendable, Equatable {
    private var ic1 = 0.0
    private var ic2 = 0.0

    public init() {}

    public struct Output: Sendable {
        public var low: Double
        public var band: Double
        public var high: Double
    }

    public mutating func process(_ x: Double, cutoffHz: Double, q: Double, sampleRate: Double) -> Output {
        let sr = max(sampleRate, 1)
        let fc = min(max(cutoffHz, 10), sr * 0.45)
        let g = tan(Double.pi * fc / sr)
        let k = 1 / max(q, 0.05)
        let a1 = 1 / (1 + g * (g + k))
        let a2 = g * a1
        let a3 = g * a2
        let v3 = x - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        return Output(low: v2, band: v1, high: x - k * v1 - v2)
    }

    public mutating func reset() {
        ic1 = 0
        ic2 = 0
    }
}

/// One-pole low-pass for tone shaping.
public struct OnePoleLowPass: Sendable, Equatable {
    private var state = 0.0

    public init() {}

    public mutating func process(_ x: Double, cutoffHz: Double, sampleRate: Double) -> Double {
        let coeff = 1 - exp(-2 * Double.pi * max(cutoffHz, 1) / max(sampleRate, 1))
        state += coeff * (x - state)
        return state
    }
}

/// Removes DC offset left by asymmetric waveshaping or KS excitation.
public struct DCBlocker: Sendable, Equatable {
    private var x1 = 0.0
    private var y1 = 0.0
    public var r: Double

    public init(r: Double = 0.995) {
        self.r = r
    }

    public mutating func process(_ x: Double) -> Double {
        let y = x - x1 + r * y1
        x1 = x
        y1 = y
        return y
    }
}
