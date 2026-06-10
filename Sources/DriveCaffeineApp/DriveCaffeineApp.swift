import SwiftUI
import AppKit
import DriveCaffeineKit

@main
struct DriveCaffeineApp: App {
    @StateObject private var controller = KeepAliveController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: controller)
                .frame(width: 400)   // wide enough for Read · Write · interval on one line
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    static let menuBarIcon = AppIcon.image(size: 18)
}

// Shared loader for the custom cup-on-drive icon, used by the menu-bar item AND
// the popover header so they match.
//
// IMPORTANT: load by BASE NAME, not a hard-coded .png URL. Xcode combines
// MenuIcon.png/@2x/@3x into a single multi-resolution MenuIcon.tiff at build
// time, so `Bundle.main.url(forResource:"MenuIcon", withExtension:"png")` finds
// nothing in an Xcode/App Store build and the icon silently falls back to the
// SF Symbol (the "old icon" bug). `NSImage(named:)` resolves whichever form the
// bundle actually contains — the combined .tiff (Xcode) OR loose PNGs (build.sh).
enum AppIcon {
    static func image(size: CGFloat) -> NSImage {
        let img = NSImage(named: "MenuIcon")
            // Fallback for loose-PNG bundles where named lookup misses:
            ?? Bundle.main.url(forResource: "MenuIcon", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "externaldrive.fill.badge.checkmark",
                       accessibilityDescription: "Drive Caffeine")
            ?? NSImage()
        img.isTemplate = true
        img.size = NSSize(width: size, height: size)
        return img
    }
}
