import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let interceptor = KeyInterceptor()
    private let caster = Caster()
    private let shaman = ShamanController()
    private lazy var notepad = NotepadWindowController(shaman: shaman)
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Sprite.menuIcon.templateImage(pointSize: 18)
        statusItem.button?.toolTip = "САНБОЙ ШАМАН"
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        shaman.isEnabled = settings.showsShaman

        interceptor.onReturn = { [weak self] keyCode, flags in
            self?.handleReturn(keyCode: keyCode, flags: flags) ?? false
        }
        interceptor.onKeyDown = { [weak self] keyCode, flags in
            self?.handleKeyDown(keyCode: keyCode, flags: flags)
        }
        interceptor.onToggle = { [weak self] in self?.toggleEnabled() }

        startInterceptor(firstLaunch: true)
        updateIcon()
    }

    // MARK: - Клавиатура

    private func handleReturn(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard settings.isEnabled else { return false }
        // Shift/Option/Control+Enter — перенос строки или своё действие приложения, не трогаем.
        guard flags.isDisjoint(with: [.maskShift, .maskAlternate, .maskControl]) else { return false }
        guard let app = NSWorkspace.shared.frontmostApplication, settings.works(in: app.bundleIdentifier) else {
            return false
        }
        // Второй Enter, пока колдуем над первым, проглатываем, чтобы не отправить дважды.
        if caster.isBusy { return true }

        let pid = app.processIdentifier
        // Сам Enter отдаём сразу, а колдуем на следующем витке цикла, чтобы не держать перехват.
        onMain(after: 0) { [weak self] in
            guard let self else { return }
            self.caster.castAndSend(pid: pid, keyCode: keyCode, flags: flags) { [weak self] changed in
                guard let self, changed else { return }
                self.shaman.spell(in: AX.focusedElement(pid: pid))
            }
        }
        return true
    }

    private func handleKeyDown(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard settings.isEnabled, settings.showsShaman else { return }
        guard flags.isDisjoint(with: [.maskCommand, .maskControl]) else { return }
        guard let app = NSWorkspace.shared.frontmostApplication, settings.works(in: app.bundleIdentifier) else { return }
        let pid = app.processIdentifier
        // Даём приложению вставить символ, потом спрашиваем, где каретка.
        onMain(after: 0.03) { [weak self] in
            guard let self, let element = AX.focusedElement(pid: pid), AX.isTextInput(element) else { return }
            self.shaman.typed(in: element)
        }
    }

    // MARK: - Разрешения

    private static let bundleID = Bundle.main.bundleIdentifier ?? "ru.cybertatar.sunboyshaman"
    /// «Мониторинг ввода» спрашиваем один раз за запуск: повторный запрос macOS всё равно не покажет.
    private var askedListenAccess = false

    private func startInterceptor(firstLaunch: Bool = false) {
        if !AX.isTrusted {
            if firstLaunch { explainPermission() }
            AX.requestTrust()
        }
        tryStart()
        if !interceptor.isRunning { waitForPermission() }
    }

    /// Ставит перехват, если macOS уже пускает. Универсальный доступ есть, а перехват
    /// не встал — значит, нужен ещё «Мониторинг ввода».
    private func tryStart() {
        if AX.isTrusted, !interceptor.start(), !askedListenAccess, !CGPreflightListenEventAccess() {
            askedListenAccess = true
            CGRequestListenEventAccess()
        }
        updateIcon()
    }

    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.tryStart()
                if self.interceptor.isRunning {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                }
            }
        }
    }

    /// Что сейчас мешает колдовать — для строки в меню.
    private var accessProblem: String? {
        if interceptor.isRunning { return nil }
        if !AX.isTrusted { return "Нет доступа: «Универсальный доступ»" }
        if !CGPreflightListenEventAccess() { return "Нет доступа: «Мониторинг ввода»" }
        return "Доступ есть, но macOS не пускает — перезапусти шамана"
    }

    @objc private func openListenEventSettings() {
        askedListenAccess = true
        CGRequestListenEventAccess()
        openSettings("Privacy_ListenEvent")
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Перезапуск: новая копия стартует через секунду, когда эта уже закрылась.
    @objc private func relaunch() {
        let path = Bundle.main.bundleURL.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? process.run()
        NSApp.terminate(nil)
    }

    /// Запись в «Универсальном доступе» от прошлой сборки выглядит включённой, но не действует:
    /// macOS помнит подпись старой версии. Сбрасываем и спрашиваем заново.
    @objc private func resetAccess() {
        for service in ["Accessibility", "ListenEvent"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, Self.bundleID]
            try? process.run()
            process.waitUntilExit()
        }
        relaunch()
    }

    private func explainPermission() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Шаману нужен доступ к клавиатуре"
        alert.informativeText = """
            Чтобы колдовать над сообщением при отправке, САНБОЙ ШАМАН перехватывает Enter \
            и читает текст в поле ввода. Включи его в «Системные настройки → \
            Конфиденциальность и безопасность → Универсальный доступ». Текст никуда не уходит.
            """
        alert.addButton(withTitle: "Понятно")
        alert.runModal()
    }

    @objc private func openPermissions() {
        AX.requestTrust()
        openSettings("Privacy_Accessibility")
        startInterceptor()
    }

    // MARK: - Меню

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let title = NSMenuItem(title: "САНБОЙ ШАМАН", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        if !interceptor.isRunning { tryStart() }
        if let problem = accessProblem {
            let status = NSMenuItem(title: problem, action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
            if !AX.isTrusted {
                menu.addItem(item("Открыть «Универсальный доступ»…", #selector(openPermissions)))
            } else if !CGPreflightListenEventAccess() {
                menu.addItem(item("Открыть «Мониторинг ввода»…", #selector(openListenEventSettings)))
            }
            menu.addItem(item("Перезапустить шамана", #selector(relaunch)))
            menu.addItem(item("Сбросить доступ и спросить заново", #selector(resetAccess)))
        }
        menu.addItem(.separator())

        let enabled = item("Колдовать при отправке", #selector(toggleEnabled), state: settings.isEnabled)
        enabled.keyEquivalent = "s"
        enabled.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(enabled)
        menu.addItem(item("Шаман над строкой", #selector(toggleShaman), state: settings.showsShaman))
        menu.addItem(.separator())

        menu.addItem(item("Во всех приложениях", #selector(toggleAllApps), state: settings.allApps))
        menu.addItem(.separator())

        menu.addItem(item("Шаманский блокнот", #selector(openNotepad)))
        menu.addItem(item("Запускать при входе", #selector(toggleLoginItem), state: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector, state: Bool? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let state { item.state = state ? .on : .off }
        return item
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        if !settings.isEnabled { shaman.hide() }
        updateIcon()
    }

    @objc private func toggleShaman() {
        settings.showsShaman.toggle()
        shaman.isEnabled = settings.showsShaman
    }

    @objc private func toggleAllApps() {
        settings.allApps.toggle()
    }

    @objc private func openNotepad() {
        notepad.show()
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Прочее

    /// Значок тускнеет, когда шаман выключен или у него нет доступа.
    private func updateIcon() {
        statusItem.button?.appearsDisabled = !settings.isEnabled || !interceptor.isRunning
    }

    /// Главное меню не видно (приложение живёт в строке меню), но без него
    /// в блокноте не работают ⌘C, ⌘V, ⌘A и ⌘Z.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Закрыть окно", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        appMenu.addItem(NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Правка")
        edit.addItem(NSMenuItem(title: "Отменить", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Повторить", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Вырезать", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Скопировать", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Вставить", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Выбрать все", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit
        main.addItem(editItem)
        return main
    }
}
