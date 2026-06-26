import SwiftUI
import UIKit

// A text field that *prefers* a given keyboard language. iOS won't let an app force the
// system keyboard, but a field can pick a preferred input mode from the user's INSTALLED
// keyboards. So a "ja" field auto-switches to the Japanese keyboard if it's installed —
// giving the "type word → enter → translation in the other language" flow.
final class PreferredLanguageTextField: UITextField {
    var preferredLanguage: String?
    override var textInputMode: UITextInputMode? {
        if let lang = preferredLanguage?.lowercased(),
           let mode = UITextInputMode.activeInputModes.first(where: {
               ($0.primaryLanguage ?? "").lowercased().hasPrefix(lang)
           }) {
            return mode
        }
        return super.textInputMode
    }
}

struct LanguageTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var language: String?
    var isFocused: Bool = false
    var returnKey: UIReturnKeyType = .next
    var fontSize: CGFloat = 16
    var onReturn: () -> Void = {}
    var onFocus: () -> Void = {}

    func makeUIView(context: Context) -> PreferredLanguageTextField {
        let tf = PreferredLanguageTextField()
        tf.delegate = context.coordinator
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.smartQuotesType = .no
        tf.clearButtonMode = .whileEditing
        tf.font = .systemFont(ofSize: fontSize)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ tf: PreferredLanguageTextField, context: Context) {
        context.coordinator.parent = self
        if tf.text != text { tf.text = text }
        tf.placeholder = placeholder
        tf.preferredLanguage = language
        tf.returnKeyType = returnKey
        DispatchQueue.main.async {
            if isFocused, !tf.isFirstResponder { tf.becomeFirstResponder() }
            else if !isFocused, tf.isFirstResponder { tf.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LanguageTextField
        init(_ parent: LanguageTextField) { self.parent = parent }

        @objc func editingChanged(_ tf: UITextField) { parent.text = tf.text ?? "" }

        func textFieldDidBeginEditing(_ tf: UITextField) { parent.onFocus() }

        func textFieldShouldReturn(_ tf: UITextField) -> Bool {
            parent.onReturn()
            return false
        }
    }
}
