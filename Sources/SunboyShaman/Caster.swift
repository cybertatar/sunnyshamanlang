import AppKit
import ShamanCore

/// Колдует при отправке: меняет текст в поле на шаманский и нажимает Enter заново.
///
/// Текст читаем через Accessibility, а если приложение его не отдаёт — копируем (⌘A, ⌘C).
/// Обратно кладём вставкой (⌘A, ⌘V): её понимают все приложения, в отличие от
/// прямой записи значения поля, которую веб-поля и Electron часто не замечают.
/// Буфер обмена потом возвращаем как был.
@MainActor
final class Caster {
    private(set) var isBusy = false

    /// Пауза, за которую приложение успевает обработать наши нажатия.
    private let keyDelay: TimeInterval = 0.08
    private let copyDelay: TimeInterval = 0.15
    private let restoreDelay: TimeInterval = 0.6

    /// `completion(true)`, если текст поменялся.
    func castAndSend(pid: pid_t, keyCode: CGKeyCode, flags: CGEventFlags, completion: @escaping @MainActor (Bool) -> Void) {
        isBusy = true
        let sendFlags = flags.intersection(.maskCommand)
        let finish: @MainActor (Bool) -> Void = { [weak self] changed in
            KeyInterceptor.press(keyCode, flags: sendFlags)
            self?.isBusy = false
            completion(changed)
        }

        guard let element = AX.focusedElement(pid: pid), AX.isTextInput(element) else {
            finish(false)
            return
        }

        if let text = AX.value(of: element) {
            replace(text, clipboard: nil, finish: finish)
            return
        }

        // Поле не отдаёт текст — копируем его сами.
        let clipboard = ClipboardSnapshot()
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount
        KeyInterceptor.press(KeyInterceptor.Key.a, flags: .maskCommand)
        KeyInterceptor.press(KeyInterceptor.Key.c, flags: .maskCommand)
        onMain(after: copyDelay) { [weak self] in
            guard let self else { return }
            let copied = pasteboard.changeCount != before ? pasteboard.string(forType: .string) : nil
            guard let copied else {
                clipboard.restore()
                finish(false)
                return
            }
            self.replace(copied, clipboard: clipboard, finish: finish)
        }
    }

    private func replace(_ text: String, clipboard: ClipboardSnapshot?, finish: @escaping @MainActor (Bool) -> Void) {
        let shaman = Shamanizer.transform(text)
        guard !text.isEmpty, shaman != text else {
            clipboard?.restore()
            finish(false)
            return
        }

        let snapshot = clipboard ?? ClipboardSnapshot()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shaman, forType: .string)
        // Менеджеры буфера обмена не сохраняют такие записи в историю.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let ours = pasteboard.changeCount

        KeyInterceptor.press(KeyInterceptor.Key.a, flags: .maskCommand)
        KeyInterceptor.press(KeyInterceptor.Key.v, flags: .maskCommand)
        onMain(after: keyDelay) {
            finish(true)
        }
        onMain(after: keyDelay + restoreDelay) {
            // Если за это время пользователь что-то скопировал сам — не трогаем.
            if pasteboard.changeCount == ours { snapshot.restore() }
        }
    }
}

/// Копия буфера обмена со всеми типами данных.
struct ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard = .general) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var data: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let value = item.data(forType: type) { data[type] = value }
            }
            return data
        }
    }

    func restore(_ pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let restored = items.map { data -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, value) in data { item.setData(value, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}

/// Выполнить на главном потоке через `delay` секунд.
func onMain(after delay: TimeInterval, _ work: @escaping @MainActor () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        MainActor.assumeIsolated { work() }
    }
}
