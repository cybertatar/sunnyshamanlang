/// Стиль «как пишет Санбой» — по его настоящим сообщениям:
/// «В ТРУДНЫЙ сейчас МОМЕНТ..враги--..мне это не надо .....поможешь ?....ответь сразу.НЕ ОТВЕТИШЬ».
///
/// Прототип с теми же числами — `tools/style/sunboy.py`: меняешь вероятности тут — меняй и там.
/// Решения «случайные», но зависят от соседних слов, поэтому одна фраза колдуется одинаково,
/// а превью в блокноте не мигает при наборе.
extension Shamanizer {
    public static func sunboy(_ text: String) -> String {
        if isSprinkled(text) { return text }
        let tokens = tokenize(text)
        var output = tokens.map(\.text)

        // Слова: капс длинными кусками, «0» вместо «о» и прочие замены, словечки, повторы.
        var caps = false
        var previous = ""
        var wordNumber = 0
        for (index, token) in tokens.enumerated() {
            switch token.kind {
            case .keep:
                previous = token.text
            case .separator:
                continue
            case .word:
                let hash = fnv1a("w\u{1F}" + previous + "\u{1F}" + token.text)
                // Капс тянется длинными кусками: войти в него легко, выйти трудно (~70% слов капсом).
                if wordNumber > 0, hash % 100 < (caps ? 16 : 50) { caps.toggle() }
                let spoken = (hash >> 28) % 100 < 85 ? slangWord(token.text) : token.text
                var word: String
                if caps {
                    word = spoken.uppercased()
                } else {
                    word = spoken.lowercased()
                    if wordNumber == 0 { word = word.prefix(1).uppercased() + word.dropFirst() }
                }
                if (hash >> 8) % 100 < 65 { word = swapLetters(word) }
                // Повтор для нажима: «ДРУЗЬЯ,,НАСТОЯЩИЕ,,,,,,».
                if caps, token.text.count >= 4, (hash >> 36) % 100 < 9 {
                    word += String(repeating: ",", count: 2 + Int((hash >> 40) % 5)) + word
                }
                output[index] = word
                previous = token.text
                wordNumber += 1
            }
        }

        // Промежутки и знаки препинания.
        for (index, token) in tokens.enumerated() where token.kind == .separator && index > 0 {
            let left = tokens[index - 1]
            let right = index + 1 < tokens.count ? tokens[index + 1] : nil
            if left.kind == .keep || right?.kind == .keep || token.text.contains("\n") { continue }
            // «кто-то», «1,5», «:)» без пробелов не трогаем.
            if right != nil, !token.text.contains(where: \.isWhitespace) { continue }

            let hash = fnv1a("g\u{1F}" + left.text + "\u{1F}" + token.text + "\u{1F}" + (right?.text ?? ""))
            let dots = { (low: Int, high: Int) in repeated(".", hash: hash, low, high) }
            let commas = { (low: Int, high: Int) in repeated(",", hash: hash, low, high) }

            var result = ""
            if token.text == " " {
                switch hash % 1000 {
                case ..<380: result = " "
                case ..<610: result = dots(2, 13)
                case ..<800: result = commas(2, 6)
                case ..<850: result = "--.."
                case ..<910: result = " " + dots(3, 6)
                case ..<960: result = ""
                default: result = ".. "
                }
            } else {
                for character in token.text where !character.isWhitespace {
                    switch character {
                    case ".", "…": result += dots(2, 16)
                    case ",": result += commas(2, 5)
                    case "!": result += "!!"
                    case "?": result += " ?" + dots(2, 5)
                    case "—", "–", "-": result += (hash >> 20) & 1 == 1 ? " —" : "--"
                    default: result.append(character)
                    }
                }
                if right != nil, (hash >> 24) % 100 < 20 { result += " " }
            }
            output[index] = result
        }

        // Сообщение без точки в конце иногда затухает многоточием.
        if let last = tokens.last, last.kind == .word {
            let hash = fnv1a("e\u{1F}" + last.text)
            if hash % 100 < 45 { output.append(repeated(".", hash: hash, 3, 10)) }
        }
        var result = output.joined()
        // Без длинной пачки повторное колдовство (Enter на переносе строки) перемешало бы
        // регистр заново, а с ней `isSprinkled` узнаёт уже заколдованный текст.
        if !isSprinkled(result), !result.isEmpty {
            result += repeated(".", hash: fnv1a("z\u{1F}" + text), 4, 9)
        }
        return result
    }

    // MARK: - Разбор на слова

    struct Token: Equatable {
        enum Kind { case word, separator, keep }
        let kind: Kind
        var text: String
    }

    /// Слова, разделители (пробелы и знаки) и неприкосновенное: ссылки и почта.
    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []

        func addSeparator(_ piece: String) {
            if let last = tokens.last, last.kind == .separator {
                tokens[tokens.count - 1].text += piece
            } else {
                tokens.append(Token(kind: .separator, text: piece))
            }
        }

        func flush(_ chunk: String) {
            guard !chunk.isEmpty else { return }
            if isProtected(chunk) {
                tokens.append(Token(kind: .keep, text: chunk))
                return
            }
            var current = ""
            var currentIsWord = false
            for character in chunk {
                let isWord = isWordCharacter(character)
                if !current.isEmpty, isWord != currentIsWord {
                    if currentIsWord { tokens.append(Token(kind: .word, text: current)) } else { addSeparator(current) }
                    current = ""
                }
                current.append(character)
                currentIsWord = isWord
            }
            if !current.isEmpty {
                if currentIsWord { tokens.append(Token(kind: .word, text: current)) } else { addSeparator(current) }
            }
        }

        var chunk = ""
        for character in text {
            if character.isWhitespace {
                flush(chunk)
                chunk = ""
                addSeparator(String(character))
            } else {
                chunk.append(character)
            }
        }
        flush(chunk)
        return tokens
    }

    /// Ссылки и почту не трогаем, иначе они перестанут открываться.
    static func isProtected(_ chunk: String) -> Bool {
        if chunk.contains("://") || chunk.lowercased().hasPrefix("www.") { return true }
        guard let at = chunk.lastIndex(of: "@") else { return false }
        return chunk[chunk.index(after: at)...].contains(".")
    }

    /// Замены букв, как в редакторе на сайте Санбоя.
    private static func swapLetters(_ word: String) -> String {
        var result = ""
        for character in word {
            switch character {
            case "о", "О": result.append("0")
            case "г": result.append("х")
            case "Г": result.append("Х")
            case "е", "з": result.append("э")
            case "Е", "З": result.append("Э")
            case "й": result.append("и")
            case "Й": result.append("И")
            default: result.append(character)
            }
        }
        return result
    }

    /// Разговорные словечки, как «НУ ШО» у Санбоя.
    static let slang: [String: String] = [
        "что": "шо", "чтобы": "шобы", "чего": "чо", "сейчас": "щас", "вообще": "ваще",
        "только": "тока", "ничего": "ничо", "конечно": "канешно", "пожалуйста": "пажалуста",
        "здравствуйте": "здрасте", "спасибо": "спасиба", "тебя": "тибя", "меня": "миня",
        "сегодня": "седня", "хорошо": "харашо", "короче": "карочи", "нормально": "нармальна",
    ]

    private static func slangWord(_ word: String) -> String {
        guard let spoken = slang[word.lowercased()] else { return word }
        if word.count > 1, word == word.uppercased() { return spoken.uppercased() }
        if word.first?.isUppercase == true { return spoken.prefix(1).uppercased() + spoken.dropFirst() }
        return spoken
    }

    private static func repeated(_ mark: Character, hash: UInt64, _ low: Int, _ high: Int) -> String {
        let count = low + Int((hash >> 12) % UInt64(high - low + 1))
        return String(repeating: mark, count: count)
    }
}
