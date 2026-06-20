import UIKit

final class KeyboardViewController: UIInputViewController {
  private let statusLabel = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInterface()
  }

  private func buildInterface() {
    view.backgroundColor = UIColor(red: 0.965, green: 0.957, blue: 0.984, alpha: 1)
    let title = UILabel()
    title.text = "Quick Text"
    title.font = .systemFont(ofSize: 17, weight: .bold)
    title.textColor = UIColor(red: 0.16, green: 0.14, blue: 0.20, alpha: 1)

    let subtitle = UILabel()
    subtitle.text = "iOS erlaubt Sprachaufnahme nur über die Apple-Tastatur oder in Quick Text."
    subtitle.font = .systemFont(ofSize: 12)
    subtitle.textColor = .secondaryLabel
    subtitle.numberOfLines = 2

    let recordHint = UILabel()
    recordHint.text = "🎙  Zum Sprechen: Mikrofon unten rechts tippen  ↘︎"
    recordHint.textAlignment = .center
    recordHint.textColor = .white
    recordHint.font = .systemFont(ofSize: 16, weight: .semibold)
    recordHint.backgroundColor = UIColor(red: 0.40, green: 0.34, blue: 0.96, alpha: 1)
    recordHint.layer.cornerRadius = 18
    recordHint.layer.masksToBounds = true
    recordHint.adjustsFontSizeToFitWidth = true
    recordHint.minimumScaleFactor = 0.75
    recordHint.heightAnchor.constraint(equalToConstant: 56).isActive = true

    let pasteButton = UIButton(type: .system)
    pasteButton.setTitle("  Letztes Diktat einfügen", for: .normal)
    pasteButton.setImage(UIImage(systemName: "doc.on.clipboard"), for: .normal)
    pasteButton.tintColor = UIColor(red: 0.40, green: 0.34, blue: 0.96, alpha: 1)
    pasteButton.setTitleColor(UIColor(red: 0.40, green: 0.34, blue: 0.96, alpha: 1), for: .normal)
    pasteButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
    pasteButton.backgroundColor = UIColor(red: 0.92, green: 0.90, blue: 1.0, alpha: 1)
    pasteButton.layer.cornerRadius = 14
    pasteButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    pasteButton.addTarget(self, action: #selector(pasteLatest), for: .touchUpInside)

    let nextKeyboard = UIButton(type: .system)
    nextKeyboard.setImage(UIImage(systemName: "globe"), for: .normal)
    nextKeyboard.setTitle("  Tastatur wechseln", for: .normal)
    nextKeyboard.tintColor = .secondaryLabel
    nextKeyboard.setTitleColor(.secondaryLabel, for: .normal)
    nextKeyboard.contentHorizontalAlignment = .leading
    nextKeyboard.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

    statusLabel.text = hasFullAccess
      ? "Vollzugriff aktiv · Aufnahme erfolgt ausschließlich in Quick Text."
      : "Bitte „Vollen Zugriff erlauben“ aktivieren."
    statusLabel.font = .systemFont(ofSize: 11)
    statusLabel.textColor = .secondaryLabel
    statusLabel.numberOfLines = 2
    statusLabel.textAlignment = .center

    let header = UIStackView(arrangedSubviews: [title, subtitle])
    header.axis = .vertical
    header.spacing = 3
    let stack = UIStackView(arrangedSubviews: [header, recordHint, pasteButton, nextKeyboard, statusLabel])
    stack.axis = .vertical
    stack.spacing = 9
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
      view.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
    ])
  }

  @objc private func pasteLatest() {
    guard hasFullAccess else {
      statusLabel.text = "Voller Zugriff ist für die Zwischenablage erforderlich."
      return
    }
    guard let text = UIPasteboard.general.string, !text.isEmpty else {
      statusLabel.text = "Noch kein Text in der Zwischenablage."
      return
    }
    textDocumentProxy.insertText(text)
    statusLabel.text = "Text eingefügt"
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }
}
