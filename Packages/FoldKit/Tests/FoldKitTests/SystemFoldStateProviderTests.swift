import Testing
import Foundation
@testable import FoldKit

@Suite("SystemFoldStateProvider Tests")
struct SystemFoldStateProviderTests {

    @Test("Initial state defaults to noHinge")
    func testDefaultInitialState() {
        let provider = SystemFoldStateProvider()
        #expect(provider.state.posture == .noHinge)
    }

    @Test("updateState() updates state")
    func testUpdateState() {
        let provider = SystemFoldStateProvider()
        provider.updateState(FoldState(posture: .partiallyOpen, angleDegrees: 90))
        #expect(provider.state.posture == .partiallyOpen)
        #expect(provider.state.angleDegrees == 90)
    }

    @Test("states() yields current value, then every change")
    func testStatesStream() async {
        let provider = SystemFoldStateProvider(initialState: FoldState(posture: .closed, angleDegrees: 0))
        var iterator = provider.states().makeAsyncIterator()

        let first = await iterator.next()
        #expect(first?.posture == .closed)

        provider.updateState(FoldState(posture: .fullyOpen, angleDegrees: 180))
        let second = await iterator.next()
        #expect(second?.posture == .fullyOpen)
        #expect(second?.angleDegrees == 180)
    }
}
