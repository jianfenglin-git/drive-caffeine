# Contributing to DriveCaffeine

Thanks for helping keep this alive — DriveCaffeine exists because every prior
tool in this space got abandoned. Contributors are what keep it working across
macOS releases.

## Setup

You need macOS 13+ and the Xcode **Command Line Tools** (`xcode-select --install`).
Full Xcode is only needed to submit to the App Store, not to build or test.

```sh
swift build      # build the package
swift test       # run unit tests (no external drive needed)
./build.sh       # produce a runnable, signed DriveCaffeine.app
```

## Testing

- **Unit tests** run with no hardware and must stay green in CI. The error-triage
  logic (`ErrnoAction`) is a pure function — add a case there and test every branch.
- **Real-drive integration** is gated on an env var so it skips in CI:
  ```sh
  DRIVECAFFEINE_TEST_VOLUME=/Volumes/YourDrive swift test
  ```
  Run this on real hardware before a release, especially the spin-down-defeat check.

## High-value contributions

- **Test on more enclosures.** All current evidence is one drive (45s timer). If
  you have a JMicron/ASMedia dock, report which mode (read/write) and interval
  keeps it awake. This is the single most useful data point you can add.
- **App Nap robustness.** The keep-alive timer must survive App Nap (background,
  on battery, idle >10 min). If you find a drive/condition where it throttles,
  open an issue with the timing.

## Architecture

The logic lives in `DriveCaffeineKit` (no UI), the shell in `DriveCaffeineApp`.
Keep new logic in the kit so it's testable. The `F_NOCACHE` flag on the read path
is load-bearing — see the comment in `DiskIO.swift` before changing the read.

## Pull requests

- Keep diffs focused. One change per PR.
- `swift test` must pass. Add tests for new logic.
- Match the existing comment density — the code explains *why*, not just *what*.
