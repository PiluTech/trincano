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
/// An operation has a deadline: past ``timeout`` the next one goes on,
/// ``onTimeout`` is called and the slow operation is cancelled (cooperatively:
/// it must check `Task.isCancelled` at the boundaries of its steps and stop
/// before changing shared state), so one stuck app can't freeze every later
/// click nor leave a late operation racing the next one.
@MainActor
final class SerialAsyncQueue {
    private var tail: Task<Void, Never>?
    private let timeout: Duration
    private let onTimeout: @MainActor () -> Void
    private let sleep: @Sendable (Duration) async -> Void

    /// - Parameter sleep: Waits for the deadline; replaced in tests so they
    ///   don't depend on wall-clock time.
    init(
        timeout: Duration = .seconds(5),
        onTimeout: @escaping @MainActor () -> Void = {},
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.timeout = timeout
        self.onTimeout = onTimeout
        self.sleep = sleep
    }

    func run<T: Sendable>(_ operation: @escaping @MainActor () async -> T) async -> T {
        let previous = tail
        let signal = Signal()
        let timeout = timeout
        let onTimeout = onTimeout
        let sleep = sleep
        let handle = TaskHandle()
        let task = Task { @MainActor in
            await previous?.value
            // The deadline counts from when this operation starts, not from
            // when it was queued.
            let timer = Task { @MainActor in
                await sleep(timeout)
                guard !Task.isCancelled else {
                    return
                }
                if signal.fire() {
                    handle.cancel?()
                    onTimeout()
                }
            }
            let result = await operation()
            timer.cancel()
            signal.fire()
            return result
        }
        handle.cancel = { task.cancel() }
        tail = Task { @MainActor in
            await signal.wait()
        }
        return await task.value
    }

    /// Lets the deadline timer reach the operation's own task.
    @MainActor
    private final class TaskHandle {
        var cancel: (() -> Void)?
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
