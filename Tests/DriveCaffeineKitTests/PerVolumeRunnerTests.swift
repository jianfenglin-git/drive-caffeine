import XCTest
@testable import DriveCaffeineKit

final class PerVolumeRunnerTests: XCTestCase {

    // The in-flight guard: while a poke is running, a second tick is dropped and
    // counted — it does NOT queue up behind the slow poke (eng review Issue 2).
    //
    // Cross-thread gating uses DispatchSemaphore, NOT XCTest expectations. An
    // XCTestExpectation is auto-tracked and is meant to be waited on from the
    // *test* thread; using one as a gate that a background poke blocks on is
    // racy — on a loaded CI runner the background thread can be descheduled
    // right after fulfilling "started" and before it reaches its wait, so the
    // test finishes first and XCTest's teardown flags the gate as an "unwaited
    // expectation" (the observed CI flake). Semaphores have no such teardown
    // coupling and make the hand-off deterministic.
    func testInFlightGuardSkipsOverlappingTick() {
        let runner = PerVolumeRunner(label: "test", pokeTimeout: 5)
        let firstStarted = DispatchSemaphore(value: 0)   // first poke is now running
        let release = DispatchSemaphore(value: 0)        // let the first poke finish
        let firstFinished = DispatchSemaphore(value: 0)  // background thread fully done
        let pokeCount = Counter()

        // First tick on a background thread: signal it started, then block
        // (still "in flight") until the test releases it.
        DispatchQueue.global().async {
            runner.runTick(poke: {
                pokeCount.increment()
                firstStarted.signal()
                release.wait()                 // hold the poke in flight
                return .init(action: .ok, ranModes: .read)
            }, report: { _ in })
            firstFinished.signal()
        }

        // Wait until the first poke is actually executing before firing the second.
        XCTAssertEqual(firstStarted.wait(timeout: .now() + 5), .success,
                       "first poke should start")

        // Second tick arrives while the first is still in flight → must be skipped.
        runner.runTick(poke: {
            pokeCount.increment()              // should NOT happen
            return .init(action: .ok, ranModes: .read)
        }, report: { _ in })

        XCTAssertEqual(runner.skippedTicks, 1, "overlapping tick should be skipped")
        XCTAssertEqual(pokeCount.value, 1, "second poke must not run while first is in flight")

        // Release the first poke and make sure the background thread unwinds
        // cleanly before the test ends.
        release.signal()
        XCTAssertEqual(firstFinished.wait(timeout: .now() + 5), .success,
                       "first poke should finish after release")
    }

    // After a poke finishes, the next tick runs normally (guard resets).
    func testGuardResetsAfterPokeCompletes() {
        let runner = PerVolumeRunner(label: "test2", pokeTimeout: 5)
        var count = 0
        runner.runTick(poke: { count += 1; return .init(action: .ok, ranModes: .read) },
                       report: { _ in })
        runner.runTick(poke: { count += 1; return .init(action: .ok, ranModes: .read) },
                       report: { _ in })
        XCTAssertEqual(count, 2)
        XCTAssertEqual(runner.skippedTicks, 0)
    }
}

/// Tiny lock-guarded counter so the poke-count assertion is race-free even
/// though the two pokes run on different threads.
private final class Counter {
    private let lock = NSLock()
    private var n = 0
    func increment() { lock.lock(); n += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
}
