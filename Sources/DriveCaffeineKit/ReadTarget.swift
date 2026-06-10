import Foundation

// Decides WHICH file the read pattern reads each interval.
//
//   Writable volume:  read the app's own marker (.drivecaffeine_keepalive) —
//                      small, hidden, always present (created by the write path
//                      or by ensureMarker). We control it.
//
//   Read-only volume: we can't create a marker, so pick an existing file. Prefer
//                      a genuinely small one; if only large files exist (the Plex
//                      case — drives full of multi-GB videos), pick any regular
//                      file and read only its FIRST chunk (DiskIO caps reads at
//                      chunkSize). Never read a whole file.
//
// The chosen path is cached by the caller; if it later disappears, the caller
// re-runs selection (self-healing). Returns nil only when NO readable file
// exists on a read-only volume → the controller surfaces "try Write".
public enum ReadTarget {

    public enum Selection: Equatable {
        case marker(String)        // path to our own marker (writable volume)
        case existingFile(String)  // path to an existing file (read-only volume)
    }

    /// Pick the read target for a volume.
    ///
    /// ALWAYS read a real existing file on the drive — NEVER the app's own marker.
    /// This is what the Step-0.5 hardware spike actually validated: reading a file
    /// the app didn't just write forces a genuine device read (cache miss), which
    /// is what keeps the drive's bridge timer reset. The earlier "writable → read
    /// our own marker" optimization broke this: reading a freshly-written 8-byte
    /// file is served from RAM in ~0ms and never touches the disk, so the drive
    /// slept. (Confirmed via os_log: tick fired every 30s, poke took=0ms, drive
    /// slept anyway.) `writable` is no longer used for selection — reads are reads.
    public static func select(volumeRoot: URL,
                              writable: Bool = false,
                              fileManager: FileManager = .default) -> Selection? {
        if let file = firstReadableFile(under: volumeRoot, fileManager: fileManager) {
            return .existingFile(file)
        }
        return nil
    }

    /// Ensure the marker file exists on a writable volume (create empty if not),
    /// so the read path has something to read even before the first write tick.
    @discardableResult
    public static func ensureMarker(volumeRoot: URL) -> Bool {
        let path = DiskIO.markerPath(forVolume: volumeRoot)
        if FileManager.default.fileExists(atPath: path) { return true }
        return DiskIO.writeMarker(path: path).succeeded
    }

    /// Walk the volume for a file to read. Prefer small (≤ 1MB); else remember
    /// the first regular file seen and use that (we only read its first chunk).
    /// Bounded so we never walk a huge drive forever.
    static func firstReadableFile(under root: URL,
                                  fileManager fm: FileManager = .default,
                                  scanLimit: Int = 5000) -> String? {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else { return nil }
        if !isDir.boolValue { return root.path }

        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                     options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return nil
        }

        var firstAny: String?
        var scanned = 0
        for case let url as URL in en {
            scanned += 1
            if scanned > scanLimit { break }
            guard let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  vals.isRegularFile == true else { continue }
            if firstAny == nil { firstAny = url.path }
            if let size = vals.fileSize, size > 0, size <= 1_000_000 {
                return url.path   // ideal: a genuinely small file
            }
        }
        return firstAny           // fall back: first regular file (read first chunk only)
    }
}
