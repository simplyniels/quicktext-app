import UIKit

final class KeyboardViewController: UIInputViewController {
  private let statusLabel = UILabel()
  private let accent = UIColor(red: 210 / 255, green: 120 / 255, blue: 73 / 255, alpha: 1)

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInterface()
  }

  private func buildInterface() {
    let dark = traitCollection.userInterfaceStyle == .dark
    let foreground = dark
      ? UIColor(red: 246 / 255, green: 239 / 255, blue: 227 / 255, alpha: 1)
      : UIColor(red: 35 / 255, green: 32 / 255, blue: 27 / 255, alpha: 1)
    let secondary = dark
      ? UIColor(red: 168 / 255, green: 158 / 255, blue: 139 / 255, alpha: 1)
      : UIColor(red: 107 / 255, green: 101 / 255, blue: 91 / 255, alpha: 1)
    let surface = dark
      ? UIColor(red: 26 / 255, green: 22 / 255, blue: 18 / 255, alpha: 1)
      : UIColor(red: 255 / 255, green: 252 / 255, blue: 247 / 255, alpha: 1)
    view.backgroundColor = dark
      ? UIColor(red: 15 / 255, green: 13 / 255, blue: 10 / 255, alpha: 1)
      : UIColor(red: 251 / 255, green: 246 / 255, blue: 238 / 255, alpha: 1)

    let handle = UIView()
    handle.backgroundColor = foreground.withAlphaComponent(0.18)
    handle.layer.cornerRadius = 2.5

    let logo = UIView()
    logo.backgroundColor = accent
    logo.layer.cornerRadius = 13
    let logoIcon = UIImageView(image: UIImage(systemName: "waveform"))
    logoIcon.tintColor = .white
    logoIcon.contentMode = .scaleAspectFit
    logoIcon.translatesAutoresizingMaskIntoConstraints = false
    logo.addSubview(logoIcon)

    let title = UILabel()
    title.text = "Quick Text"
    title.font = UIFont(name: "Georgia-Bold", size: 23) ?? .systemFont(ofSize: 23, weight: .semibold)
    title.textColor = foreground

    let subtitle = UILabel()
    subtitle.text = "Systemdiktat nutzen oder Ergebnis einfügen."
    subtitle.font = .systemFont(ofSize: 14)
    subtitle.textColor = secondary
    subtitle.adjustsFontSizeToFitWidth = true
    subtitle.minimumScaleFactor = 0.82

    let titleStack = UIStackView(arrangedSubviews: [title, subtitle])
    titleStack.axis = .vertical
    titleStack.spacing = 4

    let header = UIStackView(arrangedSubviews: [logo, titleStack])
    header.axis = .horizontal
    header.alignment = .center
    header.spacing = 12

    let recordButton = UIButton(type: .system)
    recordButton.setTitle("  Tippe das Mikrofon unten rechts", for: .normal)
    recordButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
    recordButton.tintColor = .white
    recordButton.setTitleColor(.white, for: .normal)
    recordButton.titleLabel?.font = .systemFont(ofSize: 16.5, weight: .semibold)
    recordButton.backgroundColor = accent
    recordButton.layer.cornerRadius = 16
    recordButton.heightAnchor.constraint(equalToConstant: 58).isActive = true
    recordButton.addTarget(self, action: #selector(showMicrophoneHint), for: .touchUpInside)

    let pasteButton = UIButton(type: .system)
    pasteButton.setTitle("  Letztes Diktat einfügen", for: .normal)
    pasteButton.setImage(UIImage(systemName: "doc.on.clipboard"), for: .normal)
    pasteButton.tintColor = accent
    pasteButton.setTitleColor(accent, for: .normal)
    pasteButton.titleLabel?.font = .systemFont(ofSize: 16.5, weight: .semibold)
    pasteButton.backgroundColor = surface
    pasteButton.layer.cornerRadius = 16
    pasteButton.layer.borderWidth = 1
    pasteButton.layer.borderColor = foreground.withAlphaComponent(0.08).cgColor
    pasteButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
    pasteButton.addTarget(self, action: #selector(pasteLatest), for: .touchUpInside)

    let actions = UIStackView(arrangedSubviews: [recordButton, pasteButton])
    actions.axis = .vertical
    actions.alignment = .fill
    actions.distribution = .fill
    actions.spacing = 12

    statusLabel.text = hasFullAccess ? "●  Vollzugriff aktiv" : "Vollzugriff zum Einfügen aktivieren"
    statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
    statusLabel.textColor = hasFullAccess ? UIColor.systemGreen : secondary
    statusLabel.textAlignment = .center

    let nextKeyboard = UIButton(type: .system)
    nextKeyboard.setImage(UIImage(systemName: "globe"), for: .normal)
    nextKeyboard.tintColor = secondary
    nextKeyboard.accessibilityLabel = "Tastatur wechseln"
    nextKeyboard.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

    let microphone = UIButton(type: .system)
    microphone.setImage(UIImage(systemName: "mic"), for: .normal)
    microphone.tintColor = accent
    microphone.backgroundColor = accent.withAlphaComponent(0.18)
    microphone.layer.cornerRadius = 23
    microphone.accessibilityLabel = "iOS-Mikrofon"
    microphone.addTarget(self, action: #selector(showMicrophoneHint), for: .touchUpInside)

    let toolbarSpacer = UIView()
    let toolbar = UIStackView(arrangedSubviews: [nextKeyboard, toolbarSpacer, microphone])
    toolbar.axis = .horizontal
    toolbar.alignment = .center
    toolbar.backgroundColor = dark
      ? UIColor(red: 15 / 255, green: 12 / 255, blue: 9 / 255, alpha: 1)
      : UIColor(red: 239 / 255, green: 231 / 255, blue: 215 / 255, alpha: 1)
    toolbar.isLayoutMarginsRelativeArrangement = true
    toolbar.layoutMargins = UIEdgeInsets(top: 12, left: 26, bottom: 12, right: 26)

    let stack = UIStackView(arrangedSubviews: [handle, header, actions, statusLabel, toolbar])
    stack.axis = .vertical
    stack.alignment = .center
    stack.setCustomSpacing(20, after: handle)
    stack.setCustomSpacing(22, after: header)
    stack.setCustomSpacing(18, after: actions)
    stack.setCustomSpacing(18, after: statusLabel)
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)

    NSLayoutConstraint.activate([
      handle.widthAnchor.constraint(equalToConstant: 40),
      handle.heightAnchor.constraint(equalToConstant: 5),
      handle.centerXAnchor.constraint(equalTo: stack.centerXAnchor),
      logo.widthAnchor.constraint(equalToConstant: 42),
      logo.heightAnchor.constraint(equalToConstant: 42),
      logoIcon.centerXAnchor.constraint(equalTo: logo.centerXAnchor),
      logoIcon.centerYAnchor.constraint(equalTo: logo.centerYAnchor),
      logoIcon.widthAnchor.constraint(equalToConstant: 22),
      logoIcon.heightAnchor.constraint(equalToConstant: 22),
      microphone.widthAnchor.constraint(equalToConstant: 46),
      microphone.heightAnchor.constraint(equalToConstant: 46),
      header.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
      actions.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
      statusLabel.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
      stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      view.heightAnchor.constraint(equalToConstant: 356),
    ])
  }

  @objc private func showMicrophoneHint() {
    statusLabel.text = "Tippe jetzt unten rechts auf das iOS-Mikrofon  ↘︎"
    statusLabel.textColor = accent
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
