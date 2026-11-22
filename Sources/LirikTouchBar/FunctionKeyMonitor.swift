import AppKit
import Carbon
import ApplicationServices

/// Watches for the Fn / Globe key.
///
/// macOS consumes Fn before Carbon hotkeys can see it (the globe key is handled
/// by the Touch Bar server), so the primary method is a global NSEvent monitor.
/// That requires Accessibility permission; we prompt once on first launch.
final class FunctionKeyMonitor {
    static let shared = FunctionKeyMonitor()

    /// Called when Fn transitions from up to down.
    var onFunctionKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private var recheckTimer: Timer?
    private var fnDown = false

    private init() {}

    func register() {
        DebugLog.write("Fn registration check: trusted=\(AXIsProcessTrusted()) bundle=\(Bundle.main.bundlePath)")
        registerCarbonHotKey()   // harmless fallback on Macs that deliver Fn
        registerGlobalMonitor()

        // A menu-bar app may not receive applicationDidBecomeActive after the
        // user grants Accessibility in System Settings, so poll for trust.
        guard recheckTimer == nil else { return }
        recheckTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.recheck()
        }
    }

    /// Re-checks trust without showing a prompt (safe to call repeatedly).
    func recheck() {
        guard AXIsProcessTrusted() else { return }
        let wasInstalled = globalMonitor != nil
        registerGlobalMonitor()
        if !wasInstalled, globalMonitor != nil {
            DebugLog.write("Accessibility granted — Fn monitor active")
        }
    }

    /// Prompts for Accessibility and, once granted, starts the monitor and
    /// opens the relevant System Settings pane for manual approval.
    func requestAccessibility() {
        _ = isTrusted
        if isTrusted {
            registerGlobalMonitor()
            DebugLog.write("Accessibility granted — Fn monitor active")
        } else {
            if let url = URL(string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            DebugLog.write("Opening Accessibility settings for Fn key")
        }
    }

    // MARK: - Accessibility

    private var isTrusted: Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    // MARK: - Carbon fallback

    private func registerCarbonHotKey() {
        guard hotKeyRef == nil else { return }
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C524B32), id: 2) // 'LRK2'
        let status = RegisterEventHotKey(
            UInt32(kVK_Function), 0, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard status == noErr else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                DispatchQueue.main.async { FunctionKeyMonitor.shared.fireIfNeeded() }
                return noErr
            },
            1, &eventType, nil, &eventHandlerRef
        )
    }

    // MARK: - Global monitor

    private func registerGlobalMonitor() {
        guard globalMonitor == nil else { return }
        guard isTrusted else {
            DebugLog.write("Accessibility not granted — Fn key detection unavailable")
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) {
            [weak self] event in
            guard let self else { return }
            let fnNow = event.modifierFlags.contains(.function) ||
                        event.keyCode == UInt16(kVK_Function)
            if fnNow && !self.fnDown {
                self.fireIfNeeded()
            }
            self.fnDown = fnNow
        }
        DebugLog.write("Fn global monitor installed")
    }

    // MARK: - Firing

    private func fireIfNeeded() {
        DebugLog.write("Fn key pressed")
        onFunctionKey?()
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
    }
}
