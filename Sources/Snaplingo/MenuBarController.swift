import AppKit

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        configure()
    }

    private func configure() {
        if let image = Self.menuBarImage() {
            statusItem.button?.image = image
            statusItem.button?.imagePosition = .imageOnly
        } else {
            statusItem.button?.title = "Snaplingo"
        }
        statusItem.button?.toolTip = "Snaplingo 截图翻译"

        let menu = NSMenu()
        menu.addItem(captureItem(title: "截图", action: #selector(capture), shortcut: HotkeyAction.capture.defaultShortcut))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    private func captureItem(title: String, action: Selector, shortcut: HotkeyBinding) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: shortcut.keyEquivalent)
        item.keyEquivalentModifierMask = shortcut.modifierFlags
        return item
    }

    private static func menuBarImage() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "menu-bar-iconTemplate", withExtension: "png") else {
            return nil
        }
        let image = NSImage(contentsOf: url)
        image?.size = NSSize(width: 20, height: 20)
        image?.isTemplate = true
        return image
    }

    @objc private func capture() {
        coordinator?.capture()
    }

    @objc private func openSettings() {
        coordinator?.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
