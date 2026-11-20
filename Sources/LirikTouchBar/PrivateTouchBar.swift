import AppKit
import Darwin

/// Thin wrapper around Apple's private *system-modal* Touch Bar APIs.
///
/// A normal `NSTouchBar` is only displayed for the frontmost app. The APIs
/// below let an app present a Touch Bar at the system level, which stays
/// visible no matter which app is active. They are not public API: this app
/// cannot be sold on the App Store, and a future macOS update may break them.
enum PrivateTouchBar {
    private static let dfr = dlopen(
        "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation",
        RTLD_LAZY
    )

    /// Adds a button to the system-wide Control Strip.
    static func addSystemTrayItem(_ item: NSTouchBarItem) {
        let selector = NSSelectorFromString("addSystemTrayItem:")
        guard NSTouchBarItem.responds(to: selector) else {
            DebugLog.write("PrivateTouchBar: addSystemTrayItem unavailable")
            return
        }
        _ = NSTouchBarItem.perform(selector, with: item)
    }

    /// Makes the tray item visible in System Settings → Keyboard → Touch Bar.
    static func setControlStripPresence(_ identifier: NSTouchBarItem.Identifier,
                                        visible: Bool) {
        guard let dfr,
              let symbol = dlsym(dfr, "DFRElementSetControlStripPresenceForIdentifier") else {
            DebugLog.write("PrivateTouchBar: DFRElementSetControlStripPresenceForIdentifier unavailable")
            return
        }
        typealias Function = @convention(c) (CFString, Bool) -> Void
        unsafeBitCast(symbol, to: Function.self)(identifier.rawValue as CFString, visible)
    }

    static func showsCloseBoxWhenFrontMost(_ show: Bool) {
        guard let dfr,
              let symbol = dlsym(dfr, "DFRSystemModalShowsCloseBoxWhenFrontMost") else { return }
        typealias Function = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: Function.self)(show)
    }

    /// Presents a system-level bar that remains visible across all apps.
    static func present(_ touchBar: NSTouchBar, trayID: NSTouchBarItem.Identifier) {
        let selector = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        guard NSTouchBar.responds(to: selector) else {
            DebugLog.write("PrivateTouchBar: presentSystemModalTouchBar unavailable")
            return
        }
        _ = NSTouchBar.perform(selector, with: touchBar, with: trayID.rawValue as NSString)
    }

    static func minimize(_ touchBar: NSTouchBar) {
        let selector = NSSelectorFromString("minimizeSystemModalTouchBar:")
        guard NSTouchBar.responds(to: selector) else { return }
        _ = NSTouchBar.perform(selector, with: touchBar)
    }
}
