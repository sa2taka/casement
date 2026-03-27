import SwiftUI

struct PreferencesView: View {
    @ObservedObject var preferencesStore: PreferencesStore
    var usageStore: UsageStore

    var body: some View {
        TabView {
            GeneralTab(preferencesStore: preferencesStore)
                .tabItem { Label("General", systemImage: "gear") }
            ExclusionsTab(preferencesStore: preferencesStore)
                .tabItem { Label("Exclusions", systemImage: "eye.slash") }
            DataTab(usageStore: usageStore)
                .tabItem { Label("Data", systemImage: "cylinder.split.1x2") }
        }
        .frame(width: 450, height: 300)
    }
}

private struct GeneralTab: View {
    @ObservedObject var preferencesStore: PreferencesStore
    @State private var isRecording = false

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Search shortcut:")
                    Spacer()
                    ShortcutButton(
                        shortcut: $preferencesStore.preferences.hotkeyShortcut,
                        isRecording: $isRecording
                    )
                }
            }

            Section("Display") {
                Toggle("Include minimized windows", isOn: $preferencesStore.preferences.includeMinimizedWindows)
                Toggle("Include utility windows", isOn: $preferencesStore.preferences.includeUtilityWindows)
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferencesStore.preferences) { _, _ in
            preferencesStore.save()
        }
    }
}

private struct ShortcutButton: View {
    @Binding var shortcut: HotkeyShortcut
    @Binding var isRecording: Bool

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "Press shortcut…" : shortcut.displayString)
                .frame(minWidth: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .background(
            ShortcutRecorderRepresentable(
                shortcut: $shortcut,
                isRecording: $isRecording
            )
            .frame(width: 0, height: 0)
        )
    }
}

private struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var shortcut: HotkeyShortcut
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onShortcutCaptured = { keyCode, modifiers in
            shortcut = HotkeyShortcut(keyCode: keyCode, modifiers: modifiers)
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.isRecordingEnabled = isRecording
    }
}

final class ShortcutRecorderNSView: NSView {
    var onShortcutCaptured: ((UInt32, UInt32) -> Void)?
    var isRecordingEnabled = false {
        didSet {
            if isRecordingEnabled {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self, self.isRecordingEnabled else { return event }
                    let modifiers = HotkeyShortcut.carbonModifiers(from: event.modifierFlags)
                    guard modifiers != 0 else { return event }
                    self.onShortcutCaptured?(UInt32(event.keyCode), modifiers)
                    return nil
                }
            } else if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
    private nonisolated(unsafe) var monitor: Any?

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}

private struct ExclusionsTab: View {
    @ObservedObject var preferencesStore: PreferencesStore
    @State private var newBundleId = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Excluded applications will not appear in search results.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Bundle ID (e.g. com.apple.finder)", text: $newBundleId)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = newBundleId.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    preferencesStore.addExclusion(trimmed)
                    newBundleId = ""
                }
                .disabled(newBundleId.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(Array(preferencesStore.preferences.excludedBundleIds).sorted(), id: \.self) { bundleId in
                    HStack {
                        Text(bundleId)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            preferencesStore.removeExclusion(bundleId)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding()
    }
}

private struct DataTab: View {
    let usageStore: UsageStore
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Casement learns from your search selections to improve ranking.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Clear All Learned Data", role: .destructive) {
                showingClearConfirmation = true
            }
            .alert("Clear all learned data?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    usageStore.clearAll()
                }
            } message: {
                Text("This will reset all learned shortcuts and usage history. This cannot be undone.")
            }
            Spacer()
        }
        .padding()
    }
}
