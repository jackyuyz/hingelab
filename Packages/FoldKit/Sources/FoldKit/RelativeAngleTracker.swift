import Foundation

/// Converts noisy absolute angles into a stable 0…1 control value.
/// Used for smooth hinge interactions and progress tracking.
public struct RelativeAngleTracker: Sendable {
    /// The anchor angle set when the interaction starts
    public var anchorDegrees: Double?
    
    /// Minimum angle observed during tracking
    public var observedMin: Double
    
    /// Maximum angle observed during tracking
    public var observedMax: Double
    
    /// EMA (Exponential Moving Average) smoothing factor; animate between samples
    public var smoothing: Double
    
    /// Last smoothed value
    private var lastSmoothedValue: Double?
    
    public init(smoothing: Double = 0.25) {
        self.smoothing = smoothing
        self.observedMin = .infinity
        self.observedMax = -.infinity
    }
    
    /// Begin tracking from a specific angle
    public mutating func begin(at degrees: Double) {
        anchorDegrees = degrees
        observedMin = degrees
        observedMax = degrees
        lastSmoothedValue = nil
    }
    
    /// Update with a new angle reading and return normalized progress 0…1
    ///
    /// The progress is based on the observed range during this tracking session.
    /// Returns 0 at observedMin and 1 at observedMax.
    public mutating func update(_ degrees: Double) -> Double {
        // Update observed range
        observedMin = min(observedMin, degrees)
        observedMax = max(observedMax, degrees)
        
        // Calculate raw progress
        let range = observedMax - observedMin
        let rawProgress: Double
        if range > 0 {
            rawProgress = (degrees - observedMin) / range
        } else {
            rawProgress = 0.5
        }
        
        // Apply smoothing
        let smoothed: Double
        if let last = lastSmoothedValue {
            smoothed = last + smoothing * (rawProgress - last)
        } else {
            smoothed = rawProgress
        }
        lastSmoothedValue = smoothed
        
        return max(0, min(1, smoothed))
    }
    
    /// Calculate signed degrees since anchor
    public func delta(_ degrees: Double) -> Double {
        guard let anchor = anchorDegrees else { return 0 }
        return degrees - anchor
    }
    
    /// Reset the tracker
    public mutating func reset() {
        anchorDegrees = nil
        observedMin = .infinity
        observedMax = -.infinity
        lastSmoothedValue = nil
    }
    
    /// The observed range of angles
    public var observedRange: ClosedRange<Double>? {
        guard observedMin.isFinite && observedMax.isFinite && observedMin <= observedMax else {
            return nil
        }
        return observedMin...observedMax
    }
}
