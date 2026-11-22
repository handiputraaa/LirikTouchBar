import AppKit
import Carbon

/// Global hotkeys:
/// - ⌥⌘L — focus the lyric panel / restore the Touch Bar
/// - ⌥⌘F — show the Fn-style system controls row (works without Accessibility)
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var panelHotKey: EventHotKeyRef?
    private var controlsHotKey: EventHotKeyRef?
    private var panelHandler: EventHandlerRef?
    private var controlsHandler: EventHandlerRef?

    private init() {}

    func register() {
        panelHotKey = registerHotKey(keyCode: UInt32(kVK_ANSI_L), id: 1, signature: 0x4C524B31) { // LRK1
            Task { @MainActor in LyricPanelWindowController.shared.show() }
        }
        panelHandler = installHandler()

        controlsHotKey = registerHotKey(keyCode: UInt32(kVK_ANSI_F), id: 3, signature: 0x4C524B33) { // LRK3
            DebugLog.write("⌥⌘F pressed — showing system controls row")
            Task { @MainActor in SystemLyricsTouchBar.shared.showFunctionKeys() }
        }
        controlsHandler = installHandler()
    }

    private func registerHotKey(keyCode: UInt32, id: UInt32, signature: OSType,
                                action: @escaping () -> Void) -> EventHotKeyRef? {
        if hotKeyActions[signature] == nil { hotKeyActions[signature] = [:] }
        hotKeyActions[signature]?[id] = action

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, UInt32(cmdKey | optionKey), hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        return status == noErr ? ref : nil
    }

    private func installHandler() -> EventHandlerRef? {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var handler: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(), hotKeyEventHandler,
            1, &eventType, nil, &handler
        )
        return handler
    }

    deinit {
        if let panelHotKey { UnregisterEventHotKey(panelHotKey) }
        if let controlsHotKey { UnregisterEventHotKey(controlsHotKey) }
        if let panelHandler { RemoveEventHandler(panelHandler) }
        if let controlsHandler { RemoveEventHandler(controlsHandler) }
    }
}

// MARK: - Global C callback

private var hotKeyActions: [OSType: [UInt32: () -> Void]] = [:]

private let hotKeyEventHandler: EventHandlerProcPtr = { _, event, _ -> OSStatus in
    guard let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr,
          let action = hotKeyActions[hotKeyID.signature]?[hotKeyID.id] else { return noErr }
    DispatchQueue.main.async { action() }
    return noErr
}
