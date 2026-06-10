import Foundation

// Owns the timer + concurrency discipline for ONE volume. Pulled out of the
// controller so the in-flight-guard + watchdog logic is unit-testable in
// isolation (inject a fake poke closure; no real timer or disk needed).
//
// CONCURRENCY MODEL (per the eng review):
//   - One serial queue per volume → pokes for a volume never overlap each other.
//   - In-flight guard → if a tick fires while the previous poke is still running
//     (slow/hung drive), the new tick is dropped and counted, not queued.
//   - Watchdog → each poke is bounded; if it doesn't finish within the timeout,
//     the runner reports a timeout so a dead drive marks failed instead of
//     blocking forever. One hung volume can't stall the others (separate queues).
public final class PerVolumeRunner {

    public typealias PokeFn = () -> KeepAliveEngine.Outcome
    public typealias ReportFn = (KeepAliveEngine.Outcome) -> Void

    let label: String
    private let queue: DispatchQueue
    private let watchdog: DispatchQueue
    private let pokeTimeout: TimeInterval

    private var timer: DispatchSourceTimer?
    private let lock = NSLock()
    private var inFlight = false
    public private(set) var skippedTicks = 0
    public private(set) var timeouts = 0

    public init(label: String, pokeTimeout: TimeInterval = 8) {
        self.label = label
        self.queue = DispatchQueue(label: "drivecaffeine.poke.\(label)")
        self.watchdog = DispatchQueue(label: "drivecaffeine.watchdog.\(label)")
        self.pokeTimeout = pokeTimeout
    }

    /// Start firing `poke` every `interval` seconds, reporting each outcome via
    /// `report`. Idempotent: calling start again replaces the timer.
    public func start(interval: TimeInterval, poke: @escaping PokeFn, report: @escaping ReportFn) {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(200))
        t.setEventHandler { [weak self] in
            self?.runTick(poke: poke, report: report)
        }
        timer = t
        t.resume()
        DCLog.keepalive.info("runner STARTED (\(self.label, privacy: .public)) interval=\(interval, format: .fixed(precision: 0))s")
    }

    public func stop() {
        if timer != nil {
            DCLog.keepalive.info("runner STOPPED (\(self.label, privacy: .public))")
        }
        timer?.cancel()
        timer = nil
    }

    // MARK: tick

    /// Exposed for tests: run a single tick synchronously-ish with the guard.
    public func runTick(poke: @escaping PokeFn, report: @escaping ReportFn) {
        lock.lock()
        if inFlight {
            skippedTicks += 1
            lock.unlock()
            DCLog.keepalive.info("tick SKIPPED (\(self.label, privacy: .public)) — previous poke still in flight")
            return
        }
        inFlight = true
        lock.unlock()
        DCLog.keepalive.info("tick FIRED (\(self.label, privacy: .public))")

        // Watchdog: if the poke hasn't cleared inFlight within the timeout, we
        // record a timeout and report .markFailed. The actual blocked thread is
        // on `queue`; it can't be force-killed, but the volume is marked failed
        // and future ticks are skipped (still inFlight) until it returns —
        // crucially WITHOUT blocking other volumes' queues.
        let done = DispatchWorkItem {}
        watchdog.asyncAfter(deadline: .now() + pokeTimeout) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let stuck = self.inFlight && !done.isCancelled
            if stuck { self.timeouts += 1 }
            self.lock.unlock()
            if stuck {
                report(KeepAliveEngine.Outcome(action: .markFailed(errno: ETIMEDOUT),
                                               ranModes: []))
            }
        }

        let started = DispatchTime.now()
        let outcome = poke()
        let ms = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000
        done.cancel()           // poke returned before the watchdog fired

        lock.lock()
        inFlight = false
        lock.unlock()

        let slow = ms > 1500 ? " ⚠️SLOW(drive likely had spun down)" : ""
        DCLog.keepalive.info("poke DONE (\(self.label, privacy: .public)) action=\(String(describing: outcome.action), privacy: .public) modes=\(outcome.ranModes.rawValue) took=\(ms, format: .fixed(precision: 0))ms\(slow, privacy: .public)")

        report(outcome)
    }
}
