import Foundation

// What the keep-alive engine should do in response to a poke's outcome.
//
// This is the error-triage matrix from the eng review, expressed as a PURE
// function (errno in → Action out). No I/O, no state. That purity is
// deliberate: it's the most bug-prone logic in the app and the part we most
// want to prove correct, so it lives behind a function that unit tests can
// hammer with every errno value and zero hardware.
public enum KeepAliveAction: Equatable, Sendable {
    /// The write path can't work on this volume (it's read-only). Switch this
    /// volume to the read pattern at the same interval. Read-only is a NORMAL
    /// mode, not a failure — e.g. a Plex media drive or a Time Machine mount.
    case fallbackToRead

    /// The drive went away mid-poke (ejected/unplugged/bridge dropped). Stop
    /// poking and wait for the mount notification to re-arm.
    case waitRemount

    /// Our access grant is gone (revoked / stale security-scoped bookmark).
    /// Prompt the user to re-grant access to this volume.
    case regrant

    /// Something we don't have a specific recovery for. Mark this volume failed
    /// in the UI (with the errno) and keep other volumes running.
    case markFailed(errno: Int32)

    /// The poke succeeded — the drive was kept awake this interval.
    case ok
}

public enum ErrnoAction {

    /// Map a poke result to the action the controller should take.
    ///
    /// `result` is the syscall return value (>= 0 means success; < 0 means an
    /// error occurred and `err` holds the errno). For successful pokes pass
    /// `err = 0`.
    ///
    /// NOTE on ENOSPC: the keep-alive marker file is fixed-size and overwritten
    /// in place, so a write should never actually need new space. But if a full
    /// disk still rejects the write, we fall back to read — a full drive is
    /// still readable, and a read keeps the bridge timer reset just as well.
    public static func action(forResult result: Int, errno err: Int32) -> KeepAliveAction {
        if result >= 0 { return .ok }

        switch err {
        case EROFS, EACCES, EPERM:
            // Read-only filesystem, or we lack write permission → use read.
            return .fallbackToRead
        case ENOSPC, EDQUOT:
            // Disk full / quota exceeded → read still works.
            return .fallbackToRead
        case EIO, ENXIO, ENODEV, ENOENT:
            // Device I/O error, no such device/address, or the path vanished
            // because the volume unmounted → wait for remount.
            return .waitRemount
        case EBADF:
            // Our file descriptor / access is no longer valid → re-grant.
            return .regrant
        default:
            return .markFailed(errno: err)
        }
    }

    /// Convenience for the read path, which can also fail to find any readable
    /// file (a separate, non-errno condition). The engine calls this when the
    /// read target selector returns nil.
    public static let noReadableFile = KeepAliveAction.markFailed(errno: ENOENT)
}
