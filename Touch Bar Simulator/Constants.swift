import Foundation
import Defaults
import KeyboardShortcuts

struct Constants {
	static let windowAutosaveName = "TouchBarWindow"
}

extension Defaults.Keys {
	static let windowTransparency = Key<Double>("windowTransparency", default: 0.75)
	static let windowDocking = Key<TouchBarWindow.Docking>("windowDocking", default: .floating)
	static let windowPadding = Key<Double>("windowPadding", default: 0.0)
	static let showOnAllDesktops = Key<Bool>("showOnAllDesktops", default: false)
	static let lastFloatingPosition = Key<CGPoint?>("lastFloatingPosition")
	static let autohideMode = Key<TouchBarWindow.AutohideMode?>("autohideMode", default: nil)
	static let lastWindowDockingWithDockBehavior = Key<TouchBarWindow.Docking>("windowDockingWithDockBehavior", default: .dockedToTop)
	static let lastUndockedAutohideMode = Key<TouchBarWindow.AutohideMode?>("lastUndockedAutohideMode", default: nil)
}

extension KeyboardShortcuts.Name {
	static let toggleTouchBar = Name("toggleTouchBar")
}
