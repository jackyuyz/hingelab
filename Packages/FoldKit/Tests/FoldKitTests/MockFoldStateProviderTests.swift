import Testing
import Foundation
@testable import FoldKit

@Suite("MockFoldStateProvider Tests")
struct MockFoldStateProviderTests {
    
    @Test("Initial state defaults to noHinge")
    func testDefaultInitialState() async {
        let provider = MockFoldStateProvider()
        let state = await provider.state
        #expect(state.posture == .noHinge)
    }
    
    @Test("Custom initial state is respected")
    func testCustomInitialState() async {
        let initialState = FoldState(posture: .fullyOpen, angleDegrees: 180)
        let provider = MockFoldStateProvider(initialState: initialState)
        let state = await provider.state
        #expect(state.posture == .fullyOpen)
        #expect(state.angleDegrees == 180)
    }
    
    @Test("set() updates state")
    func testSetState() async {
        let provider = MockFoldStateProvider()
        await provider.set(.partiallyOpen, angle: 90)
        let state = await provider.state
        #expect(state.posture == .partiallyOpen)
        #expect(state.angleDegrees == 90)
    }
    
    @Test("parseArgument handles 'nohinge'")
    func testParseNoHinge() {
        let result = MockFoldStateProvider.parseArgument("nohinge")
        #expect(result.posture == .noHinge)
        #expect(result.angle == nil)
        #expect(result.script == nil)
    }
    
    @Test("parseArgument handles 'closed'")
    func testParseClosed() {
        let result = MockFoldStateProvider.parseArgument("closed")
        #expect(result.posture == .closed)
        #expect(result.angle == 0)
        #expect(result.script == nil)
    }
    
    @Test("parseArgument handles 'open'")
    func testParseOpen() {
        let result = MockFoldStateProvider.parseArgument("open")
        #expect(result.posture == .fullyOpen)
        #expect(result.angle == 180)
        #expect(result.script == nil)
    }
    
    @Test("parseArgument handles 'half:<deg>'")
    func testParseHalf() {
        let result = MockFoldStateProvider.parseArgument("half:95")
        #expect(result.posture == .partiallyOpen)
        #expect(result.angle == 95)
        #expect(result.script == nil)
    }
    
    @Test("parseArgument handles 'sweep:<from>-<to>:<seconds>'")
    func testParseSweep() {
        let result = MockFoldStateProvider.parseArgument("sweep:10-180:6")
        #expect(result.posture == .partiallyOpen)
        #expect(result.angle == 10)
        #expect(result.script != nil)
        #expect(result.script!.count > 0)
    }
    
    @Test("parseArgument handles invalid input gracefully")
    func testParseInvalid() {
        let result = MockFoldStateProvider.parseArgument("invalid")
        #expect(result.posture == .noHinge)
        #expect(result.angle == nil)
        #expect(result.script == nil)
    }
    
    @Test("parseArgument is case-insensitive")
    func testParseCaseInsensitive() {
        let result1 = MockFoldStateProvider.parseArgument("NOHINGE")
        let result2 = MockFoldStateProvider.parseArgument("NoHinge")
        let result3 = MockFoldStateProvider.parseArgument("CLOSED")
        
        #expect(result1.posture == .noHinge)
        #expect(result2.posture == .noHinge)
        #expect(result3.posture == .closed)
    }
}

@Suite("FoldScriptStep Tests")
struct FoldScriptStepTests {
    
    @Test("FoldScriptStep initializes correctly")
    func testInitialization() {
        let step = FoldScriptStep(posture: .partiallyOpen, angleDegrees: 90, durationSeconds: 0.5)
        #expect(step.posture == .partiallyOpen)
        #expect(step.angleDegrees == 90)
        #expect(step.durationSeconds == 0.5)
    }
    
    @Test("sweep() generates correct number of steps")
    func testSweepStepCount() {
        let steps = FoldScriptStep.sweep(from: 0, to: 180, durationSeconds: 2, sampleRate: 30)
        // 2 seconds * 30 samples/second + 1 = 61 steps
        #expect(steps.count == 61)
    }
    
    @Test("sweep() generates correct angle progression")
    func testSweepAngleProgression() {
        let steps = FoldScriptStep.sweep(from: 0, to: 180, durationSeconds: 1, sampleRate: 10)
        
        // First step should be at 0
        #expect(steps.first?.angleDegrees == 0)
        
        // Last step should be at 180
        #expect(steps.last?.angleDegrees == 180)
        
        // Steps should be monotonically increasing
        for i in 1..<steps.count {
            #expect(steps[i].angleDegrees! >= steps[i-1].angleDegrees!)
        }
    }
    
    @Test("sweep() assigns correct postures based on angle")
    func testSweepPostures() {
        let steps = FoldScriptStep.sweep(from: 0, to: 180, durationSeconds: 1, sampleRate: 10)
        
        // First step (0°) should be closed
        #expect(steps.first?.posture == .closed)
        
        // Last step (180°) should be fullyOpen
        #expect(steps.last?.posture == .fullyOpen)
        
        // Middle steps should be partiallyOpen
        let middleSteps = steps.filter { $0.angleDegrees! > 10 && $0.angleDegrees! < 170 }
        for step in middleSteps {
            #expect(step.posture == .partiallyOpen)
        }
    }
    
    @Test("sweep() handles reverse direction")
    func testSweepReverse() {
        let steps = FoldScriptStep.sweep(from: 180, to: 0, durationSeconds: 1, sampleRate: 10)
        
        #expect(steps.first?.angleDegrees == 180)
        #expect(steps.last?.angleDegrees == 0)
        
        // Steps should be monotonically decreasing
        for i in 1..<steps.count {
            #expect(steps[i].angleDegrees! <= steps[i-1].angleDegrees!)
        }
    }
    
    @Test("FoldScriptStep is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = FoldScriptStep(posture: .partiallyOpen, angleDegrees: 90, durationSeconds: 0.5)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FoldScriptStep.self, from: data)
        
        #expect(decoded.posture == original.posture)
        #expect(decoded.angleDegrees == original.angleDegrees)
        #expect(decoded.durationSeconds == original.durationSeconds)
    }
}

@Suite("MockFoldStateProvider synchronous state")
struct MockFoldStateProviderSyncStateTests {
    @Test("state is readable synchronously from the main actor and tracks set()")
    @MainActor
    func syncReadFromMainActor() async {
        let provider = MockFoldStateProvider(initialState: FoldState(posture: .closed, angleDegrees: 0))
        #expect(provider.state.posture == .closed)
        await provider.set(.fullyOpen, angle: 180)
        #expect(provider.state.posture == .fullyOpen)
        #expect(provider.state.angleDegrees == 180)
    }
}
