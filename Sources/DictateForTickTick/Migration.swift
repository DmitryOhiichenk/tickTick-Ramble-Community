import Foundation

/// The app was called "TickTick Live" in 1.0.0. On first launch after the rename, settings, tokens and
/// unsent tasks are carried over so updating users lose nothing.
@MainActor
enum Migration {
    private static let oldDefaultsDomain = "app.ticktick-live.voice"
    private static let oldKeychainService = "app.ticktick-live.tokens"
    private static let oldSupportFolder = "TickTick Live"
    private static let doneKey = "migratedFromTickTickLive"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }

        if let old = UserDefaults(suiteName: oldDefaultsDomain) {
            for key in ["language", "appearance", "model", "silenceTimeout", "hotkey", "showInMenuBar", "runInBackground"]
            where defaults.object(forKey: key) == nil {
                if let value = old.object(forKey: key) { defaults.set(value, forKey: key) }
            }
        }

        for account in ["gemini", "ticktick"] where Keychain.read(account).isEmpty {
            let value = Keychain.read(account, service: oldKeychainService)
            if !value.isEmpty {
                Keychain.write(account, value)
                Keychain.write(account, "", service: oldKeychainService)
            }
        }

        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldFolder = base.appendingPathComponent(oldSupportFolder, isDirectory: true)
        let newFolder = AppState.supportDirectory
        if fm.fileExists(atPath: oldFolder.path) {
            if !fm.fileExists(atPath: newFolder.path) {
                try? fm.moveItem(at: oldFolder, to: newFolder)
            } else {
                try? fm.removeItem(at: oldFolder)
            }
        }

        defaults.set(true, forKey: doneKey)
    }
}
