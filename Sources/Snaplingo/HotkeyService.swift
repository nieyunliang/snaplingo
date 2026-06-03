import AppKit
import Carbon
import Combine

@MainActor
final class HotkeyService {
    private static let signature: OSType = 0x534E4150

    private var eventHandler: EventHandlerRef?
    private var registeredHotkeys: [EventHotKeyRef] = []
    private var actionsByID: [UInt32: HotkeyAction] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var lastFireDate = Date.distantPast
    private var handler: ((HotkeyAction) -> Void)?

    func start(settings: AppSettings, handler: @escaping (HotkeyAction) -> Void) {
        stop()
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            snaplingoHotkeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        for (index, binding) in settings.hotkeys.enumerated() {
            register(binding, id: UInt32(index + 1))
        }

        settings.$hotkeys
            .dropFirst()
            .sink { [weak self, weak settings] _ in
                guard let self, let settings else { return }
                self.start(settings: settings, handler: handler)
            }
            .store(in: &cancellables)
    }

    func stop() {
        for hotkey in registeredHotkeys {
            UnregisterEventHotKey(hotkey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
        registeredHotkeys.removeAll()
        actionsByID.removeAll()
        cancellables.removeAll()
        handler = nil
    }

    fileprivate func handleHotkey(id: UInt32) {
        guard let action = actionsByID[id], let handler else {
            return
        }
        fire(action: action, handler: handler)
    }

    private func fire(action: HotkeyAction, handler: @escaping (HotkeyAction) -> Void) {
        let now = Date()
        guard now.timeIntervalSince(lastFireDate) > 0.4 else {
            return
        }
        lastFireDate = now
        handler(action)
    }

    private func register(_ binding: HotkeyBinding, id: UInt32) {
        let hotkeyID = EventHotKeyID(signature: Self.signature, id: id)
        var hotkey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode,
            carbonModifiers(for: binding.modifierFlags),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkey
        )
        guard status == noErr, let hotkey else {
            return
        }
        registeredHotkeys.append(hotkey)
        actionsByID[id] = binding.action
    }

    private func carbonModifiers(for modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if modifiers.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        if modifiers.contains(.option) {
            result |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            result |= UInt32(controlKey)
        }
        return result
    }
}

private func snaplingoHotkeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard status == noErr else {
        return status
    }

    let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        service.handleHotkey(id: hotkeyID.id)
    }
    return noErr
}
