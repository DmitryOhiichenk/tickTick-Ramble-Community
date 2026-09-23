import AppKit
import Carbon

/// A global shortcut in Carbon terms (virtual key code + Carbon modifier mask).
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultCombo = KeyCombo(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(optionKey | shiftKey))

    private static let relevantMask = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.relevantMask
    }

    init(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        self.init(keyCode: UInt32(event.keyCode), modifiers: m)
    }

    var hasPrimaryModifier: Bool {
        modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    var isFunctionKey: Bool { Self.functionKeys[Int(keyCode)] != nil }

    var display: String { Self.modifierSymbols(modifiers) + Self.keyName(keyCode) }

    static func modifierSymbols(_ m: UInt32) -> String {
        var s = ""
        if m & UInt32(controlKey) != 0 { s += "⌃" }
        if m & UInt32(optionKey) != 0 { s += "⌥" }
        if m & UInt32(shiftKey) != 0 { s += "⇧" }
        if m & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    static func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
        kVK_F19: "F19", kVK_F20: "F20",
    ]

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_ANSI_KeypadEnter: "⌤",
    ]

    static func keyName(_ code: UInt32) -> String {
        if let f = functionKeys[Int(code)] { return f }
        if let s = specialKeys[Int(code)] { return s }
        return translate(code)?.uppercased() ?? "#\(code)"
    }

    /// Character for a key code in the current ASCII-capable layout (so ⌥⇧R shows "R" even with a Cyrillic layout active).
    private static func translate(_ code: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String? in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeys: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}

enum HotkeyValidation: Equatable {
    case ok, needsModifier, systemConflict, inUse
}

/// Registers one global hotkey via Carbon. Needs no Accessibility permission.
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    var onPressed: (() -> Void)?

    private static let signature: OSType = 0x44465454 // 'DFTT'

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onPressed?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    @discardableResult
    func register(_ combo: KeyCombo) -> OSStatus {
        unregister()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        return RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    /// Call while this app's own hotkey is unregistered (the recorder does that).
    static func validate(_ combo: KeyCombo) -> HotkeyValidation {
        if !combo.hasPrimaryModifier && !combo.isFunctionKey { return .needsModifier }
        if isSystemShortcut(combo) { return .systemConflict }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, EventHotKeyID(signature: signature, id: 99),
                                         GetApplicationEventTarget(), 0, &ref)
        if let ref { UnregisterEventHotKey(ref) }
        if status == OSStatus(eventHotKeyExistsErr) { return .inUse }
        return status == noErr ? .ok : .inUse
    }

    /// Well-known shortcuts that apps rely on, plus everything enabled in System Settings → Keyboard Shortcuts.
    private static func isSystemShortcut(_ combo: KeyCombo) -> Bool {
        let cmd = UInt32(cmdKey), shift = UInt32(shiftKey), opt = UInt32(optionKey), ctrl = UInt32(controlKey)
        let reserved: [(Int, UInt32)] = [
            (kVK_Space, cmd), (kVK_Space, ctrl), (kVK_Space, cmd | opt), (kVK_Tab, cmd), (kVK_Tab, cmd | shift),
            (kVK_ANSI_Q, cmd), (kVK_ANSI_W, cmd), (kVK_ANSI_H, cmd), (kVK_ANSI_M, cmd), (kVK_ANSI_C, cmd),
            (kVK_ANSI_V, cmd), (kVK_ANSI_X, cmd), (kVK_ANSI_Z, cmd), (kVK_ANSI_Z, cmd | shift), (kVK_ANSI_A, cmd),
            (kVK_ANSI_S, cmd), (kVK_ANSI_N, cmd), (kVK_ANSI_O, cmd), (kVK_ANSI_P, cmd), (kVK_ANSI_F, cmd),
            (kVK_ANSI_T, cmd), (kVK_ANSI_Comma, cmd), (kVK_ANSI_Grave, cmd), (kVK_Escape, cmd | opt),
            (kVK_ANSI_3, cmd | shift), (kVK_ANSI_4, cmd | shift), (kVK_ANSI_5, cmd | shift),
            (kVK_ANSI_Q, cmd | ctrl), (kVK_ANSI_F, cmd | ctrl), (kVK_ANSI_Q, cmd | shift),
        ]
        if reserved.contains(where: { UInt32($0.0) == combo.keyCode && $0.1 == combo.modifiers }) { return true }

        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr, let array = unmanaged?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        let mask = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        for entry in array {
            let enabled = (entry["kHISymbolicHotKeyEnabled"] as? Bool) ?? false
            guard enabled,
                  let code = (entry["kHISymbolicHotKeyCode"] as? NSNumber)?.uint32Value,
                  let mods = (entry["kHISymbolicHotKeyModifiers"] as? NSNumber)?.uint32Value else { continue }
            if code == combo.keyCode && (mods & mask) == combo.modifiers { return true }
        }
        return false
    }
}
