//
//  SerialAsyncQueue.swift
//  Ice
//

/// Runs async operations one after the other, in the order they were submitted.
///
/// On the main actor each `await` lets another task run, so two clicks handled
/// by separate tasks would interleave their steps. Submitting them here makes
/// the second wait for the first to finish.
///
/// An operation has a deadline: past ``timeout`` the next one goes on (the slow
/// one is not cancelled, since a move must run to completion) and
/// ``onTimeout`` is called, so one stuck app can't freeze every later click.
@MainActor
final class SerialAsyncQueue {
    private var tail: Task<Void, Never>?
    private let timeout: Duration
    private let onTimeout: @MainActor () -> Void

    init(timeout: Duration = .seconds(5), onTimeout: @escaping @MainActor () -> Void = {}) {
        self.timeout = timeout
        self.onTimeout = onTimeout
    }

    func run<T: Sendable>(_ operation: @escaping @MainActor () async -> T) async -> T {
        let previous = tail
        let signal = Signal()
        let timeout = timeout
        let onTimeout = onTimeout
        let task = Task { @MainActor in
            await previous?.value
            // The deadline counts from when this operation starts, not from
            // when it was queued.
            let timer = Task { @MainActor in
                try? await Task.sleep(for: timeout)
                if signal.fire() {
                    onTimeout()
                }
            }
            let result = await operation()
            timer.cancel()
            signal.fire()
            return result
        }
        tail = Task { @MainActor in
            await signal.wait()
        }
        return await task.value
    }

    /// Lets the next operation go on as soon as the current one finishes or
    /// runs out of time, whichever comes first.
    @MainActor
    private final class Signal {
        private var fired = false
        private var waiters = [CheckedContinuation<Void, Never>]()

        /// Returns `true` only for the first call.
        @discardableResult
        func fire() -> Bool {
            guard !fired else {
                return false
            }
            fired = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
            return true
        }

        func wait() async {
            if fired {
                return
            }
            await withCheckedContinuation { waiters.append($0) }
        }
    }
}
