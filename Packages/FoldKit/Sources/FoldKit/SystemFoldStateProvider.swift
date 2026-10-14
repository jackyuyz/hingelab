import Foundation

/// Production provider. Fed by the app's hinge bridge, attached once at the root of every scene.
///
/// State is guarded by a lock so `state` can be read synchronously from any context.
public final class SystemFoldStateProvider: FoldStateProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _state: FoldState
    private var continuations: [UUID: AsyncStream<FoldState>.Continuation] = [:]

    public init(initialState: FoldState = .noHinge) {
        self._state = initialState
    }

    public var state: FoldState {
        lock.withLock { _state }
    }

    public func states() -> AsyncStream<FoldState> {
        AsyncStream { continuation in
            let id = UUID()
            let currentState = lock.withLock {
                continuations[id] = continuation
                return _state
            }
            continuation.yield(currentState)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id: id)
            }
        }
    }

    /// Store a new state and fan it out to every active stream.
    public func updateState(_ newState: FoldState) {
        let active = lock.withLock {
            _state = newState
            return Array(continuations.values)
        }
        for continuation in active {
            continuation.yield(newState)
        }
    }

    private func removeContinuation(id: UUID) {
        lock.withLock {
            _ = continuations.removeValue(forKey: id)
        }
    }
}
