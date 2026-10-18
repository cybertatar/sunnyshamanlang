import AppKit

/// Глобальный перехват клавиатуры через CGEventTap.
/// Enter отдаём на колдовство, остальные нажатия — шаману, чтобы бил в бубен.
final class KeyInterceptor {
    /// Метка наших собственных нажатий, чтобы не ловить их повторно.
    static let marker: Int64 = 0x5348_414D

    enum Key {
        static let a: CGKeyCode = 0
        static let s: CGKeyCode = 1
        static let c: CGKeyCode = 8
        static let v: CGKeyCode = 9
        static let returnKey: CGKeyCode = 36
        static let keypadEnter: CGKeyCode = 76
    }

    /// Нажат Enter. Вернуть `true`, чтобы проглотить его (потом отправим сами).
    var onReturn: (@MainActor (_ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Bool)?
    /// Нажата любая другая клавиша.
    var onKeyDown: (@MainActor (_ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Void)?
    /// ⌃⌥S — включить или выключить колдовство.
    var onToggle: (@MainActor () -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var swallowedKeyUps = Set<CGKeyCode>()

    var isRunning: Bool { tap != nil }

    /// Ставит перехват. Без «Универсального доступа» вернёт `false`.
    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let interceptor = Unmanaged<KeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
            return interceptor.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        // Система отключает перехват, если мы долго думали, — включаем обратно.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return pass }

        let keyCode = CGKeyCode(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp {
            return swallowedKeyUps.remove(keyCode) != nil ? nil : pass
        }
        guard type == .keyDown else { return pass }

        let flags = event.flags
        if keyCode == Key.s, flags.contains(.maskControl), flags.contains(.maskAlternate), !flags.contains(.maskCommand) {
            if let onToggle { MainActor.assumeIsolated { onToggle() } }
            swallowedKeyUps.insert(keyCode)
            return nil
        }
        if keyCode == Key.returnKey || keyCode == Key.keypadEnter {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            // Перехват стоит на главном цикле, поэтому мы уже на главном потоке.
            if !isRepeat, let onReturn, MainActor.assumeIsolated({ onReturn(keyCode, flags) }) {
                swallowedKeyUps.insert(keyCode)
                return nil
            }
            return pass
        }
        if let onKeyDown { MainActor.assumeIsolated { onKeyDown(keyCode, flags) } }
        return pass
    }

    // MARK: - Наши нажатия

    private static let source: CGEventSource? = {
        let source = CGEventSource(stateID: .privateState)
        source?.userData = marker
        return source
    }()

    /// Нажимает и отпускает клавишу так, будто это сделал пользователь.
    static func press(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.post(tap: .cghidEventTap)
        }
    }
}
