import Foundation
import os

// Unified-system-log channel. Query it from Terminal with:
//   log show --predicate 'subsystem == "com.example.drivecaffeine"' --last 5m --info
//   log stream --predicate 'subsystem == "com.example.drivecaffeine"' --info   (live)
//
// Every keep-alive tick and every disk poke logs here, so "is it really reading
// every 30s?" is answerable by reading the log instead of guessing.
public enum DCLog {
    public static let keepalive = Logger(subsystem: "com.example.drivecaffeine",
                                         category: "keepalive")
}
