import AppKit
import ShamanCore

/// Шаманский блокнот: пишешь как обычно, а снизу видно, как сообщение уйдёт.
/// Нужен, чтобы попробовать стиль и шамана без мессенджера.
@MainActor
final class NotepadWindowController: NSWindowController, NSTextViewDelegate {
    private let shaman: ShamanController
    private let textView: NSTextView
    private let preview: NSTextField

    init(shaman: ShamanController) {
        self.shaman = shaman

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Шаманский блокнот"
        window.minSize = NSSize(width: 320, height: 200)
        window.isReleasedWhenClosed = false
        window.center()

        let hint = NSTextField(wrappingLabelWithString:
            "Пиши тут — снизу видно, как сообщение уйдёт. В мессенджерах колдовство срабатывает при отправке (Enter), Shift+Enter — без колдовства.")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .bezelBorder
        let textView = scroll.documentView as! NSTextView
        self.textView = textView
        textView.font = .systemFont(ofSize: 15)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 8)

        let preview = NSTextField(wrappingLabelWithString: "")
        preview.isSelectable = true
        preview.font = .systemFont(ofSize: 13)
        preview.placeholderString = "Так уйдёт: …"
        self.preview = preview

        let stack = NSStackView(views: [hint, scroll, preview])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            hint.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            preview.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
        window.contentView = content

        super.init(window: window)
        textView.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(textView)
    }

    func textDidChange(_ notification: Notification) {
        // Пока набирается составной символ (диакритика, японская раскладка), не мешаем.
        guard !textView.hasMarkedText() else { return }

        let message = Shamanizer.transform(textView.string)
        preview.stringValue = message.isEmpty ? "" : "Так уйдёт: \(message)"

        // Каретку берём у самого текстового поля: Accessibility к себе же с главного потока зависнет.
        let caret = textView.selectedRange()
        let rect = textView.firstRect(forCharacterRange: NSRange(location: caret.location, length: 0), actualRange: nil)
        if rect.height > 0 {
            shaman.typed(at: rect)
        }
    }
}
