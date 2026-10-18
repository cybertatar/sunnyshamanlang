import AppKit
import ApplicationServices

/// Обёртки над Accessibility API: поле ввода в фокусе, его текст и место каретки.
@MainActor
enum AX {
    /// Роли, в которых живёт текст сообщения. В остальных (список чатов, кнопки) Enter не трогаем.
    private static let textRoles: Set<String> = [
        kAXTextAreaRole as String,
        kAXTextFieldRole as String,
        kAXComboBoxRole as String,
        "AXSearchField",
    ]

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Показывает системный запрос на «Универсальный доступ», если его ещё нет.
    @discardableResult
    static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Элемент в фокусе у приложения `pid` (или у системы, если приложение не ответило).
    static func focusedElement(pid: pid_t? = nil) -> AXUIElement? {
        if let pid {
            let app = AXUIElementCreateApplication(pid)
            // Зависшее приложение не должно держать нас дольше полсекунды.
            AXUIElementSetMessagingTimeout(app, 0.5)
            // Electron-приложения открывают дерево доступности только по этому флагу.
            AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            if let element = element(app, kAXFocusedUIElementAttribute) { return element }
        }
        return element(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute)
    }

    static func role(of element: AXUIElement) -> String? {
        string(element, kAXRoleAttribute)
    }

    static func isTextInput(_ element: AXUIElement) -> Bool {
        guard let role = role(of: element) else { return false }
        return textRoles.contains(role)
    }

    /// Текст поля, если приложение его отдаёт.
    static func value(of element: AXUIElement) -> String? {
        string(element, kAXValueAttribute)
    }

    /// Прямоугольник каретки в координатах Cocoa (начало внизу слева).
    static func caretRect(of element: AXUIElement) -> CGRect? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID()
        else { return nil }
        var selection = CFRange()
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &selection) else { return nil }

        let caret = selection.location + selection.length
        // Пустой диапазон у каретки отдают не все поля — тогда берём символ перед ней.
        var candidates = [CFRange(location: caret, length: 0)]
        if caret > 0 { candidates.append(CFRange(location: caret - 1, length: 1)) }

        for var range in candidates {
            guard let rangeValue = AXValueCreate(.cfRange, &range) else { continue }
            var boundsRef: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(
                element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeValue, &boundsRef
            ) == .success,
                let boundsRef, CFGetTypeID(boundsRef) == AXValueGetTypeID()
            else { continue }
            var rect = CGRect.zero
            guard AXValueGetValue(boundsRef as! AXValue, .cgRect, &rect),
                  rect.height > 1, rect.origin != .zero
            else { continue }
            if range.length == 1 {
                rect.origin.x = rect.maxX
                rect.size.width = 0
            }
            return toCocoa(rect)
        }
        return nil
    }

    /// Рамка элемента в координатах Cocoa.
    static func frame(of element: AXUIElement) -> CGRect? {
        var position = CGPoint.zero
        var size = CGSize.zero
        guard axValue(element, kAXPositionAttribute, type: .cgPoint, into: &position),
              axValue(element, kAXSizeAttribute, type: .cgSize, into: &size),
              size.width > 0, size.height > 0
        else { return nil }
        return toCocoa(CGRect(origin: position, size: size))
    }

    /// Куда ставить шамана: над кареткой, а если её не узнать — над левым краем поля.
    static func anchor(for element: AXUIElement) -> CGRect? {
        if let caret = caretRect(of: element) { return caret }
        guard let frame = frame(of: element) else { return nil }
        return CGRect(x: frame.minX + 40, y: frame.maxY - 1, width: 0, height: 1)
    }

    // MARK: - Помощники

    /// Accessibility считает от верхнего левого угла главного экрана, Cocoa — от нижнего.
    private static func toCocoa(_ rect: CGRect) -> CGRect {
        let height = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID()
        else { return nil }
        return (ref as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String, type: AXValueType, into result: UnsafeMutableRawPointer) -> Bool {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXValueGetTypeID()
        else { return false }
        return AXValueGetValue(ref as! AXValue, type, result)
    }
}
