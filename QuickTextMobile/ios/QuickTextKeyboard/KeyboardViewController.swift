import UIKit

final class KeyboardViewController: UIInputViewController {
  private let statusLabel = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInterface()
  }

  private func buildInterface() {
    let blue = UIColor.systemBlue
    view.backgroundColor = UIColor.secondarySystemBackground

    let title = UILabel()
    title.text = "Quick Text"
    title.font = .systemFont(ofSize: 18, weight: .bold)
    title.textColor = .label

    let subtitle = UILabel()
    subtitle.text = "Systemdiktat nutzen oder Quick-Text-Ergebnis einfügen."
    subtitle.font = .systemFont(ofSize: 11.5)
    subtitle.textColor = .secondaryLabel
    subtitle.adjustsFontSizeToFitWidth = true
    subtitle.minimumScaleFactor = 0.78

    let titleStack = UIStackView(arrangedSubviews: [title, subtitle])
    titleStack.axis = .vertical
    titleStack.spacing = 2

    let header = UIStackView(arrangedSubviews: [titleStack])
    header.axis = .horizontal
    header.alignment = .center
    if needsInputModeSwitchKey {
      let nextKeyboard = UIButton(type: .system)
      nextKeyboard.setImage(UIImage(systemName: "globe"), for: .normal)
      nextKeyboard.tintColor = .secondaryLabel
      nextKeyboard.backgroundColor = UIColor.secondarySystemFill
      nextKeyboard.layer.cornerRadius = 17
      nextKeyboard.accessibilityLabel = "Tastatur wechseln"
      nextKeyboard.widthAnchor.constraint(equalToConstant: 34).isActive = true
      nextKeyboard.heightAnchor.constraint(equalToConstant: 34).isActive = true
      nextKeyboard.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
      header.addArrangedSubview(nextKeyboard)
    }

    let recordButton = UIButton(type: .system)
    recordButton.setTitle("  Tippe das Mikrofon unten rechts", for: .normal)
    recordButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
    recordButton.tintColor = .white
    recordButton.setTitleColor(.white, for: .normal)
    recordButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
    recordButton.backgroundColor = blue
    recordButton.layer.cornerRadius = 14
    recordButton.widthAnchor.constraint(equalToConstant: 280).isActive = true
    recordButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    recordButton.addTarget(self, action: #selector(showMicrophoneHint), for: .touchUpInside)

    let pasteButton = UIButton(type: .system)
    pasteButton.setTitle("  Letztes Diktat einfügen", for: .normal)
    pasteButton.setImage(UIImage(systemName: "doc.on.clipboard"), for: .normal)
    pasteButton.tintColor = blue
    pasteButton.setTitleColor(blue, for: .normal)
    pasteButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
    pasteButton.backgroundColor = UIColor.tertiarySystemFill
    pasteButton.layer.cornerRadius = 14
    pasteButton.widthAnchor.constraint(equalToConstant: 280).isActive = true
    pasteButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    pasteButton.addTarget(self, action: #selector(pasteLatest), for: .touchUpInside)

    let actions = UIStackView(arrangedSubviews: [recordButton, pasteButton])
    actions.axis = .vertical
    actions.alignment = .center
    actions.distribution = .fill
    actions.spacing = 8

    statusLabel.text = hasFullAccess ? "●  Vollzugriff aktiv" : "Vollzugriff zum Einfügen aktivieren"
    statusLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
    statusLabel.textColor = hasFullAccess ? UIColor.systemGreen : UIColor.secondaryLabel
    statusLabel.textAlignment = .center

    let stack = UIStackView(arrangedSubviews: [header, actions, statusLabel])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 11
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)

    NSLayoutConstraint.activate([
      header.widthAnchor.constraint(equalTo: stack.widthAnchor),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
      view.heightAnchor.constraint(equalToConstant: 196),
    ])
  }

  @objc private func showMicrophoneHint() {
    statusLabel.text = "Tippe jetzt unten rechts auf das iOS-Mikrofon  ↘︎"
    statusLabel.textColor = .systemBlue
    UISelectionFeedbackGenerator().selectionChanged()
  }

  @objc private func pasteLatest() {
    guard hasFullAccess else {
      statusLabel.text = "Vollzugriff ist für die Zwischenablage erforderlich"
      statusLabel.textColor = .systemOrange
      return
    }
    guard let text = UIPasteboard.general.string, !text.isEmpty else {
      statusLabel.text = "Noch kein Diktat in der Zwischenablage"
      statusLabel.textColor = .systemOrange
      return
    }
    textDocumentProxy.insertText(text)
    statusLabel.text = "✓  Text eingefügt"
    statusLabel.textColor = .systemGreen
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }
}
