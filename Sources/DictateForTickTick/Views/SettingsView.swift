import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(settings.t(.settings))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                HStack {
                    // Sits right after the window's close / minimize / zoom buttons.
                    IconButton(systemName: "chevron.left", help: settings.t(.back)) {
                        withAnimation(.easeOut(duration: 0.2)) { app.showSettings = false }
                    }
                    .padding(.leading, 64)
                    Spacer()
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    general
                    recording
                    connections
                    hotkey
                    background
                    footer
                }
                .padding(16)
            }
            .scrollIndicators(.never)
        }
        .background(Theme.background)
    }

    // MARK: Sections

    private var general: some View {
        SettingsSection(title: settings.t(.sectionGeneral)) {
            SettingsRow(title: settings.t(.language), hint: settings.t(.dictationHint)) {
                Picker("", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            Divider().overlay(Theme.separator)
            SettingsRow(title: settings.t(.theme)) {
                Picker("", selection: $settings.appearance) {
                    Text(settings.t(.themeSystem)).tag(AppAppearance.system)
                    Text(settings.t(.themeLight)).tag(AppAppearance.light)
                    Text(settings.t(.themeDark)).tag(AppAppearance.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private var recording: some View {
        SettingsSection(title: settings.t(.sectionRecording)) {
            SettingsRow(title: settings.t(.silenceTimeout), hint: settings.t(.silenceTimeoutHint)) {
                HStack(spacing: 6) {
                    Text(settings.t(.seconds, settings.silenceTimeout))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.text)
                    Stepper("", value: $settings.silenceTimeout, in: SettingsStore.silenceTimeoutRange, step: 5)
                        .labelsHidden()
                }
            }
        }
    }

    private var connections: some View {
        SettingsSection(title: settings.t(.sectionConnections)) {
            TokenField(title: settings.t(.geminiKey), text: $settings.geminiKey, okText: { _ in settings.t(.testOkGemini) }) {
                let r = await GeminiLiveClient.test(apiKey: settings.geminiKey, model: settings.effectiveModel)
                return r.map { 0 }
            }
            Divider().overlay(Theme.separator)
            TokenField(title: settings.t(.tickTickToken), text: $settings.tickTickToken, okText: { settings.t(.testOkTickTick, $0) }) {
                do {
                    return .success(try await TickTickClient(token: settings.tickTickToken).projectCount())
                } catch {
                    return .failure(ServiceError.from(error))
                }
            }
            Divider().overlay(Theme.separator)
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.t(.model))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                TextField(SettingsStore.defaultModel, text: $settings.model)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }

    private var hotkey: some View {
        SettingsSection(title: settings.t(.sectionHotkey)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.t(.hotkey))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                HotkeyRecorder()
                Text(settings.t(.hotkeyHint))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var background: some View {
        SettingsSection(title: settings.t(.sectionBackground)) {
            SettingsRow(title: settings.t(.showInMenuBar), hint: settings.t(.showInMenuBarHint)) {
                Toggle("", isOn: $settings.showInMenuBar).toggleStyle(.switch).labelsHidden().tint(Theme.accent)
            }
            Divider().overlay(Theme.separator)
            SettingsRow(title: settings.t(.runInBackground), hint: settings.t(.runInBackgroundHint)) {
                Toggle("", isOn: $settings.runInBackground).toggleStyle(.switch).labelsHidden().tint(Theme.accent)
            }
            if settings.runInBackground && !settings.showInMenuBar {
                Text(settings.t(.hiddenHint, settings.hotkey.display))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.priority(.p2))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(Theme.separator)
            SettingsRow(title: settings.t(.launchAtLogin), hint: settings.launchAtLoginError) {
                Toggle("", isOn: $settings.launchAtLogin).toggleStyle(.switch).labelsHidden().tint(Theme.accent)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Building blocks

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).shadow(color: .black.opacity(0.06), radius: 1.5, y: 1))
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var hint: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                if let hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control
        }
    }
}

/// Masked token field with a Test button: idle → spinner → result for 5 s.
struct TokenField: View {
    @EnvironmentObject var settings: SettingsStore
    let title: String
    @Binding var text: String
    let okText: (Int) -> String
    let test: () async -> Result<Int, ServiceError>

    enum TestState: Equatable { case idle, running, ok(String), failed(String) }
    @State private var state: TestState = .idle
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(settings.t(.keychainNote))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondary)
            }
            HStack(spacing: 8) {
                Group {
                    if revealed {
                        TextField("", text: $text)
                    } else {
                        SecureField("", text: $text)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                Button { revealed.toggle() } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye").foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
                Button {
                    run()
                } label: {
                    if state == .running {
                        ProgressView().controlSize(.mini).frame(width: 40)
                    } else {
                        Text(settings.t(.test)).frame(minWidth: 40)
                    }
                }
                .buttonStyle(SmallButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || state == .running)
            }
            switch state {
            case .ok(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.success)
            case .failed(let message):
                Label(message, systemImage: "xmark.octagon.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.error)
                    .fixedSize(horizontal: false, vertical: true)
            default:
                EmptyView()
            }
        }
    }

    private func run() {
        state = .running
        Task {
            let result = await test()
            switch result {
            case .success(let n): state = .ok(okText(n))
            case .failure(let e): state = .failed(settings.message(for: e))
            }
            try? await Task.sleep(for: .seconds(5))
            if state != .running { state = .idle }
        }
    }
}

/// Click "Change", press a new shortcut. Validates: needs a modifier, no macOS conflicts, not taken by another app.
struct HotkeyRecorder: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var recording = false
    @State private var liveModifiers: NSEvent.ModifierFlags = []
    @State private var monitor: Any?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(recording ? (liveModifiers.isEmpty ? settings.t(.hotkeyPress) : KeyCombo.modifierSymbols(liveModifiers)) : settings.hotkey.display)
                    .font(.system(size: recording && liveModifiers.isEmpty ? 12 : 14, weight: .medium, design: .rounded))
                    .foregroundStyle(recording ? Theme.accent : Theme.text)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: 90)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.chip))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(recording ? Theme.accent : .clear, lineWidth: 1.5))
                Spacer()
                Button(recording ? settings.t(.cancel) : settings.t(.hotkeyChange)) {
                    recording ? stop() : start()
                }
                .buttonStyle(SmallButtonStyle())
                if settings.hotkey != .defaultCombo && !recording {
                    Button(settings.t(.hotkeyReset)) {
                        settings.hotkey = .defaultCombo
                        error = nil
                    }
                    .buttonStyle(SmallButtonStyle(tint: Theme.secondary))
                }
            }
            if let error {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.error)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        error = nil
        recording = true
        liveModifiers = []
        settings.isRecordingHotkey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                liveModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                return event
            }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == UInt16(kVK_Escape) && mods.isEmpty {
                stop()
                return nil
            }
            let combo = KeyCombo(event: event)
            switch HotkeyManager.validate(combo) {
            case .ok:
                settings.hotkey = combo
                error = nil
                stop()
            case .needsModifier:
                error = settings.t(.hotkeyNeedsModifier)
            case .systemConflict:
                error = settings.t(.hotkeyConflictSystem, combo.display)
            case .inUse:
                error = settings.t(.hotkeyConflictInUse, combo.display)
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        liveModifiers = []
        settings.isRecordingHotkey = false
    }
}
