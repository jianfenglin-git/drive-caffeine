// DriveCaffeine — Step-0.5 sandbox spike
// ========================================
// GOAL: prove the THREE things the design assumes but the Step-0 raw-device
// spike did NOT test, because Step-0 used `sudo dd if=/dev/rdiskN` which a
// sandboxed App Store app can never do.
//
//   1. A SANDBOXED `F_NOCACHE` read of a FILE (reached via a security-scoped
//      bookmark) actually keeps the drive's bridge-chip idle timer from firing.
//   2. The security-scoped bookmark survives quit → reboot → drive remount and
//      still grants access WITHOUT re-prompting the user.
//   3. The repeating timer keeps firing on schedule when the app is backgrounded
//      and the Mac is idle on battery (i.e. it survives App Nap).
//
// This is THROWAWAY validation code. It is intentionally one file, no tests,
// no abstraction. If the spike passes, the real app (T2+) reimplements this
// cleanly. If it fails, you learned it in an afternoon instead of after a
// weekend of building.
//
// HOW TO READ THE RESULT
//   - Pick your problem drive once. Quit the app. Reboot. Relaunch. If it
//     resumes pinging WITHOUT a new file-picker prompt → bookmark persistence OK.
//   - Leave it pinging at 30s, unplug from power, close other apps, walk away
//     >10 min with the app in the background. If the drive stays awake → App Nap
//     defense OK. If it naps → App Nap is throttling the timer (the CRITICAL risk).
//   - Watch the in-app log: each tick prints whether the read crossed to the
//     device (bytesRead) and how long it took. A multi-second read after idle
//     means the drive had spun down (i.e. a PREVIOUS tick failed to keep it up).

import SwiftUI
import AppKit

// Simple Error wrapper so I/O helpers can return Result<Int, ProbeError>.
struct ProbeError: Error { let message: String }

@main
struct SandboxProbeApp: App {
    @StateObject private var probe = Probe()

    var body: some Scene {
        // .window style so we get an interactive panel with the log + controls.
        MenuBarExtra("DriveCaffeine Spike", systemImage: "externaldrive.badge.timemachine") {
            ProbeView(probe: probe)
                .frame(width: 460, height: 420)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Probe

@MainActor
final class Probe: ObservableObject {
    @Published var bookmarkedPath: String = "(none)"
    @Published var running = false
    @Published var intervalSeconds: Double = 30
    @Published var log: [String] = []

    private let bookmarkKey = "spike.volume.bookmark"
    private var timer: DispatchSourceTimer?
    private var activityToken: (any NSObjectProtocol)?   // App Nap defense handle
    private var accessURL: URL?                        // security-scoped, started

    // Dedicated serial queue: all blocking POSIX I/O happens here, never main.
    private let ioQueue = DispatchQueue(label: "spike.io")
    private var inFlight = false                        // in-flight guard

    init() {
        if UserDefaults.standard.data(forKey: bookmarkKey) != nil {
            note("Found a saved bookmark from a previous launch. Click Resume to test persistence.")
        } else {
            note("No saved bookmark. Click 'Pick Drive…' to grant access.")
        }
    }

    // MARK: User actions

    func pickDrive() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Pick the external drive you want to keep awake"
        panel.prompt = "Grant Access"
        // Default the panel at /Volumes so the user lands on mounted drives.
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            // App-scope security-scoped bookmark — the ONLY way a sandboxed app
            // persists access to a user-picked location across launches.
            let data = try url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            note("Saved security-scoped bookmark for \(url.path).")
            start(from: url, freshlyPicked: true)
        } catch {
            note("ERROR creating bookmark: \(error.localizedDescription)")
        }
    }

    func resumeFromBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            note("No saved bookmark to resume from. Pick a drive first.")
            return
        }
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &stale)
            if stale {
                // The design's stale-bookmark path: drop it, prompt re-grant.
                note("Bookmark is STALE (volume reformatted/renamed or OS update). Re-pick the drive.")
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return
            }
            note("Resolved saved bookmark WITHOUT re-prompting → persistence works.")
            start(from: url, freshlyPicked: false)
        } catch {
            note("ERROR resolving bookmark: \(error.localizedDescription)")
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        running = false
        endActivity()
        if let url = accessURL {
            url.stopAccessingSecurityScopedResource()
            accessURL = nil
        }
        note("Stopped.")
    }

    // MARK: Engine

    private func start(from url: URL, freshlyPicked: Bool) {
        stop()  // idempotent reset

        // Must bracket all access to the bookmarked URL between start/stop.
        guard url.startAccessingSecurityScopedResource() else {
            note("startAccessingSecurityScopedResource FAILED — sandbox denied access.")
            return
        }
        accessURL = url
        bookmarkedPath = url.path

        beginActivity()   // App Nap defense — the thing we most want to validate

        let t = DispatchSource.makeTimerSource(queue: ioQueue)
        t.schedule(deadline: .now(), repeating: intervalSeconds, leeway: .milliseconds(200))
        t.setEventHandler { [weak self] in self?.tick(volume: url) }
        timer = t
        t.resume()
        running = true
        note("Started pinging \(url.lastPathComponent) every \(Int(intervalSeconds))s (read, F_NOCACHE).")
    }

    // One keep-alive poke. Runs on ioQueue.
    private func tick(volume: URL) {
        if inFlight {
            Task { @MainActor in self.note("tick skipped — previous poke still running (in-flight guard).") }
            return
        }
        inFlight = true
        defer { inFlight = false }

        let started = DispatchTime.now()
        let result = Self.uncachedRead(volume: volume)
        let ms = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000

        Task { @MainActor in
            switch result {
            case .success(let bytes):
                let slow = ms > 1500 ? "  ⚠️ slow (drive had likely spun down)" : ""
                self.note(String(format: "tick ok — read %d bytes in %.0f ms%@", bytes, ms, slow))
            case .failure(let err):
                self.note("tick FAILED — \(err.message)")
            }
        }
    }

    // MARK: - The actual mechanism under test
    //
    // Reads up to one block of an existing file with F_NOCACHE so the read
    // command crosses the USB bridge instead of being served from the OS page
    // cache. If `volume` is a directory, we find a file to read (read-only-drive
    // path: first small chunk of whatever exists). Returns bytes actually read.

    nonisolated static func uncachedRead(volume: URL) -> Result<Int, ProbeError> {
        guard let target = firstReadableFile(under: volume) else {
            return .failure(ProbeError(message: "no readable file under \(volume.lastPathComponent) — try the Write mode in the real app"))
        }
        let fd = open(target.path, O_RDONLY)
        if fd < 0 { return .failure(ProbeError(message: "open errno \(errno) on \(target.lastPathComponent)")) }
        defer { close(fd) }

        // F_NOCACHE is load-bearing: it forces the read past the unified buffer
        // cache so a real command reaches the device every interval.
        _ = fcntl(fd, F_NOCACHE, 1)

        var buf = [UInt8](repeating: 0, count: 64 * 1024)  // first 64KB chunk only
        let n = buf.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
        if n < 0 { return .failure(ProbeError(message: "read errno \(errno)")) }
        return .success(n)
    }

    // Find a file to read: prefer a small file, else just read the first chunk
    // of whatever is there (handles read-only Plex drives full of huge videos).
    nonisolated static func firstReadableFile(under root: URL) -> URL? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else { return nil }
        if !isDir.boolValue { return root }  // user somehow pointed at a file

        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                     options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return nil }
        var firstAny: URL?
        var count = 0
        for case let u as URL in en {
            count += 1
            if count > 5000 { break }  // don't walk a huge drive forever
            let vals = try? u.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard vals?.isRegularFile == true else { continue }
            if firstAny == nil { firstAny = u }
            if let size = vals?.fileSize, size > 0, size <= 1_000_000 { return u }  // small file: ideal
        }
        return firstAny  // fall back to first regular file; we only read its first 64KB
    }

    // MARK: App Nap defense

    private func beginActivity() {
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Keeping selected external drive awake (spike)"
        )
        note("beginActivity() asserted — App Nap should be suppressed while running.")
    }

    private func endActivity() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    // MARK: Logging

    func note(_ s: String) {
        let stamp = Self.clock()
        log.insert("[\(stamp)] \(s)", at: 0)
        if log.count > 200 { log.removeLast(log.count - 200) }
    }

    nonisolated static func clock() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

// MARK: - View

struct ProbeView: View {
    @ObservedObject var probe: Probe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DriveCaffeine — Sandbox Spike")
                .font(.headline)
            Text("Drive: \(probe.bookmarkedPath)")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)

            HStack {
                Text("Interval: \(Int(probe.intervalSeconds))s")
                Slider(value: $probe.intervalSeconds, in: 5...120, step: 5)
                    .disabled(probe.running)
            }

            HStack {
                Button("Pick Drive…") { probe.pickDrive() }
                Button("Resume (saved)") { probe.resumeFromBookmark() }
                    .disabled(probe.running)
                if probe.running {
                    Button("Stop") { probe.stop() }
                }
                Spacer()
                Circle()
                    .fill(probe.running ? .green : .gray)
                    .frame(width: 10, height: 10)
            }

            Divider()
            Text("Log").font(.caption.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(probe.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .padding(12)
    }
}
