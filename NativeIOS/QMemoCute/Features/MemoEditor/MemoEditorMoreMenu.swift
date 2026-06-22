import SwiftUI
import UIKit

struct EditorMoreMenuButton: UIViewRepresentable {
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(configuration: buttonConfiguration())
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.accessibilityLabel = "更多"
        context.coordinator.configure(button)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.parent = self
        button.configuration = buttonConfiguration()
        context.coordinator.configure(button)
    }

    private func buttonConfiguration() -> UIButton.Configuration {
        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) {
            configuration = .glass()
        } else {
            configuration = .bordered()
        }

        configuration.image = UIImage(systemName: "ellipsis")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 21, weight: .bold)
        configuration.baseForegroundColor = UIColor(red: 0x49 / 255, green: 0x39 / 255, blue: 0x2F / 255, alpha: 1)
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        if #available(iOS 16.0, *) {
            configuration.indicator = .none
        }
        return configuration
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator {
        var parent: EditorMoreMenuButton

        init(parent: EditorMoreMenuButton) {
            self.parent = parent
        }

        func configure(_ button: UIButton) {
            let isPinned = parent.isPinned
            let pinAction = UIAction(title: isPinned ? "取消置顶" : "置顶", image: UIImage(named: isPinned ? "ActionUnpin" : "ActionPin")) { [weak self] _ in
                self?.parent.onTogglePin()
            }
            let deleteAction = UIAction(title: "删除", image: UIImage(named: "ActionDelete"), attributes: .destructive) { [weak self] _ in
                self?.parent.onDelete()
            }
            button.menu = UIMenu(children: [pinAction, deleteAction])
        }
    }
}
