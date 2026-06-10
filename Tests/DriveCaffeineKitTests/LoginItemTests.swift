import XCTest
@testable import DriveCaffeineKit

// LoginItem wraps SMAppService. We can't assert real registration in a unit
// test (no signed app bundle, and it would mutate the user's login items), but
// we CAN assert the wrapper is safe to call and returns sane values — it must
// never crash and isEnabled must be a clean Bool regardless of environment.
final class LoginItemTests: XCTestCase {
    func testStatusQueriesDoNotCrash() {
        // These just must not throw/crash in the test runtime.
        _ = LoginItem.isSupported
        _ = LoginItem.isEnabled
    }

    func testSupportedImpliesMacOS13Plus() {
        // On the macOS test host we target (13+), support should be true.
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            XCTAssertTrue(LoginItem.isSupported)
        }
        #endif
    }
}
