import AppKit
import SwiftUI

struct InstalledApp: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let icon: NSImage
}

enum AppCatalog {
    static func installedApps() -> [InstalledApp] {
        var directories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        // Include nested folders such as /Applications/Utilities.
        for base in [URL(fileURLWithPath: "/Applications"),
                     URL(fileURLWithPath: "/System/Applications")] {
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: base, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            ) {
                directories += contents.filter { $0.pathExtension == "" }
            }
        }

        var seen = Set<String>()
        var apps: [InstalledApp] = []
        let workspace = NSWorkspace.shared

        for directory in directories {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                let path = url.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)

                let name = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                apps.append(InstalledApp(
                    url: url,
                    name: name,
                    icon: workspace.icon(forFile: path)
                ))
            }
        }

        let sorted = apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        DebugLog.write("App catalog loaded \(sorted.count) apps")
        return sorted
    }
}

struct AppGridView: View {
    @State private var search = ""
    private let apps = AppCatalog.installedApps()

    private var filtered: [InstalledApp] {
        search.isEmpty ? apps : apps.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 88))]

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search apps", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(filtered) { app in
                        Button {
                            NSWorkspace.shared.open(app.url)
                            AppGridWindowController.shared.closeWindow()
                        } label: {
                            VStack(spacing: 6) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 52, height: 52)
                                Text(app.name)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 84)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .frame(width: 720, height: 520)
    }
}

final class AppGridWindowController: NSWindowController, NSWindowDelegate {
    static let shared = AppGridWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "All Apps"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: AppGridView())
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.orderOut(nil)
        restoreLyricBar()
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        restoreLyricBar()
        return true
    }

    private func restoreLyricBar() {
        Task { @MainActor in
            DebugLog.write("App grid closed — restoring lyric Touch Bar")
            SystemLyricsTouchBar.shared.showLyricsFromAppGrid()
        }
    }
}
