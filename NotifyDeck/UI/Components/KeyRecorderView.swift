import SwiftUI
import AppKit

/// キーボードショートカットレコーダー
struct KeyRecorderView: View {
    @Binding var shortcut: KeyboardShortcut
    @State private var isRecording = false

    var body: some View {
        HStack {
            Button(action: { isRecording = true }) {
                HStack {
                    if shortcut.isDisabled {
                        Text("ショートカットを設定...")
                            .foregroundColor(.secondary)
                    } else {
                        Text(shortcut.displayString)
                            .fontWeight(.medium)
                    }
                }
                .frame(minWidth: 120)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .overlay(
                KeyEventCapturingView(
                    isRecording: $isRecording,
                    onKeyPress: { event in
                        handleKeyPress(event)
                    }
                )
                .opacity(0)
            )

            if !shortcut.isDisabled {
                Button(action: {
                    shortcut = .disabled
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleKeyPress(_ event: NSEvent) {
        // 修飾キーのみの入力は無視
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let keyCode = event.keyCode
        let key = characters.uppercased()

        // 少なくとも1つの修飾キーが必要
        guard !modifiers.isEmpty else { return }

        var shortcutModifiers: KeyboardShortcut.Modifiers = []
        if modifiers.contains(.command) { shortcutModifiers.insert(.command) }
        if modifiers.contains(.shift) { shortcutModifiers.insert(.shift) }
        if modifiers.contains(.option) { shortcutModifiers.insert(.option) }
        if modifiers.contains(.control) { shortcutModifiers.insert(.control) }

        shortcut = KeyboardShortcut(
            modifiers: shortcutModifiers,
            keyCode: keyCode,
            key: key
        )

        isRecording = false
    }
}

// MARK: - Key Event Capturing View

/// NSViewを使ってキーイベントをキャプチャする
private struct KeyEventCapturingView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onKeyPress: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyCaptureView {
            if isRecording {
                view.window?.makeFirstResponder(view)
            }
        }
    }

    class KeyCaptureView: NSView {
        var onKeyPress: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            onKeyPress?(event)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        KeyRecorderView(shortcut: .constant(.openHistory))
        KeyRecorderView(shortcut: .constant(.focusSearch))
        KeyRecorderView(shortcut: .constant(.disabled))
    }
    .padding()
    .frame(width: 300)
}
