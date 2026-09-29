import Carbon

// A system-wide keyboard shortcut. Uses the Carbon hot key API, which
// works in every app and needs no special macOS permission.
enum HotKey {
    private static var action: (() -> Void)?
    private static var ref: EventHotKeyRef?
    private static var handlerInstalled = false

    static func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        self.action = action
        if !handlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { HotKey.action?() }
                return noErr
            }, 1, &eventType, nil, nil)
            handlerInstalled = true
        }
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        let id = EventHotKeyID(signature: OSType(0x534E_4950), id: 1) // "SNIP"
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &ref)
        return status == noErr
    }
}
