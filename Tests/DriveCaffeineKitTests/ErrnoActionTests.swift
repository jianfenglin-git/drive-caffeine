import XCTest
@testable import DriveCaffeineKit

// The keystone tests: the error-triage matrix is a pure function, so we can
// prove every branch with zero hardware. This is the coverage we'd otherwise
// have lost by calling POSIX directly in the engine (eng review Issue 1).
final class ErrnoActionTests: XCTestCase {

    func testSuccessIsOk() {
        XCTAssertEqual(ErrnoAction.action(forResult: 8, errno: 0), .ok)
        XCTAssertEqual(ErrnoAction.action(forResult: 0, errno: 0), .ok)
    }

    func testReadOnlyFamilyFallsBackToRead() {
        for e in [EROFS, EACCES, EPERM] {
            XCTAssertEqual(ErrnoAction.action(forResult: -1, errno: e), .fallbackToRead,
                           "errno \(e) should fall back to read")
        }
    }

    func testDiskFullFamilyFallsBackToRead() {
        for e in [ENOSPC, EDQUOT] {
            XCTAssertEqual(ErrnoAction.action(forResult: -1, errno: e), .fallbackToRead)
        }
    }

    func testDeviceGoneWaitsForRemount() {
        for e in [EIO, ENXIO, ENODEV, ENOENT] {
            XCTAssertEqual(ErrnoAction.action(forResult: -1, errno: e), .waitRemount)
        }
    }

    func testBadDescriptorTriggersRegrant() {
        XCTAssertEqual(ErrnoAction.action(forResult: -1, errno: EBADF), .regrant)
    }

    func testUnknownErrnoMarksFailedWithCode() {
        XCTAssertEqual(ErrnoAction.action(forResult: -1, errno: EINVAL),
                       .markFailed(errno: EINVAL))
    }
}
