import AppKit
import XCTest
@testable import DJAnthemMapper

@MainActor
final class AnthemMapLifecycleWindowAttachmentTests: XCTestCase {
    private final class DelegateSpy: NSObject, NSWindowDelegate {
        var allowClose = true

        private(set) var closeCount = 0
        private(set) var moveCount = 0

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            closeCount += 1
            return allowClose
        }

        func windowDidMove(_ notification: Notification) {
            moveCount += 1
        }
    }

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 320,
                height: 240
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
    }

    func testAttachWithoutOriginalDelegateSucceeds() {
        let window = makeWindow()
        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertTrue(window.delegate === attachment)
        XCTAssertTrue(attachment.isAttached)

        attachment.detach()
    }

    func testAttachPreservesOriginalDelegateForRestoration() {
        let window = makeWindow()
        let original = DelegateSpy()
        window.delegate = original

        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))

        attachment.detach()

        XCTAssertTrue(window.delegate === original)
    }

    func testDoubleAttachToSameWindowIsIdempotent() {
        let window = makeWindow()
        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertTrue(window.delegate === attachment)

        attachment.detach()
    }

    func testDifferentWindowIsRejectedWhileAttached() {
        let first = makeWindow()
        let second = makeWindow()

        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: first))
        XCTAssertFalse(attachment.attach(to: second))
        XCTAssertTrue(first.delegate === attachment)
        XCTAssertFalse(second.delegate === attachment)

        attachment.detach()
    }

    func testOriginalDelegateCanRejectBeforeProtection() {
        let window = makeWindow()
        let original = DelegateSpy()
        original.allowClose = false
        window.delegate = original

        var protectionCount = 0

        let attachment = AnthemMapLifecycleWindowAttachment { _ in
            protectionCount += 1
            return true
        }

        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertFalse(attachment.windowShouldClose(window))
        XCTAssertEqual(original.closeCount, 1)
        XCTAssertEqual(protectionCount, 0)

        attachment.detach()
    }

    func testOriginalApprovalThenConsultsProtection() {
        let window = makeWindow()
        let original = DelegateSpy()
        window.delegate = original

        var protectionCount = 0

        let attachment = AnthemMapLifecycleWindowAttachment { _ in
            protectionCount += 1
            return false
        }

        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertFalse(attachment.windowShouldClose(window))
        XCTAssertEqual(original.closeCount, 1)
        XCTAssertEqual(protectionCount, 1)

        attachment.detach()
    }

    func testProtectionCanPermitClose() {
        let window = makeWindow()
        var count = 0

        let attachment = AnthemMapLifecycleWindowAttachment { _ in
            count += 1
            return true
        }

        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertTrue(attachment.windowShouldClose(window))
        XCTAssertEqual(count, 1)

        attachment.detach()
    }

    func testProtectionCanDeferClose() {
        let window = makeWindow()
        var count = 0

        let attachment = AnthemMapLifecycleWindowAttachment { _ in
            count += 1
            return false
        }

        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertFalse(attachment.windowShouldClose(window))
        XCTAssertEqual(count, 1)

        attachment.detach()
    }

    func testCloseRequestReceivesReplayClosure() {
        let window = makeWindow()

        var replay: AnthemMapLifecycleWindowAttachment.ReplayClose?

        let attachment = AnthemMapLifecycleWindowAttachment { value in
            replay = value
            return false
        }

        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertFalse(attachment.windowShouldClose(window))
        XCTAssertNotNil(replay)

        attachment.detach()
    }

    func testWrongWindowIsRejected() {
        let attached = makeWindow()
        let other = makeWindow()

        var count = 0

        let attachment = AnthemMapLifecycleWindowAttachment { _ in
            count += 1
            return true
        }

        XCTAssertTrue(attachment.attach(to: attached))
        XCTAssertFalse(attachment.windowShouldClose(other))
        XCTAssertEqual(count, 0)

        attachment.detach()
    }

    func testDetachedCloseIsRejected() {
        let window = makeWindow()
        var count = 0

        let attachment = AnthemMapLifecycleWindowAttachment { _ in
            count += 1
            return true
        }

        XCTAssertTrue(attachment.attach(to: window))
        attachment.detach()

        XCTAssertFalse(attachment.windowShouldClose(window))
        XCTAssertEqual(count, 0)
    }

    func testDetachRestoresNilWithoutOriginalDelegate() {
        let window = makeWindow()
        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))
        attachment.detach()

        XCTAssertNil(window.delegate)
        XCTAssertFalse(attachment.isAttached)
    }

    func testDetachRestoresOriginalDelegate() {
        let window = makeWindow()
        let original = DelegateSpy()
        window.delegate = original

        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))
        attachment.detach()

        XCTAssertTrue(window.delegate === original)
        XCTAssertFalse(attachment.isAttached)
    }

    func testDetachDoesNotOverwriteReplacementDelegate() {
        let window = makeWindow()
        let original = DelegateSpy()
        let replacement = DelegateSpy()

        window.delegate = original

        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))

        window.delegate = replacement
        attachment.detach()

        XCTAssertTrue(window.delegate === replacement)
    }

    func testExternalDelegateReplacementMakesProxyInactive() {
        let window = makeWindow()
        let replacement = DelegateSpy()

        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))

        window.delegate = replacement

        XCTAssertFalse(attachment.isAttached)

        attachment.detach()

        XCTAssertTrue(window.delegate === replacement)
    }

    func testRespondsIncludesOriginalDelegateSelector() {
        let window = makeWindow()
        let original = DelegateSpy()
        window.delegate = original

        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))

        let selector = #selector(NSWindowDelegate.windowDidMove(_:))

        XCTAssertTrue(original.responds(to: selector))
        XCTAssertTrue(attachment.responds(to: selector))

        attachment.detach()
    }

    func testForwardingTargetPreservesOriginalDelegateCallback() {
        let window = makeWindow()
        let original = DelegateSpy()
        window.delegate = original

        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))

        let selector = #selector(NSWindowDelegate.windowDidMove(_:))
        let target = attachment.forwardingTarget(for: selector)

        XCTAssertTrue(target as AnyObject === original)

        original.windowDidMove(
            Notification(
                name: NSWindow.didMoveNotification,
                object: window
            )
        )

        XCTAssertEqual(original.moveCount, 1)

        attachment.detach()
    }

    func testCloseSelectorIsNotForwarded() {
        let window = makeWindow()
        let original = DelegateSpy()
        window.delegate = original

        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))

        let selector = #selector(NSWindowDelegate.windowShouldClose(_:))

        XCTAssertNil(attachment.forwardingTarget(for: selector))

        attachment.detach()
    }

    func testAttachmentStateClearsAfterDetach() {
        let window = makeWindow()
        let attachment = AnthemMapLifecycleWindowAttachment { _ in true }

        XCTAssertTrue(attachment.attach(to: window))
        XCTAssertTrue(attachment.isAttached)

        attachment.detach()

        XCTAssertFalse(attachment.isAttached)
    }
}
