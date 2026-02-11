import SwiftUI

/// 検索バー
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "検索..."
    var onSubmit: (() -> Void)?
    var focused: FocusState<Bool>.Binding?

    @FocusState private var internalFocus: Bool

    private var isFocused: Bool {
        get { focused?.wrappedValue ?? internalFocus }
        nonmutating set {
            if let focused = focused {
                focused.wrappedValue = newValue
            } else {
                internalFocus = newValue
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.subheadline)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused(focused ?? $internalFocus)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button(action: clearText) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }

    private func clearText() {
        text = ""
        if let focused = focused {
            focused.wrappedValue = true
        } else {
            internalFocus = true
        }
    }
}

// MARK: - Search Bar Styles

extension SearchBar {
    /// コンパクトスタイル
    func compact() -> some View {
        self
            .frame(height: 28)
    }

    /// ラージスタイル
    func large() -> some View {
        self
            .frame(height: 36)
    }
}

#Preview {
    VStack(spacing: 16) {
        SearchBar(text: .constant(""))
        SearchBar(text: .constant("検索テキスト"))
        SearchBar(text: .constant(""), placeholder: "通知を検索...")
            .compact()
    }
    .padding()
    .frame(width: 300)
}
