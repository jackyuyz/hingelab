import Foundation

/// Protocol for providing fold state updates.
/// Feature code depends on this protocol, never on the concrete implementation.
/// This enables testing without a real device.
public protocol FoldStateProvider: AnyObject, Sendable {
    /// The current fold state
    var state: FoldState { get }
    
    /// Yields the current value immediately, then every change.
    func states() -> AsyncStream<FoldState>
}

/// Actor-isolated fold state provider for thread-safe access.
/// This is the base class for concrete implementations.
public actor FoldStateProviderBase {
    private var _state: FoldState
    private var continuations: [UUID: AsyncStream<FoldState>.Continuation] = [:]
    
    public init(initialState: FoldState = .noHinge) {
        self._state = initialState
    }
    
    public var state: FoldState {
        _state
    }
    
    public func updateState(_ newState: FoldState) {
        _state = newState
        for continuation in continuations.values {
            continuation.yield(newState)
        }
    }
    
    public func states() -> AsyncStream<FoldState> {
        let currentState = _state
        return AsyncStream { continuation in
            let id = UUID()
            continuation.yield(currentState)
            Task { [weak self] in
                await self?.addContinuation(id: id, continuation: continuation)
            }
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }
    
    private func addContinuation(id: UUID, continuation: AsyncStream<FoldState>.Continuation) {
        continuations[id] = continuation
    }
    
    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
