# Step-0.5 Sandbox Spike

Throwaway validation app. It answers the three questions the Step-0 raw-device
spike could NOT (because `sudo dd if=/dev/rdiskN` is impossible in the sandbox):

1. Does a **sandboxed `F_NOCACHE` read of a file** (via a security-scoped bookmark)
   keep the drive's bridge-chip idle timer from firing?
2. Does the **security-scoped bookmark survive quit → reboot → remount** and still
   grant access with **no re-prompt**?
3. Does the repeating timer **keep firing under App Nap** (app backgrounded, Mac
   idle, on battery, >10 min)? — the CRITICAL unhedged risk from the eng review.

If all three pass, the real app (tasks T2+) reimplements this cleanly.
If #3 fails, escalate to a login-item helper or an IOKit power assertion and re-spike.

---

## Build & run — NO Xcode needed

Command Line Tools (which you have) are enough. `build.sh` compiles with `swiftc`,
assembles the `.app` bundle, and ad-hoc code-signs it WITH the sandbox entitlements.
This produces a real, sandboxed, App-Nap-subject app that runs locally. (Full Xcode +
the paid program are only needed for App Store submission / notarization — not for
running the spike.)

```sh
cd spike/sandbox-probe
./build.sh
open build/DriveCaffeineSpike.app
```

A menu-bar icon appears (an external-drive symbol, no Dock icon). Click it to start.

To confirm it's genuinely sandboxed:
```sh
ls -d ~/Library/Containers/com.example.drivecaffeine.spike   # exists → sandbox active
codesign -dv --entitlements - build/DriveCaffeineSpike.app   # lists the 3 entitlements
```

## Run the three checks

**Check A — sandboxed read keeps the drive awake (mechanism under the sandbox)**
1. Click the menu-bar icon → **Pick Drive…** → select your problem external drive.
2. Leave interval at 30s. It starts pinging; the log shows `tick ok — read N bytes`.
3. Walk away >10 min (foreground is fine for this check). Drive should NOT spin down.
   - A later tick logged as `⚠️ slow (drive had likely spun down)` means a prior tick
     failed to keep it up → the sandboxed file read may not be crossing the bridge.

**Check B — bookmark survives reboot + remount (no re-prompt)**
1. With a drive picked, **Quit** the app. **Reboot** the Mac.
2. Relaunch the app. Click **Resume (saved)**.
3. PASS = log says "Resolved saved bookmark WITHOUT re-prompting". Unplug/replug the
   drive and Resume again to confirm remount survival.
4. If it says STALE, that's the design's re-grant path firing (expected only after
   reformat/rename/OS update).

**Check C — App Nap (the critical one) — test HONESTLY**
1. Start pinging at 30s. **Unplug from power (battery).**
2. Put the app in the background, close other apps, **do not touch the Mac**.
3. Wait **>10 minutes** (App Nap throttling takes minutes to engage).
4. Come back. PASS = drive still awake AND the log shows ticks landed ~30s apart the
   whole time. FAIL = gaps between ticks stretch past your drive's timer (45s here) and
   the drive napped → App Nap is throttling despite `beginActivity`.

## Record the result (one block, paste into the eng plan)

```
Check A (sandboxed F_NOCACHE read keeps drive awake): PASS / FAIL
Check B (bookmark survives reboot + remount, no re-prompt): PASS / FAIL
Check C (timer fires under App Nap, battery, idle, >10min): PASS / FAIL
Notes:
```

If A or C fails, STOP and bring the result back — it changes the build (write-default,
or a helper process). If all pass, proceed to T2 (DiskIO core).
