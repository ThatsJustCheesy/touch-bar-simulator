import Cocoa

class ActiveAppMenuFocusWatcher {
	private var appWatcher: ActiveAppWatcher?
	private var menuWatcher: SingleAppMenuFocusWatcher?

	typealias MenuFocusChange = SingleAppMenuFocusWatcher.FocusChange
	typealias MenuFocusChangeCallback = SingleAppMenuFocusWatcher.MenuFocusChangeCallback

    var callback: MenuFocusChangeCallback

	init(callback: @escaping MenuFocusChangeCallback) {
		self.callback = callback
		self.appWatcher = ActiveAppWatcher { [weak self] application in
			guard let self = self else {
				return
			}
			guard let application = application else {
				self.menuWatcher = nil
				return
			}
			self.menuWatcher = SingleAppMenuFocusWatcher(for: application, callback: callback)
		}
	}
}

class ActiveAppWatcher {
    private var observer: Any?

    typealias AppSwitchCallback = (_ application: NSRunningApplication?) -> Void

    var callback: AppSwitchCallback

    init(callback: @escaping AppSwitchCallback) {
        self.callback = callback
        self.observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil) { [weak self] notification in
            self?.callback(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

	deinit {
		if let observer = observer {
			NotificationCenter.default.removeObserver(observer)
		}
	}
}

class SingleAppMenuFocusWatcher {
	private var observer: Accessibility.Observer
	private var openMenuCount: Int = 0

	enum FocusChange {
		case opened, closed
	}
    typealias MenuFocusChangeCallback = (FocusChange) -> Void

    var callback: MenuFocusChangeCallback

    init?(for application: NSRunningApplication, callback: @escaping MenuFocusChangeCallback) {
        self.callback = callback
        guard let observer = Accessibility.Observer(for: application) else {
            return nil
        }
        self.observer = observer

		let element = Accessibility.UIElement.forApplication(application)

        for notification in [kAXMenuOpenedNotification, kAXMenuClosedNotification] {
            do {
                try self.observer.register(for: notification, from: element) { [weak self] notification, _ in
					guard let self = self else {
						return
					}
					switch notification {
					case kAXMenuOpenedNotification:
						if self.openMenuCount == 0 {
							self.callback(.opened)
						}
						self.openMenuCount += 1
					case kAXMenuClosedNotification:
						self.openMenuCount -= 1
						if self.openMenuCount == 0 {
							self.callback(.closed)
						}
					default:
						break
                    }
                }
            } catch {
                return nil
            }
        }
    }
}

enum Accessibility {
    struct UIElement {
        let axUIElement: AXUIElement

        init(_ axUIElement: AXUIElement) {
            self.axUIElement = axUIElement
        }

        static func forSystem() -> Self {
            Self(AXUIElementCreateSystemWide())
        }

		static func forApplication(_ application: NSRunningApplication) -> Self {
			forApplication(pid: application.processIdentifier)
		}
        static func forApplication(pid: pid_t) -> Self {
            Self(AXUIElementCreateApplication(pid))
        }
    }

    class Observer {
        let axObserver: AXObserver

        typealias NotificationCallback = (_ notification: String, _ uiElement: UIElement) -> Void

		private var notifications: [(String, UIElement)] = []
        private var notificationCallbacks: [UnsafeMutablePointer<NotificationCallback>] = []

        init(_ axObserver: AXObserver) {
            self.axObserver = axObserver
        }

		convenience init?(for application: NSRunningApplication) {
			self.init(for: application.processIdentifier)
		}
        convenience init?(for pid: pid_t) {
            func receivedNotification(from observer: AXObserver, for element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
				guard let action = refcon?.bindMemory(to: NotificationCallback.self, capacity: 1).pointee else {
                    return
                }
                action(notification as String, UIElement(element))
            }

            var newObserver: AXObserver?
            let error = AXObserverCreate(pid, receivedNotification(from:for:notification:refcon:), &newObserver)
            guard
                error == .success,
                let axObserver = newObserver
            else {
                return nil
            }

			// It is assumed that the user wants to start listening,
			// and on the current runloop so that the thread on which the
			// callback runs is the same as the thread that registered it.
			CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .commonModes)

            self.init(axObserver)
        }

        func register(for notification: String, from uiElement: UIElement, action: @escaping NotificationCallback) throws {
			let actionPointer = UnsafeMutablePointer<NotificationCallback>.allocate(capacity: 1)
			actionPointer.initialize(to: action)
            notificationCallbacks.append(actionPointer)

            let error = AXObserverAddNotification(axObserver, uiElement.axUIElement, notification as CFString, actionPointer)
            guard error == .success else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(error.rawValue), userInfo: nil)
            }
        }

		deinit {
			for actionPointer in notificationCallbacks {
				actionPointer.deinitialize(count: 1)
				actionPointer.deallocate()
			}
		}
    }
}
