import Testing
import Foundation
@testable import FoldKit

@Suite("RelativeAngleTracker Tests")
struct RelativeAngleTrackerTests {
    
    @Test("Initial state has no anchor or range")
    func testInitialState() {
        let tracker = RelativeAngleTracker()
        #expect(tracker.anchorDegrees == nil)
        #expect(tracker.observedRange == nil)
    }
    
    @Test("begin() sets anchor and initializes range")
    func testBegin() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90)
        
        #expect(tracker.anchorDegrees == 90)
        #expect(tracker.observedMin == 90)
        #expect(tracker.observedMax == 90)
        #expect(tracker.observedRange == 90...90)
    }
    
    @Test("update() expands observed range")
    func testUpdateExpandsRange() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90)
        
        _ = tracker.update(60)
        #expect(tracker.observedMin == 60)
        #expect(tracker.observedMax == 90)
        
        _ = tracker.update(120)
        #expect(tracker.observedMin == 60)
        #expect(tracker.observedMax == 120)
        
        #expect(tracker.observedRange == 60...120)
    }
    
    @Test("update() returns normalized progress 0...1")
    func testUpdateReturnsNormalizedProgress() {
        var tracker = RelativeAngleTracker(smoothing: 1.0) // No smoothing for predictable results
        tracker.begin(at: 0)
        
        // At min (0°) should be 0
        let progressAtMin = tracker.update(0)
        #expect(progressAtMin >= 0 && progressAtMin <= 1)
        
        // Expand range and test
        _ = tracker.update(180)  // Establishes max at 180
        let progressAtMax = tracker.update(180)
        #expect(progressAtMax == 1.0)
        
        // Middle should be around 0.5
        let progressAtMiddle = tracker.update(90)
        #expect(progressAtMiddle == 0.5)
    }
    
    @Test("delta() returns signed difference from anchor")
    func testDelta() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90)
        
        #expect(tracker.delta(90) == 0)
        #expect(tracker.delta(100) == 10)
        #expect(tracker.delta(80) == -10)
        #expect(tracker.delta(180) == 90)
        #expect(tracker.delta(0) == -90)
    }
    
    @Test("delta() returns 0 when no anchor")
    func testDeltaWithoutAnchor() {
        let tracker = RelativeAngleTracker()
        #expect(tracker.delta(90) == 0)
    }
    
    @Test("reset() clears all state")
    func testReset() {
        var tracker = RelativeAngleTracker()
        tracker.begin(at: 90)
        _ = tracker.update(60)
        _ = tracker.update(120)
        
        tracker.reset()
        
        #expect(tracker.anchorDegrees == nil)
        #expect(tracker.observedRange == nil)
    }
    
    @Test("smoothing affects update results")
    func testSmoothing() {
        // Low smoothing (0.1) - slower response
        var lowSmooth = RelativeAngleTracker(smoothing: 0.1)
        lowSmooth.begin(at: 0)
        _ = lowSmooth.update(100)  // Establish range
        let lowResult = lowSmooth.update(100)
        
        // High smoothing (1.0) - immediate response
        var highSmooth = RelativeAngleTracker(smoothing: 1.0)
        highSmooth.begin(at: 0)
        _ = highSmooth.update(100)
        let highResult = highSmooth.update(100)
        
        // With high smoothing, we should reach 1.0 faster
        #expect(highResult >= lowResult)
    }
    
    @Test("observedRange returns nil for invalid ranges")
    func testObservedRangeInvalid() {
        let tracker = RelativeAngleTracker()
        // Before any tracking, min is +infinity, max is -infinity
        #expect(tracker.observedRange == nil)
    }
}
