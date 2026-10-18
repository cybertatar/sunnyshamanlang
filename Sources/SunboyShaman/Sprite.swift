import AppKit

/// Пиксельный спрайт: строки символов, каждый символ — цвет из `Palette`, «.» — пусто.
struct Sprite {
    let pixels: [[Character]]
    let width: Int
    let height: Int

    init(_ art: String) {
        let rows = art.split(separator: "\n", omittingEmptySubsequences: true)
            .map { Array($0.trimmingCharacters(in: .whitespaces)) }
        pixels = rows
        width = rows.map(\.count).max() ?? 0
        height = rows.count
    }

    /// Рисует спрайт в контекст с системой координат сверху вниз (flipped).
    func draw(in context: CGContext, at origin: CGPoint, scale: CGFloat) {
        for (y, row) in pixels.enumerated() {
            for (x, symbol) in row.enumerated() {
                guard let color = Palette.colors[symbol] else { continue }
                context.setFillColor(color)
                context.fill(CGRect(
                    x: origin.x + CGFloat(x) * scale,
                    y: origin.y + CGFloat(y) * scale,
                    width: scale,
                    height: scale
                ))
            }
        }
    }

    /// Шаблонная картинка для строки меню: любой непустой символ — пиксель.
    func templateImage(pointSize: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setShouldAntialias(false)
            let scale = rect.width / CGFloat(max(width, height))
            context.setFillColor(NSColor.black.cgColor)
            for (y, row) in pixels.enumerated() {
                for (x, symbol) in row.enumerated() where symbol != "." {
                    context.fill(CGRect(x: CGFloat(x) * scale, y: CGFloat(y) * scale, width: scale, height: scale))
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

enum Palette {
    static let colors: [Character: CGColor] = [
        "K": rgb(0x2A1A12), // контур
        "S": rgb(0xEDB98C), // кожа
        "s": rgb(0xC98A62), // тень кожи
        "Y": rgb(0xFFD23F), // солнце
        "O": rgb(0xFF9F1C), // оранжевое солнце
        "F": rgb(0x6B3E26), // мех шапки
        "f": rgb(0x8E5A3A), // светлый мех
        "R": rgb(0xB8322A), // мантия
        "r": rgb(0x8C2320), // тень мантии
        "T": rgb(0xF2B134), // золотая тесьма
        "W": rgb(0xA0703F), // обод бубна
        "D": rgb(0xF3E0B5), // кожа бубна
        "d": rgb(0xD9BF8A), // тень на бубне
        "B": rgb(0x5A3820), // колотушка
        "w": rgb(0xFFFFFF), // наконечник колотушки
    ]

    /// Цвета искр, которые сыплются с бубна на текст.
    static let sparks: [CGColor] = [rgb(0xFFD23F), rgb(0xFF9F1C), rgb(0xFFFFFF), rgb(0xF2B134)]

    static func rgb(_ hex: UInt32) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
