import Testing
import Foundation
@testable import FoldKit

@Suite("FoldState Tests")
struct FoldStateTests {
    
    @Test("FoldState initializes with posture, angle, and timestamp")
    func testInitialization() {
        let now = Date()
        let state = FoldState(posture: .partiallyOpen, angleDegrees: 90.0, timestamp: now)
        
        #expect(state.posture == .partiallyOpen)
        #expect(state.angleDegrees == 90.0)
        #expect(state.timestamp == now)
    }
    
    @Test("FoldState.noHinge constant is properly configured")
    func testNoHingeConstant() {
        let state = FoldState.noHinge
        
        #expect(state.posture == .noHinge)
        #expect(state.angleDegrees == nil)
        #expect(state.timestamp == .distantPast)
        #expect(state.hasHinge == false)
    }
    
    @Test("hasHinge reflects posture correctly")
    func testHasHinge() {
        let noHingeState = FoldState(posture: .noHinge, angleDegrees: nil)
        let closedState = FoldState(posture: .closed, angleDegrees: 0)
        let openState = FoldState(posture: .fullyOpen, angleDegrees: 180)
        
        #expect(noHingeState.hasHinge == false)
        #expect(closedState.hasHinge == true)
        #expect(openState.hasHinge == true)
    }
    
    @Test("FoldState is Equatable")
    func testEquatable() {
        let timestamp = Date()
        let state1 = FoldState(posture: .partiallyOpen, angleDegrees: 90.0, timestamp: timestamp)
        let state2 = FoldState(posture: .partiallyOpen, angleDegrees: 90.0, timestamp: timestamp)
        let state3 = FoldState(posture: .fullyOpen, angleDegrees: 180.0, timestamp: timestamp)
        
        #expect(state1 == state2)
        #expect(state1 != state3)
    }
    
    @Test("FoldState is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = FoldState(posture: .partiallyOpen, angleDegrees: 95.5, timestamp: Date())
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FoldState.self, from: data)
        
        #expect(decoded.posture == original.posture)
        #expect(decoded.angleDegrees == original.angleDegrees)
        // Timestamps may have slight precision differences
        #expect(abs(decoded.timestamp.timeIntervalSince1970 - original.timestamp.timeIntervalSince1970) < 0.001)
    }
    
    @Test("FoldState with nil angle is Codable")
    func testCodableNilAngle() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = FoldState(posture: .noHinge, angleDegrees: nil, timestamp: Date())
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FoldState.self, from: data)
        
        #expect(decoded.posture == original.posture)
        #expect(decoded.angleDegrees == nil)
    }
}
