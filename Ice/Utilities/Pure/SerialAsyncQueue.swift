//
//  SerialAsyncQueue.swift
//  Ice
//

/// Runs async operations one after the other, in the order they were submitted.
///
/// On the main actor each `await` lets another task run, so two clicks handled
/// by separate tasks would interleave their steps. Submitting them here makes
/// the second wait for the first to finish.
@MainActor
final class SerialAsyncQueue {
    private var tail: Task<Void, Never>?

    func run<T: Sendable>(_ operation: @escaping @MainActor () async -> T) async -> T {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            return await operation()
        }
        tail = Task { @MainActor in
            _ = await task.value
        }
        return await task.value
    }
}
