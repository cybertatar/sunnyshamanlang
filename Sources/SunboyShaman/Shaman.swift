import AppKit
import QuartzCore

/// Прозрачная панель поверх всех окон: не забирает фокус, клики проходят насквозь.
final class ShamanPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: ShamanView.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Шаман с бубном и искры, которые он сыплет на текст.
final class ShamanView: NSView {
    static let scale: CGFloat = 3
    static let size = NSSize(width: 170, height: 120)
    /// Точка каретки внутри окна: низ окна стоит на строке, шаман левее каретки.
    static let caret = CGPoint(x: 112, y: ShamanView.size.height)

    private static var shamanOrigin: CGPoint {
        CGPoint(
            x: caret.x - CGFloat(Sprite.idle.width) * scale - 4,
            y: size.height - CGFloat(Sprite.idle.height) * scale
        )
    }

    /// Край бубна, по которому бьёт колотушка (в пикселях спрайта).
    private static let drumPoint = CGPoint(x: 9, y: 19)
    /// Солнце на шапке.
    private static let crownPoint = CGPoint(x: 17, y: 2)

    private struct Spark {
        var position: CGPoint
        var velocity: CGVector
        var life: CGFloat
        let lifetime: CGFloat
        let color: CGColor
        let size: CGFloat
    }

    private var sparks: [Spark] = []
    private var hitUntil: CFTimeInterval = 0
    private var raisedUntil: CFTimeInterval = 0
    private var blinkUntil: CFTimeInterval = 0
    private var nextBlink: CFTimeInterval = 0
    private var jumpLeft: CGFloat = 0
    private let jumpDuration: CGFloat = 0.45
    private var timer: Timer?

    /// Вызывается каждый кадр: контроллер двигает окно за кареткой.
    var onFrame: (() -> Void)?

    override var isFlipped: Bool { true }

    // MARK: - Действия

    /// Удар в бубен на каждое нажатие клавиши.
    func beat() {
        let now = CACurrentMediaTime()
        // Чередуем: удар, замах, удар — пока печатают, рука ходит.
        if now < hitUntil + 0.05 {
            hitUntil = 0
            raisedUntil = now + 0.5
        } else {
            hitUntil = now + 0.12
            raisedUntil = now + 0.6
            emit(count: 3, from: Self.drumPoint, speed: 40...150, angle: (-0.9)...(0.2))
        }
        start()
    }

    /// Заклинание при отправке: прыжок и сноп искр.
    func spell() {
        let now = CACurrentMediaTime()
        hitUntil = now + 0.3
        raisedUntil = now + 0.9
        jumpLeft = jumpDuration
        emit(count: 18, from: Self.drumPoint, speed: 60...220, angle: (-2.6)...(0.4))
        emit(count: 12, from: Self.crownPoint, speed: 40...160, angle: (-2.8)...(-0.3))
        start()
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        sparks.removeAll()
        jumpLeft = 0
    }

    // MARK: - Кадр

    private func emit(count: Int, from point: CGPoint, speed: ClosedRange<CGFloat>, angle: ClosedRange<CGFloat>) {
        let origin = Self.shamanOrigin
        let start = CGPoint(x: origin.x + point.x * Self.scale, y: origin.y + point.y * Self.scale)
        for _ in 0..<count {
            // Угол 0 — вправо, отрицательный — вверх (система координат сверху вниз).
            let a = CGFloat.random(in: angle)
            let v = CGFloat.random(in: speed)
            let lifetime = CGFloat.random(in: 0.5...1.0)
            sparks.append(Spark(
                position: start,
                velocity: CGVector(dx: cos(a) * v, dy: sin(a) * v),
                life: lifetime,
                lifetime: lifetime,
                color: Palette.sparks.randomElement()!,
                size: Bool.random() ? Self.scale : Self.scale * 2
            ))
        }
    }

    private func tick() {
        let dt: CGFloat = 1.0 / 30
        sparks = sparks.compactMap { spark in
            var spark = spark
            spark.life -= dt
            guard spark.life > 0 else { return nil }
            spark.velocity.dy += 380 * dt
            spark.position.x += spark.velocity.dx * dt
            spark.position.y += spark.velocity.dy * dt
            return spark
        }
        jumpLeft = max(0, jumpLeft - dt)

        let now = CACurrentMediaTime()
        if nextBlink == 0 || now > nextBlink {
            blinkUntil = now + 0.14
            nextBlink = now + Double.random(in: 2...5)
        }
        onFrame?()
        needsDisplay = true
    }

    private var pose: Sprite {
        let now = CACurrentMediaTime()
        if now < hitUntil { return .hit }
        if now < raisedUntil { return .up }
        if now < blinkUntil { return .blink }
        return .idle
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.setShouldAntialias(false)
        let scale = Self.scale

        // Прыжок по дуге, с шагом в целый пиксель спрайта.
        let progress = jumpLeft > 0 ? 1 - jumpLeft / jumpDuration : 0
        let lift = (sin(progress * .pi) * 4).rounded() * scale
        let origin = Self.shamanOrigin
        pose.draw(in: context, at: CGPoint(x: origin.x, y: origin.y - lift), scale: scale)

        for spark in sparks {
            let alpha = min(1, spark.life / spark.lifetime * 1.6)
            context.setFillColor(spark.color.copy(alpha: alpha) ?? spark.color)
            let x = (spark.position.x / scale).rounded(.down) * scale
            let y = (spark.position.y / scale).rounded(.down) * scale
            context.fill(CGRect(x: x, y: y, width: spark.size, height: spark.size))
        }
    }
}

/// Показывает шамана над кареткой, ведёт его за ней и прячет, когда печатать перестали.
@MainActor
final class ShamanController {
    private let panel = ShamanPanel()
    private let view = ShamanView(frame: NSRect(origin: .zero, size: ShamanView.size))
    private var target: CGPoint?
    private var hideWork: DispatchWorkItem?
    private var isShown = false

    var isEnabled = true {
        didSet { if !isEnabled { hide() } }
    }

    init() {
        panel.contentView = view
        view.onFrame = { [weak self] in self?.follow() }
    }

    /// Напечатали символ в поле `element`.
    func typed(in element: AXUIElement) {
        guard isEnabled, let anchor = AX.anchor(for: element) else { return }
        typed(at: anchor)
    }

    /// Напечатали символ, каретка в `anchor` (координаты экрана Cocoa).
    func typed(at anchor: CGRect) {
        guard isEnabled else { return }
        show(at: anchor)
        view.beat()
        scheduleHide(after: 2.5)
    }

    /// Сообщение ушло шаманским.
    func spell(in element: AXUIElement?) {
        guard isEnabled else { return }
        if !isShown {
            guard let element, let anchor = AX.anchor(for: element) else { return }
            show(at: anchor)
        }
        view.spell()
        scheduleHide(after: 1.6)
    }

    private func show(at anchor: CGRect) {
        var origin = CGPoint(x: anchor.minX - ShamanView.caret.x, y: anchor.maxY + 1)
        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - ShamanView.size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - ShamanView.size.height)
        }
        target = origin

        if !isShown {
            isShown = true
            panel.setFrameOrigin(origin)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
            view.start()
        }
    }

    /// Плавно догоняем каретку; если она прыгнула далеко — переносим сразу.
    private func follow() {
        guard let target else { return }
        let current = panel.frame.origin
        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = hypot(dx, dy)
        if distance > 400 {
            panel.setFrameOrigin(target)
        } else if distance > 0.5 {
            panel.setFrameOrigin(CGPoint(x: current.x + dx * 0.35, y: current.y + dy * 0.35))
        }
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.hide() }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        guard isShown else { return }
        isShown = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isShown else { return }
                self.panel.orderOut(nil)
                self.view.stop()
            }
        })
    }
}
