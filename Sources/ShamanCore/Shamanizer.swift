/// Колдовство над сообщением: как пишет сам Пророк Санбой (`Sunboy.swift`).
public enum Shamanizer {
    /// Так уходит сообщение.
    public static func transform(_ text: String) -> String {
        sunboy(text)
    }

    /// По такой пачке понимаем, что текст уже заколдован, и второй раз не колдуем.
    static let alreadySprinkled = [",,,,", "...."]

    static func isSprinkled(_ text: String) -> Bool {
        alreadySprinkled.contains(where: { text.contains($0) })
    }

    static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    /// Свой хеш: системный `Hasher` в каждом запуске разный, а нам нужна стабильность.
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        // Перемешиваем биты, чтобы младшие разряды тоже зависели от всего слова.
        hash ^= hash >> 33
        hash = hash &* 0xff51_afd7_ed55_8ccd
        hash ^= hash >> 33
        return hash
    }
}
