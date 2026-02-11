import Foundation
import AppKit

/// キーボードショートカット
struct KeyboardShortcut: Codable, Equatable {
    var modifiers: Modifiers
    var keyCode: UInt16
    var key: String  // 表示用（"N", "K"など）

    struct Modifiers: OptionSet, Codable, Equatable {
        let rawValue: UInt

        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)

        var eventFlags: NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = []
            if contains(.command) { flags.insert(.command) }
            if contains(.shift) { flags.insert(.shift) }
            if contains(.option) { flags.insert(.option) }
            if contains(.control) { flags.insert(.control) }
            return flags
        }

        var displayString: String {
            var components: [String] = []
            if contains(.control) { components.append("⌃") }
            if contains(.option) { components.append("⌥") }
            if contains(.shift) { components.append("⇧") }
            if contains(.command) { components.append("⌘") }
            return components.joined()
        }
    }

    /// 表示用の文字列（例: "⌘⇧N"）
    var displayString: String {
        modifiers.displayString + key
    }

    /// イベントがこのショートカットと一致するか
    func matches(event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }

        // キーコードの比較
        guard event.keyCode == keyCode else { return false }

        // 修飾キーの比較
        let eventModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return eventModifiers == modifiers.eventFlags
    }

    // MARK: - Presets

    static let openHistory = KeyboardShortcut(
        modifiers: [.command, .shift],
        keyCode: 45,  // N
        key: "N"
    )

    static let focusSearch = KeyboardShortcut(
        modifiers: [.command],
        keyCode: 40,  // K
        key: "K"
    )

    /// ショートカットが無効（未設定）
    static let disabled = KeyboardShortcut(
        modifiers: [],
        keyCode: 0,
        key: ""
    )

    var isDisabled: Bool {
        keyCode == 0 && key.isEmpty
    }
}
