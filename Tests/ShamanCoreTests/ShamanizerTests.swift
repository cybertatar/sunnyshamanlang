import Foundation
import XCTest
@testable import ShamanCore

final class ShamanizerTests: XCTestCase {
    // MARK: - Как пишет Санбой

    func testSunboyChangesTheMessage() {
        for text in ["Привет", "Ок, буду через 10 минут", "Привет, как дела? Давай встретимся завтра вечером"] {
            let result = Shamanizer.sunboy(text)
            XCTAssertNotEqual(result, text)
            XCTAssertTrue(Shamanizer.isSprinkled(result), result)
        }
    }

    func testSunboyIsStableAndIdempotent() {
        let text = "Мне нужны настоящие друзья, которые помогут звуком. Поможешь? Ответь сразу!"
        let once = Shamanizer.sunboy(text)
        XCTAssertEqual(Shamanizer.sunboy(text), once)
        XCTAssertEqual(Shamanizer.sunboy(once), once)
    }

    func testSunboyKeepsLinksAndEmails() {
        let link = "https://money.yandex.ru/to/410014"
        let mail = "ivan.petrov@mail.ru"
        let result = Shamanizer.sunboy("Скинь ссылку \(link) или напиши на \(mail) пожалуйста")
        XCTAssertTrue(result.contains(link), result)
        XCTAssertTrue(result.contains(mail), result)
    }

    func testSunboyKeepsLettersInOrder() {
        let text = "Мне нужны настоящие друзья, которые помогут звуком, сведением и видеоклипом"
        // Замены букв сводим к одному виду; повторы слов добавляют буквы, поэтому
        // исходный текст должен остаться подпоследовательностью результата.
        let same: [Character: Character] = ["0": "о", "х": "г", "э": "е", "з": "е", "й": "и"]
        let normalize = { (s: String) -> [Character] in
            s.lowercased().compactMap { c in
                let c = same[c] ?? c
                return c.isLetter ? c : nil
            }
        }
        let source = normalize(text)
        var rest = normalize(Shamanizer.sunboy(text))[...]
        for letter in source {
            guard let found = rest.firstIndex(of: letter) else { return XCTFail("потерялась «\(letter)»") }
            rest = rest[rest.index(after: found)...]
        }
    }

    func testSunboyUsesSlang() {
        let result = Shamanizer.sunboy("Что ты сейчас делаешь? Только честно, что вообще происходит").lowercased()
        let spoken = ["шо", "ш0", "щас", "тока", "т0ка", "ваще"]
        XCTAssertTrue(spoken.contains(where: { result.contains($0) }), result)
    }

    func testSunboyIsMostlyCaps() {
        let text = "Слушай я тут подумал что нам надо встретиться и обсудить проект только сейчас не могу давай вечером созвонимся и всё решим"
        let words = Shamanizer.sunboy(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let caps = words.filter { $0.count > 1 && $0 == $0.uppercased() }
        XCTAssertGreaterThan(Double(caps.count) / Double(words.count), 0.4)
    }

    func testSunboyLeavesInnerPunctuationAlone() {
        let result = Shamanizer.sunboy("Кто-то принёс 1,5 литра")
        XCTAssertTrue(result.contains("-т"), result)
        XCTAssertTrue(result.contains("1,5"), result)
    }

    func testSunboyTokenizer() {
        let tokens = Shamanizer.tokenize("Привет, мир! www.site.ru")
        XCTAssertEqual(tokens.map(\.text), ["Привет", ", ", "мир", "! ", "www.site.ru"])
        XCTAssertEqual(tokens.map(\.kind), [.word, .separator, .word, .separator, .keep])
    }
}
