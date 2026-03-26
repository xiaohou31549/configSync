import SwiftUI

#if canImport(AppKit)
import AppKit

@MainActor
public final class WindowChromeMetrics: ObservableObject {
    @Published public var topInset: CGFloat = 0

    public init() {}

    public func update(from window: NSWindow) {
        let inset = max(0, window.frame.maxY - window.contentLayoutRect.maxY)
        if abs(topInset - inset) > 0.5 {
            topInset = inset
        }
    }
}

public struct WindowChromeReader: NSViewRepresentable {
    @ObservedObject var metrics: WindowChromeMetrics

    public init(metrics: WindowChromeMetrics) {
        self.metrics = metrics
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                metrics.update(from: window)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                metrics.update(from: window)
            }
        }
    }
}
#endif
