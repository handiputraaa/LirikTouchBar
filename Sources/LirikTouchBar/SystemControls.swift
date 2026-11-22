import Foundation
import CoreGraphics
import AudioToolbox
import ObjectiveC
import Darwin

/// Reads and sets the built-in display brightness and the default output volume.
/// No extra permissions are needed — these are the same APIs the Control Strip uses.
enum SystemControls {
    private static let displayServices = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private static var builtInDisplay: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    // MARK: - Brightness

    static var brightness: Float? {
        get {
            typealias Getter = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
            guard let display = builtInDisplay,
                  let handle = displayServices,
                  let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
            var value: Float = 0
            return unsafeBitCast(symbol, to: Getter.self)(display, &value) == 0 ? value : nil
        }
        set {
            typealias Setter = @convention(c) (UInt32, Float) -> Int32
            guard let value = newValue,
                  let display = builtInDisplay,
                  let handle = displayServices,
                  let symbol = dlsym(handle, "DisplayServicesSetBrightness") else { return }
            _ = unsafeBitCast(symbol, to: Setter.self)(display, min(1, max(0, value)))
        }
    }

    // MARK: - Volume

    static var volume: Float? {
        get { outputProperty(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, as: Float.self) }
        set {
            guard let value = newValue else { return }
            setOutputProperty(
                kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                Float32(min(1, max(0, value)))
            )
        }
    }

    static var isMuted: Bool {
        get { (outputProperty(kAudioDevicePropertyMute, as: UInt32.self) ?? 0) != 0 }
        set { setOutputProperty(kAudioDevicePropertyMute, UInt32(newValue ? 1 : 0)) }
    }

    // MARK: - Keyboard backlight

    private static let coreBrightness = dlopen(
        "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
        RTLD_LAZY
    )

    private static let keyboardClient: NSObject? = {
        guard coreBrightness != nil,
              let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else { return nil }
        return type.init()
    }()

    private static let keyboardID: UInt64? = {
        guard let client = keyboardClient else { return nil }
        let selector = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard client.responds(to: selector),
              let ids = client.perform(selector)?.takeRetainedValue() as? [NSNumber],
              let first = ids.first else { return nil }
        return first.uint64Value
    }()

    static var keyboardBrightness: Float? {
        get {
            guard let client = keyboardClient, let id = keyboardID else { return nil }
            let selector = NSSelectorFromString("brightnessForKeyboard:")
            guard client.responds(to: selector) else { return nil }
            typealias Getter = @convention(c) (AnyObject, Selector, UInt64) -> Float
            return unsafeBitCast(client.method(for: selector), to: Getter.self)(
                client, selector, id
            )
        }
        set {
            guard let client = keyboardClient, let id = keyboardID, let value = newValue else { return }
            let selector = NSSelectorFromString("setBrightness:fadeSpeed:commit:forKeyboard:")
            guard client.responds(to: selector) else { return }
            typealias Setter = @convention(c) (AnyObject, Selector, Float, Int32, Bool, UInt64) -> Bool
            _ = unsafeBitCast(client.method(for: selector), to: Setter.self)(
                client, selector, min(1, max(0, value)), 0, true, id
            )
        }
    }

    // MARK: - Audio helpers

    private static func defaultOutput() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        return status == noErr ? device : nil
    }

    private static func outputAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func outputProperty<T>(_ selector: AudioObjectPropertySelector, as _: T.Type) -> T? {
        guard let device = defaultOutput() else { return nil }
        var address = outputAddress(selector)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.pointee
    }

    private static func setOutputProperty<T>(_ selector: AudioObjectPropertySelector, _ value: T) {
        guard let device = defaultOutput() else { return }
        var address = outputAddress(selector)
        var value = value
        _ = withUnsafeBytes(of: &value) { raw in
            AudioObjectSetPropertyData(
                device, &address, 0, nil, UInt32(MemoryLayout<T>.size), raw.baseAddress!
            )
        }
    }
}
