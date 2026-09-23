import Foundation
import ServiceManagement

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let defaultModel = "gemini-3.8-live"

    private let defaults = UserDefaults.standard

    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
    @Published var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    @Published var geminiKey: String { didSet { Keychain.write("gemini", geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    @Published var tickTickToken: String { didSet { Keychain.write("ticktick", tickTickToken.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    @Published var model: String { didSet { defaults.set(model, forKey: "model") } }
    /// Listening stops after this many seconds without speech.
    @Published var silenceTimeout: Int { didSet { defaults.set(silenceTimeout, forKey: "silenceTimeout") } }
    static let silenceTimeoutRange = 5...60
    @Published var hotkey: KeyCombo {
        didSet { defaults.set(try? JSONEncoder().encode(hotkey), forKey: "hotkey") }
    }
    @Published var showInMenuBar: Bool { didSet { defaults.set(showInMenuBar, forKey: "showInMenuBar") } }
    @Published var runInBackground: Bool { didSet { defaults.set(runInBackground, forKey: "runInBackground") } }
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue, !syncingLoginItem else { return }
            applyLaunchAtLogin()
        }
    }
    @Published var launchAtLoginError: String?
    /// True while the hotkey recorder is capturing keys; the app's own hotkey is unregistered meanwhile.
    @Published var isRecordingHotkey = false

    private var syncingLoginItem = false

    init() {
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .en
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        defaults.removeObject(forKey: "persistentDefault")
        geminiKey = Keychain.read("gemini")
        tickTickToken = Keychain.read("ticktick")
        model = defaults.string(forKey: "model") ?? Self.defaultModel
        let storedTimeout = defaults.integer(forKey: "silenceTimeout")
        silenceTimeout = Self.silenceTimeoutRange.contains(storedTimeout) ? storedTimeout : 15
        if let data = defaults.data(forKey: "hotkey"), let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            hotkey = combo
        } else {
            hotkey = .defaultCombo
        }
        showInMenuBar = defaults.object(forKey: "showInMenuBar") as? Bool ?? true
        runInBackground = defaults.object(forKey: "runInBackground") as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var tokensConfigured: Bool {
        !geminiKey.trimmingCharacters(in: .whitespaces).isEmpty && !tickTickToken.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var effectiveModel: String {
        let m = model.trimmingCharacters(in: .whitespaces)
        return m.isEmpty ? Self.defaultModel : m
    }

    func t(_ key: L) -> String { key.string(language) }
    func t(_ key: L, _ args: CVarArg...) -> String { String(format: key.string(language), arguments: args) }

    func message(for error: ServiceError) -> String {
        switch error {
        case .invalidToken: return t(.errInvalidToken)
        case .network: return t(.errNetwork)
        case .quota: return t(.errQuota)
        case .other(let s): return t(.errUnknown, s)
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            syncingLoginItem = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
            syncingLoginItem = false
        }
    }
}
