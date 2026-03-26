import SwiftUI

#if canImport(AppKit)
import AppKit

public struct WindowChromeConfigurator: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configure(window)
            }
        }
    }

    private func configure(_ window: NSWindow) {
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.styleMask.remove(.fullSizeContentView)
        window.toolbarStyle = .unified
        window.toolbar?.showsBaselineSeparator = true
    }
}
#endif
