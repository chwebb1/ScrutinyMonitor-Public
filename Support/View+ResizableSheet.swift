import SwiftUI

struct ResizableSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ResizableSheetTracker())
    }
}

struct ResizableSheetTracker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.styleMask.insert(.resizable)
            }
        }
    }
}

extension View {
    func resizableSheet() -> some View {
        self.modifier(ResizableSheetModifier())
    }
}
