import AppKit
import Carbon

/// Watches for the Fn / Globe key via a Carbon event hotkey. Unlike a global
/// event tap this needs no Accessibility permission.
final class FunctionKeyMonitor {
    static let shared = FunctionKeyMonitor()

    /// Called every time Fn is pressed down.
    var onFunctionKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    func register() {
        guard hotKeyRef == nil else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4C524B32), id: 2) // 'LRK2'
        let status = RegisterEventHotKey(
            UInt32(kVK_Function),
            0,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            DebugLog.write("Fn hotkey registration failed: \(status)")
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                DispatchQueue.main.async {
                    DebugLog.write("Fn key pressed")
                    FunctionKeyMonitor.shared.onFunctionKey?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        if handlerStatus != noErr {
            DebugLog.write("Fn event handler failed: \(handlerStatus)")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
