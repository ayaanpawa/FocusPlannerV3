import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - NSColor → UIColor-style API shim (macOS)
//
// On iOS, code like `Color(.systemBackground)` resolves to
// `Color(UIColor.systemBackground)`. NSColor on macOS doesn't have those
// exact static properties, so we add them here mapped to the closest
// macOS equivalents. This means the same view code compiles unchanged.

#if os(macOS)
extension NSColor {
    static var systemBackground:                 NSColor { windowBackgroundColor }
    static var secondarySystemBackground:        NSColor { underPageBackgroundColor }
    static var tertiarySystemBackground:         NSColor { controlBackgroundColor }
    static var systemGroupedBackground:          NSColor { windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { controlBackgroundColor }
    static var tertiarySystemGroupedBackground:  NSColor { controlBackgroundColor }
    static var systemFill:                       NSColor { controlBackgroundColor }
    static var secondarySystemFill:              NSColor { controlBackgroundColor }
    static var tertiarySystemFill:               NSColor { unemphasizedSelectedContentBackgroundColor }
    static var quaternarySystemFill:             NSColor { controlBackgroundColor }
    static var systemGray2:                      NSColor { secondaryLabelColor }
    static var systemGray3:                      NSColor { tertiaryLabelColor }
    static var systemGray4:                      NSColor { quaternaryLabelColor }
    static var systemGray5:                      NSColor { quaternaryLabelColor }
    static var systemGray6:                      NSColor { quaternaryLabelColor }
    static var separator:                        NSColor { separatorColor }
    static var label:                            NSColor { labelColor }
    static var tertiaryLabel:                    NSColor { tertiaryLabelColor }
    static var quaternaryLabel:                  NSColor { quaternaryLabelColor }
}
#endif

// MARK: - View modifier shims
//
// iOS-only modifiers are wrapped so the same call site works on both
// platforms. On macOS the modifier becomes a no-op (or a sensible
// equivalent).

extension View {
    @ViewBuilder
    func navBarInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func navBarHidden() -> some View {
        #if os(iOS)
        self.navigationBarHidden(true)
        #else
        self
        #endif
    }

    @ViewBuilder
    func stackNavStyle() -> some View {
        #if os(iOS)
        self.navigationViewStyle(.stack)
        #else
        self
        #endif
    }

    @ViewBuilder
    func noAutoCap() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func urlKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.URL)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberPadKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func insetGroupedList() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.inset)
        #endif
    }
}

// MARK: - macOS window styling
//
// Makes the whole window (including the title-bar area where the tabs sit)
// use the cream background instead of the default white/translucent material.

#if os(macOS)
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    final class Coordinator {
        var configured = false
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        scheduleConfigureOnce(view: v, coordinator: context.coordinator)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Run only on first attachment — never on subsequent SwiftUI updates,
        // otherwise we'd ping-pong with AppKit and beach-ball the main thread.
        scheduleConfigureOnce(view: nsView, coordinator: context.coordinator)
    }

    private func scheduleConfigureOnce(view: NSView, coordinator: Coordinator) {
        guard !coordinator.configured else { return }
        DispatchQueue.main.async {
            guard !coordinator.configured, let w = view.window else { return }
            coordinator.configured = true
            configure(w)
        }
    }
}

extension View {
    /// Paint the entire macOS window — including the title bar — in `color`.
    func creamWindow(_ color: Color) -> some View {
        background(
            WindowAccessor { window in
                window.backgroundColor = NSColor(color)
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
            }
        )
    }
}
#else
extension View {
    func creamWindow(_ color: Color) -> some View { self }
}
#endif

// MARK: - Toolbar placement shims

extension ToolbarItemPlacement {
    /// `.navigationBarLeading` on iOS, `.navigation` on macOS.
    static var barLeading: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarLeading
        #else
        return .navigation
        #endif
    }

    /// `.navigationBarTrailing` on iOS, `.primaryAction` on macOS.
    static var barTrailing: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }
}
