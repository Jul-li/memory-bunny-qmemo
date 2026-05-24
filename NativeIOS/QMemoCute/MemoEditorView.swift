import SwiftUI
import UIKit

enum MemoEditorNavigationChrome {
    case native
    case cardExpanded
}

struct MemoEditorView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let category: MemoCategory
    let memo: Memo?
    let navigationChrome: MemoEditorNavigationChrome

    @State private var title: String
    @State private var content: String
    @State private var isPinned: Bool
    @State private var isCustomNavigationVisible = false
    private let editorLineSpacing: CGFloat = 32
    private var editorTopPadding: CGFloat {
        navigationChrome == .cardExpanded ? 76 : 18
    }
    private var lineFirstY: CGFloat {
        editorTopPadding + 52
    }

    init(
        category: MemoCategory,
        memo: Memo?,
        navigationChrome: MemoEditorNavigationChrome = .native
    ) {
        self.category = category
        self.memo = memo
        self.navigationChrome = navigationChrome
        _title = State(initialValue: memo?.title ?? "")
        _content = State(initialValue: memo?.content ?? "")
        _isPinned = State(initialValue: memo?.isPinned ?? false)
    }

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()
            MemoEditorLinePattern(spacing: editorLineSpacing, firstY: lineFirstY)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    TextField("给这条便签起个名字", text: $title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .textInputAutocapitalization(.never)
                        .frame(height: editorLineSpacing)
                        .padding(.top, 0)

                    LinedMemoTextView(
                        text: $content,
                        font: .systemFont(ofSize: 17, weight: .semibold),
                        textColor: UIColor(Theme.Colors.text),
                        lineHeight: editorLineSpacing
                    )
                        .padding(.top, 22)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                functionPanel
                    .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.top, editorTopPadding)
            .padding(.bottom, 28)

            if navigationChrome == .cardExpanded {
                customNavigationBar
            }
        }
        .navigationTitle(memo == nil ? "新建便签" : "编辑便签")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .toolbar(navigationChrome == .cardExpanded ? .hidden : .visible, for: .navigationBar)
        .onAppear {
            guard navigationChrome == .cardExpanded else { return }

            isCustomNavigationVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) {
                    isCustomNavigationVisible = true
                }
            }
        }
        .onDisappear {
            isCustomNavigationVisible = false
        }
    }

    private var customNavigationBar: some View {
        VStack {
            HStack(spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.92))
                        .clipShape(Circle())
                        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 10, y: 4)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(memo == nil ? "新建便签" : "编辑便签")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                Button {
                    save()
                } label: {
                    Text("保存")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Theme.Colors.muted.opacity(0.42)
                                : Theme.Colors.text
                        )
                        .frame(width: 56, height: 44)
                        .background(.white.opacity(0.92))
                        .clipShape(Capsule())
                        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()
        }
        .opacity(isCustomNavigationVisible ? 1 : 0)
        .offset(y: isCustomNavigationVisible ? 0 : -34)
        .allowsHitTesting(isCustomNavigationVisible)
    }

    private var functionPanel: some View {
        HStack(spacing: 10) {
            Image(category.iconAsset)
                .resizable()
                .frame(width: 30, height: 30)
            Text(category.title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.Colors.text)
            Spacer()
            Text("置顶")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.text)
            Toggle("置顶", isOn: $isPinned)
                .labelsHidden()
        }
        .padding(.horizontal, 18)
        .frame(height: 64)
        .background(.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let memo {
            store.update(memo, title: cleanTitle, content: cleanContent, isPinned: isPinned)
        } else {
            store.create(title: cleanTitle, content: cleanContent, category: category, isPinned: isPinned)
        }

        dismiss()
    }
}

struct MemoEditorLinePattern: View {
    let spacing: CGFloat
    let firstY: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                var y = firstY
                while y < proxy.size.height + spacing {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct LinedMemoTextView: UIViewRepresentable {
    @Binding var text: String

    let font: UIFont
    let textColor: UIColor
    let lineHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.font = font
        textView.textColor = textColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
        textView.alwaysBounceVertical = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.typingAttributes = textAttributes
        textView.attributedText = attributedString(for: text)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.font = font
        textView.textColor = textColor
        textView.typingAttributes = textAttributes

        guard textView.text != text else { return }

        let selectedRange = textView.selectedRange
        textView.attributedText = attributedString(for: text)
        textView.selectedRange = clampedRange(selectedRange, in: text)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.lineBreakMode = .byWordWrapping

        return [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func attributedString(for text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: textAttributes)
    }

    private func clampedRange(_ range: NSRange, in text: String) -> NSRange {
        let count = (text as NSString).length
        let location = min(range.location, count)
        let length = min(range.length, count - location)
        return NSRange(location: location, length: length)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}
