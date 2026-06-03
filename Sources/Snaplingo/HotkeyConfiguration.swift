import AppKit

enum HotkeyAction: String, CaseIterable, Codable, Identifiable {
    case capture

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .capture:
            return "截图"
        }
    }

    var defaultShortcut: HotkeyBinding {
        switch self {
        case .capture:
            return HotkeyBinding(
                action: self,
                keyCode: 0,
                modifiers: UInt32(NSEvent.ModifierFlags.option.rawValue),
                keyEquivalent: "a"
            )
        }
    }
}

struct HotkeyBinding: Codable, Equatable, Identifiable {
    let action: HotkeyAction
    var keyCode: UInt32
    var modifiers: UInt32
    var keyEquivalent: String

    var id: String { action.rawValue }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(modifiers))
    }

    var displayText: String {
        let parts: [(NSEvent.ModifierFlags, String)] = [
            (.command, "Command"),
            (.shift, "Shift"),
            (.option, "Option"),
            (.control, "Control")
        ]
        let modifierText = parts
            .filter { modifierFlags.contains($0.0) }
            .map(\.1)
        return (modifierText + [keyEquivalent.uppercased()]).joined(separator: " + ")
    }
}
