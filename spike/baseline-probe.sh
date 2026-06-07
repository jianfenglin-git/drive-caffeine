#!/usr/bin/env bash
# Measures how long an uncached read takes RIGHT NOW.
#   - Slow (several seconds) = the drive was asleep and had to spin up.
#   - Fast (well under a second) = the drive was already awake.
#
# Use it twice:
#   1) BASELINE: leave the drive totally idle for ~15 min, then run this.
#      A slow result proves the drive really does spin down (and shows your
#      spin-up penalty). Note how many minutes of idle it took.
#   2) AFTER a keep-alive run: stop run-spike.sh, immediately run this.
#      A fast result means the pattern kept the drive awake.
#
# Usage: ./baseline-probe.sh /dev/rdisk4
set -euo pipefail
RDISK="${1:?usage: baseline-probe.sh <rdisk-node>  e.g. /dev/rdisk4}"
echo "Timing an uncached 8MB read from $RDISK (needs sudo):"
time sudo dd if="$RDISK" of=/dev/null bs=1m count=8 2>/dev/null
echo "Slow (multi-second) = was asleep.  Fast (<1s) = was awake."
