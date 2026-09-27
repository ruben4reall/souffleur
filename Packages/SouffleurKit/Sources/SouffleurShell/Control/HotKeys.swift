import Carbon.HIToolbox
import Foundation

/// System-wide shortcuts through the Carbon hot key API: no permission needed, and no other keystroke is ever seen.
@MainActor
final class HotKeys {
    struct Binding {
        let key: Int
        let modifiers: Int
        let action: @MainActor () -> Void
    }

    private var handler: EventHandlerRef?
    private var registered: [UInt32: (reference: EventHotKeyRef?, action: @MainActor () -> Void)] = [:]
    private var nextID: UInt32 = 1
    private static let signature = OSType(0x534F_5546) // "SOUF"

    /// The chord every shortcut shares: Control, Option and Command.
    static let chord = controlKey | optionKey | cmdKey

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let keys = Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { keys.fire(id.id) }
            return noErr
        }, 1, &type, context, &handler)
    }

    /// Registers a group of shortcuts and returns their ids, to remove them together later.
    @discardableResult
    func register(_ bindings: [Binding]) -> [UInt32] {
        bindings.compactMap { binding in
            let id = nextID
            nextID += 1
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(binding.key), UInt32(binding.modifiers), EventHotKeyID(signature: Self.signature, id: id),
                                             GetApplicationEventTarget(), 0, &reference)
            guard status == noErr else { return nil }
            registered[id] = (reference, binding.action)
            return id
        }
    }

    func unregister(_ ids: [UInt32]) {
        for id in ids {
            if let reference = registered[id]?.reference { UnregisterEventHotKey(reference) }
            registered[id] = nil
        }
    }

    private func fire(_ id: UInt32) {
        registered[id]?.action()
    }
}
