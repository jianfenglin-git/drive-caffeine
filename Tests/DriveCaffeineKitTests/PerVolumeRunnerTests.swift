import XCTest
@testable import DriveCaffeineKit

final class PerVolumeRunnerTests: XCTestCase {

    // The in-flight guard: while a poke is running, a second tick is dropped and
    // counted — it does NOT queue up behind the slow poke (eng review Issue 2).
    func testInFlightGuardSkipsOverlappingTick() {
        let runner = PerVolumeRunner(label: "test", pokeTimeout: 5)
        let firstStarted = expectation(description: "first poke started")
        let release = expectation(description: "release first poke")
        var pokeCount = 0

        // First tick: signal it started, then block until we let it go.
        DispatchQueue.global().async {
            runner.runTick(poke: {
                pokeCount += 1
                firstStarted.fulfill()
                _ = XCTWaiter.wait(for: [release], timeout: 2) // hold the poke "in flight"
                return .init(action: .ok, ranModes: .read)
            }, report: { _ in })
        }

        wait(for: [firstStarted], timeout: 2)

        // Second tick arrives while the first is still in flight → must be skipped.
        runner.runTick(poke: {
            pokeCount += 1                       // should NOT happen
            return .init(action: .ok, ranModes: .read)
        }, report: { _ in })

        XCTAssertEqual(runner.skippedTicks, 1, "overlapping tick should be skipped")
        XCTAssertEqual(pokeCount, 1, "second poke must not run while first is in flight")

        release.fulfill()
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
