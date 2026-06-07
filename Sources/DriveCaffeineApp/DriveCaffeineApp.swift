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
// the popover header so they match. Loads the highest-res bundled asset (@3x)
// for crispness, marks it isTemplate so it tints for light/dark, and resizes to
// the requested point size. Falls back to the SF Symbol if the asset is missing.
enum AppIcon {
    static func image(size: CGFloat) -> NSImage {
        // Prefer @3x (54px) so header/large uses stay sharp; any of the three works.
        for name in ["MenuIcon@3x", "MenuIcon@2x", "MenuIcon"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                img.isTemplate = true
                img.size = NSSize(width: size, height: size)
                return img
            }
        }
        let fallback = NSImage(systemSymbolName: "externaldrive.fill.badge.checkmark",
                               accessibilityDescription: "Drive Caffeine") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }
}
