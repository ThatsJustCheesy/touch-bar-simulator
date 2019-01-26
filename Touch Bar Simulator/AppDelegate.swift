import Cocoa
import Sparkle
import Defaults

final class AppDelegate: NSObject, NSApplicationDelegate {
	lazy var window = with(TouchBarWindow()) {
		$0.alphaValue = CGFloat(defaults[.windowTransparency])
	}

	lazy var statusItem = with(NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)) {
		$0.menu = statusMenu
		$0.button!.image = NSImage(named: "AppIcon") // TODO: Add proper icon
		$0.button!.toolTip = "Right or option-click for menu"
	}
	lazy var statusMenu = with(NSMenu()) {
		$0.delegate = self
	}

	func applicationWillFinishLaunching(_ notification: Notification) {
		UserDefaults.standard.register(defaults: [
			"NSApplicationCrashOnExceptions": true
		])
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.servicesProvider = self

		_ = SUUpdater()

		let view = window.contentView!
		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.black.cgColor

		let touchBarView = TouchBarView()
		window.setContentSize(touchBarView.bounds.adding(padding: 5).size)
		touchBarView.frame = touchBarView.frame.centered(in: view.bounds)
		view.addSubview(touchBarView)

		window.center()
		var origin = window.frame.origin
		origin.y = 100
		window.setFrameOrigin(origin)

		window.setFrameUsingName(Constants.windowAutosaveName)
		window.setFrameAutosaveName(Constants.windowAutosaveName)

		window.orderFront(nil)

		_ = statusItem

		docking = defaults[.windowDocking]
		showOnAllDesktops = defaults[.showOnAllDesktops]
	}

	@objc
	func captureScreenshot() {
		let KEY_6: CGKeyCode = 0x58
		pressKey(keyCode: KEY_6, flags: [.maskShift, .maskCommand])
	}

	@objc
	func toggleView(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
		toggleView()
	}

	func toggleView() {
		window.setIsVisible(!window.isVisible)
	}

	var docking: TouchBarWindow.Docking = .floating {
		didSet {
			defaults[.windowDocking] = docking

			statusMenuDockingItems.forEach { $0.state = .off }

			let onItem: NSMenuItem
			switch docking {
			case .floating:
				onItem = statusMenuDockingItemFloating
			case .dockedToTop:
				onItem = statusMenuDockingItemDockedToTop
			case .dockedToBottom:
				onItem = statusMenuDockingItemDockedToBottom
			}
			onItem.state = .on

			window.docking = docking
		}
	}

	var showOnAllDesktops: Bool = false {
		didSet {
			defaults[.showOnAllDesktops] = showOnAllDesktops
			statusMenuItemShowOnAllDesktops.state = showOnAllDesktops ? .on : .off
			window.showOnAllDesktops = showOnAllDesktops
		}
	}

	private lazy var statusMenuDockingItemFloating = with(NSMenuItem(title: "Floating", action: nil, keyEquivalent: "")) {
		$0.onAction = { _ in
			self.docking = .floating
		}
	}
	private lazy var statusMenuDockingItemDockedToTop = with(NSMenuItem(title: "Docked to Top", action: nil, keyEquivalent: "")) {
		$0.onAction = { _ in
			self.docking = .dockedToTop
		}
	}
	private lazy var statusMenuDockingItemDockedToBottom = with(NSMenuItem(title: "Docked to Bottom", action: nil, keyEquivalent: "")) {
		$0.onAction = { _ in
			self.docking = .dockedToBottom
		}
	}
	private lazy var statusMenuDockingItems: [NSMenuItem] = [
		statusMenuDockingItemFloating,
		statusMenuDockingItemDockedToTop,
		statusMenuDockingItemDockedToBottom
	].map { $0.indentationLevel = 1; return $0 }

	private lazy var statusMenuItemShowOnAllDesktops = with(NSMenuItem(title: "Show on All Desktops", action: nil, keyEquivalent: "")) {
		$0.onAction = { _ in
			self.showOnAllDesktops = !self.showOnAllDesktops
		}
	}

	private lazy var statusMenuOptionItems: [NSMenuItem] = [

		NSMenuItem(title: "Docking", action: nil, keyEquivalent: ""),
		statusMenuDockingItemFloating,
		statusMenuDockingItemDockedToTop,
		statusMenuDockingItemDockedToBottom,

		NSMenuItem.separator(),

		statusMenuItemShowOnAllDesktops,

		NSMenuItem.separator(),

		NSMenuItem(title: "Quit Touch Bar Simulator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")

	]
}

private func statusItemShouldShowMenu() -> Bool {
	return !NSApp.leftMouseIsDown() || NSApp.optionKeyIsDown()
}

extension AppDelegate: NSMenuDelegate {
	func menuNeedsUpdate(_ menu: NSMenu) {
		guard statusItemShouldShowMenu() else {
			menu.removeAllItems()
			return
		}
		guard menu.numberOfItems != statusMenuOptionItems.count else {
			return
		}
		menu.removeAllItems()
		if #available(macOS 10.14, *) {
			menu.items = statusMenuOptionItems
		} else {
			statusMenuOptionItems.forEach { menu.addItem($0) }
		}
	}

	func menuWillOpen(_ menu: NSMenu) {
		guard !statusItemShouldShowMenu() else {
			return
		}
		statusItemButtonClicked()
	}

	func statusItemButtonClicked() {
		toggleView()
		if window.isVisible { window.orderFront(nil) }
	}
}
