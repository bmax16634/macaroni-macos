import AppKit
import QuartzCore

struct WindowSnapPreviewTarget: Equatable {
    let action: WindowSnapAction
    let frame: CGRect

    init(action: WindowSnapAction, visibleFrame: CGRect) {
        self.action = action
        frame = WindowSnapGeometry.frame(for: action, in: visibleFrame)
    }
}

@MainActor
final class WindowSnapPreviewController {
    private static let showDuration: TimeInterval = 0.07
    private static let hideDuration: TimeInterval = 0.05

    private let panel: NSPanel
    private var currentTarget: WindowSnapPreviewTarget?
    private var transitionGeneration = 0

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.animationBehavior = .none
        panel.backgroundColor = .clear
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary,
        ]
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.alphaValue = 0
        panel.contentView = WindowSnapPreviewView(frame: .zero)
    }

    func show(action: WindowSnapAction, on screen: NSScreen) {
        let target = WindowSnapPreviewTarget(action: action, visibleFrame: screen.visibleFrame)
        guard target != currentTarget || !panel.isVisible else { return }

        transitionGeneration &+= 1
        currentTarget = target
        panel.setFrame(target.frame, display: false)

        guard !panel.isVisible else {
            panel.alphaValue = 1
            return
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        animateAlpha(to: 1, duration: Self.showDuration)
    }

    func hide(animated: Bool) {
        guard currentTarget != nil else {
            if !animated, panel.isVisible {
                transitionGeneration &+= 1
                panel.alphaValue = 0
                panel.orderOut(nil)
            }
            return
        }

        currentTarget = nil
        transitionGeneration &+= 1
        let generation = transitionGeneration
        let duration = animated ? Self.hideDuration : 0

        guard duration > 0, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.alphaValue = 0
            panel.orderOut(nil)
            return
        }

        animateAlpha(to: 0, duration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self,
                  self.transitionGeneration == generation,
                  self.currentTarget == nil else { return }
            self.panel.orderOut(nil)
        }
    }

    private func animateAlpha(to value: CGFloat, duration: TimeInterval) {
        let resolvedDuration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : duration
        guard resolvedDuration > 0 else {
            panel.alphaValue = value
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = resolvedDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = value
        }
    }
}

private final class WindowSnapPreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 2
        layer?.masksToBounds = true
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
    }
}
