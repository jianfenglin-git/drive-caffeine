# Drive Caffeine

A tiny, free, open-source macOS menu-bar app that keeps external drives from
spinning down.

Repo: https://github.com/jianfenglin-git/drive-caffeine

Many external drives have a **firmware idle timer** (in the enclosure's
JMicron/ASMedia bridge chip) that spins the disk down after a short idle period —
regardless of macOS energy settings, which can't reach it. The result is a
~10-second spin-up wait every time you touch the drive after it naps: browsing a
Plex library, scrubbing a timeline, opening a file. DriveCaffeine quietly pokes
the drive on a timer so its idle timer never fires.

## How it works

The idle timer lives in the enclosure bridge chip and resets on I/O traffic
**crossing the bridge** — not on platter motion. DriveCaffeine issues a real
command every interval:

- **Read** (default): an uncached (`F_NOCACHE`) read of a file on the drive. Gentle,
  no disk wear, and works on **read-only** volumes (Plex media shares, Time
  Machine). The `F_NOCACHE` flag is essential — it forces the read past the macOS
  cache so a real command reaches the device.
- **Write** (optional): writes a tiny hidden marker and flushes it to media with
  `F_FULLFSYNC`. For the minority of drives whose timer resets only on writes.

Pick per drive; at least one must be on. Toggling a mode runs a real test first
and tells you immediately if it won't work on that drive.

## Build & run (no Xcode needed)

Command Line Tools are enough:

```sh
git clone https://github.com/jianfenglin-git/drive-caffeine.git
cd drive-caffeine
./build.sh
open build/DriveCaffeine.app
```

A menu-bar icon appears (no Dock icon). Click it → **Add Drive…** → pick your
external drive.

Run the tests (no external drive required):

```sh
swift test
```

## Project layout

- `Sources/DriveCaffeineKit/` — the testable core (I/O, error triage, volume
  identity, persistence, timers). No UI.
- `Sources/DriveCaffeineApp/` — the SwiftUI `MenuBarExtra` shell.
- `Tests/` — unit tests (run with no hardware) + an env-gated real-drive
  integration suite (`DRIVECAFFEINE_TEST_VOLUME=/Volumes/Foo swift test`).
- `spike/` — throwaway validation experiments (Step-0 mechanism, Step-0.5 sandbox).

## Status

v1 in progress. Validated on real hardware: a sandboxed `F_NOCACHE` read keeps a
45s-timer drive awake at 30s intervals, including read-only mounts, and survives
App Nap. See `CONTRIBUTING.md` to help.

## License

MIT. See [LICENSE](LICENSE).
