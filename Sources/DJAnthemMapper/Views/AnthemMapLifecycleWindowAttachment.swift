import AppKit

@MainActor
final class AnthemMapLifecycleWindowAttachment: NSObject, NSWindowDelegate {
    typealias ReplayClose = @MainActor () -> Void
    typealias CloseRequest = @MainActor (@escaping ReplayClose) -> Bool

    private weak var window: NSWindow?

    // NSWindow.delegate is weak. Keep the displaced delegate alive while
    // this proxy is installed so it remains available for forwarding and
    // restoration.
    private var originalDelegate: NSWindowDelegate?

    private let requestClose: CloseRequest

    private var attached = false
    private var admitNextCloseReplay = false

    init(requestClose: @escaping CloseRequest) {
        self.requestClose = requestClose
        super.init()
    }

    var isAttached: Bool {
        guard attached, let window else {
            return false
        }

        return window.delegate === self
    }

    @discardableResult
    func attach(to window: NSWindow) -> Bool {
        if attached {
            return self.window === window && window.delegate === self
        }

        guard window.delegate !== self else {
            return false
        }

        let existingDelegate = window.delegate

        self.window = window
        originalDelegate = existingDelegate

        window.delegate = self

        guard window.delegate === self else {
            self.window = nil
            originalDelegate = nil
            attached = false
            return false
        }

        attached = true
        return true
    }

    func detach() {
        guard attached else {
            clearState()
            return
        }

        // Never overwrite a delegate installed by somebody else after us.
        if let window, window.delegate === self {
            window.delegate = originalDelegate
        }

        clearState()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard
            attached,
            let attachedWindow = window,
            sender === attachedWindow,
            attachedWindow.delegate === self
        else {
            return false
        }

        if admitNextCloseReplay {
            admitNextCloseReplay = false
            return originalDelegateAllowsClose(sender)
        }

        guard originalDelegateAllowsClose(sender) else {
            return false
        }

        return requestClose(makeReplayClosure(for: sender))
    }

    override func responds(to selector: Selector!) -> Bool {
        if super.responds(to: selector) {
            return true
        }

        return originalDelegate?.responds(to: selector) ?? false
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        // This selector belongs to the protection proxy itself.
        if selector == #selector(NSWindowDelegate.windowShouldClose(_:)) {
            return nil
        }

        if let originalDelegate,
           originalDelegate.responds(to: selector) {
            return originalDelegate
        }

        return super.forwardingTarget(for: selector)
    }

    private func originalDelegateAllowsClose(_ window: NSWindow) -> Bool {
        guard let originalDelegate else {
            return true
        }

        guard originalDelegate.responds(
            to: #selector(NSWindowDelegate.windowShouldClose(_:))
        ) else {
            return true
        }

        return originalDelegate.windowShouldClose?(window) ?? true
    }

    private func makeReplayClosure(
        for expectedWindow: NSWindow
    ) -> ReplayClose {
        { [weak self, weak expectedWindow] in
            guard
                let self,
                let expectedWindow,
                self.attached,
                self.window === expectedWindow,
                expectedWindow.delegate === self
            else {
                return
            }

            self.admitNextCloseReplay = true
            expectedWindow.performClose(nil)
        }
    }

    private func clearState() {
        window = nil
        originalDelegate = nil
        attached = false
        admitNextCloseReplay = false
    }
}
