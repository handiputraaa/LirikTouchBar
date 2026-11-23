import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Spotify") {
                HStack {
                    Text("Refresh interval")
                    Slider(value: $settings.refreshInterval, in: 0.2...2.0, step: 0.1)
                    Text("\(settings.refreshInterval, specifier: "%.1f")s")
                        .monospacedDigit()
                        .frame(width: 34, alignment: .trailing)
                }
                Text("How often Lirik asks Spotify for the current playback position.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Touch Bar") {
                HStack {
                    Text("Font size")
                    Slider(value: $settings.fontSize, in: 11...24, step: 1)
                    Text("\(Int(settings.fontSize))pt")
                        .monospacedDigit()
                        .frame(width: 34, alignment: .trailing)
                }
                Stepper("Visible lines: \(settings.lineCount)", value: $settings.lineCount, in: 1...3)
                TextField("Text when no lyrics are found", text: $settings.fallbackText)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Lyrics") {
                Toggle("Romanize Korean lyrics", isOn: $settings.romanizeKorean)
                Text("Shows Korean lines as Roman letters, e.g. 사랑해요 → saranghaeyo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu bar") {
                Toggle("Show menu bar icon", isOn: $settings.showMenuBar)
                Text("Click the ♪ icon to open preferences, control playback, or hide the Touch Bar lyrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Text("Lirik reads Spotify through the macOS Automation interface and fetches synced lyrics from LRCLIB.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Lirik Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentViewController = NSHostingController(rootView: SettingsView())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
