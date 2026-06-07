#!/usr/bin/env bash
# DriveCaffeine Step-0 spike runner.
# Runs ONE keep-alive pattern in a loop. Watch/listen to the drive while it runs:
# if the drive NEVER spins down for the whole window, the pattern works.
#
# Usage:
#   ./run-spike.sh write  /Volumes/YourDrive  /dev/rdisk4  [interval_seconds]
#   ./run-spike.sh read   /Volumes/YourDrive  /dev/rdisk4  [interval_seconds]
#   ./run-spike.sh both   /Volumes/YourDrive  /dev/rdisk4  [interval_seconds]
#
# Find the device node with `diskutil list` (use the rdiskN raw node for reads).
# The "read" and "both" patterns read the RAW device, which requires sudo.
set -euo pipefail

PATTERN="${1:?usage: run-spike.sh <write|read|both> <volume-path> <rdisk-node> [interval]}"
VOL="${2:?missing volume path, e.g. /Volumes/YourDrive}"
RDISK="${3:?missing raw device node, e.g. /dev/rdisk4}"
INTERVAL="${4:-30}"
MARKER="$VOL/.drivecaffeine_keepalive"

if [[ "$PATTERN" == "read" || "$PATTERN" == "both" ]]; then
  echo "Reads use the raw device and need sudo — caching your credential now:"
  sudo -v
fi

echo "pattern=$PATTERN  volume=$VOL  rdisk=$RDISK  interval=${INTERVAL}s"
echo "Watch/listen to the drive. Let it run at least $((INTERVAL * 4))s past your drive's"
echo "idle timer. Ctrl-C to stop."
trap 'echo; echo "stopped"; exit 0' INT

while true; do
  case "$PATTERN" in
    write) ./keepalive_write "$MARKER" && echo "$(date +%T) write+F_FULLFSYNC ok" ;;
    read)  sudo dd if="$RDISK" of=/dev/null bs=64k count=1 2>/dev/null && echo "$(date +%T) uncached read ok" ;;
    both)  ./keepalive_write "$MARKER"; sudo dd if="$RDISK" of=/dev/null bs=64k count=1 2>/dev/null; echo "$(date +%T) write+read ok" ;;
    *) echo "unknown pattern: $PATTERN (use write|read|both)"; exit 2 ;;
  esac
  sleep "$INTERVAL"
done
