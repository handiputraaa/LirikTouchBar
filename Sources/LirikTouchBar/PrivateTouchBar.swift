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
        // Private header declares BOOL; pass an explicit 32-bit integer so the
        // ABI matches regardless of Swift's Bool representation.
        typealias Function = @convention(c) (Int32) -> Void
        unsafeBitCast(symbol, to: Function.self)(show ? 1 : 0)
    }

    /// Presents a system-level bar that remains visible across all apps.
    /// Uses the `placement:` variant with value 1, which renders the bar full
    /// width WITHOUT Apple's X close box on the left.
    static func present(_ touchBar: NSTouchBar, trayID: NSTouchBarItem.Identifier) {
        let placementSelector = NSSelectorFromString(
            "presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"
        )
        if NSTouchBar.responds(to: placementSelector),
           let implementation = (NSTouchBar.self as AnyObject).method(for: placementSelector) {
            typealias Function = @convention(c) (
                AnyObject, Selector, NSTouchBar, Int64, NSString
            ) -> Void
            unsafeBitCast(implementation, to: Function.self)(
                NSTouchBar.self, placementSelector, touchBar, 1,
                trayID.rawValue as NSString
            )
            return
        }

        let fallback = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        guard NSTouchBar.responds(to: fallback) else {
            DebugLog.write("PrivateTouchBar: presentSystemModalTouchBar unavailable")
            return
        }
        _ = NSTouchBar.perform(fallback, with: touchBar, with: trayID.rawValue as NSString)
    }

    /// Fully removes the system-modal bar so macOS shows the frontmost app's
    /// own Touch Bar (emoji picker, media progress, etc.) again.
    static func dismiss(_ touchBar: NSTouchBar) {
        let selector = NSSelectorFromString("dismissSystemModalTouchBar:")
        guard NSTouchBar.responds(to: selector) else {
            DebugLog.write("PrivateTouchBar: dismissSystemModalTouchBar unavailable")
            return
        }
        _ = NSTouchBar.perform(selector, with: touchBar)
    }
}
