import UIKit

final class KeyboardViewController: UIInputViewController {
  private let statusLabel = UILabel()
  private let accent = UIColor(red: 210 / 255, green: 120 / 255, blue: 73 / 255, alpha: 1)
  private var isGerman: Bool { Locale.preferredLanguages.first?.lowercased().hasPrefix("de") == true }

  private func localized(_ german: String, _ english: String) -> String {
    isGerman ? german : english
  }

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
    subtitle.text = localized(
      "Systemdiktat nutzen oder Ergebnis einfügen.",
      "Use system dictation or paste your result."
    )
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
    recordButton.setTitle(
      localized("  Tippe das Mikrofon unten rechts", "  Tap the microphone at the bottom right"),
      for: .normal
    )
    recordButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
    recordButton.tintColor = .white
    recordButton.setTitleColor(.white, for: .normal)
    recordButton.titleLabel?.font = .systemFont(ofSize: 16.5, weight: .semibold)
    recordButton.backgroundColor = accent
    recordButton.layer.cornerRadius = 16
    recordButton.heightAnchor.constraint(equalToConstant: 58).isActive = true
    recordButton.addTarget(self, action: #selector(showMicrophoneHint), for: .touchUpInside)

    let pasteButton = UIButton(type: .system)
    pasteButton.setTitle(
      localized("  Letztes Diktat einfügen", "  Paste latest dictation"),
      for: .normal
    )
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

    statusLabel.text = hasFullAccess
      ? localized("●  Vollzugriff aktiv", "●  Full Access enabled")
      : localized("Vollzugriff zum Einfügen aktivieren", "Enable Full Access to paste")
    statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
    statusLabel.textColor = hasFullAccess ? UIColor.systemGreen : secondary
    statusLabel.textAlignment = .center

    let stack = UIStackView(arrangedSubviews: [handle, header, actions, statusLabel])
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
      header.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
      actions.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
      statusLabel.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
      stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
      view.heightAnchor.constraint(equalToConstant: 290),
    ])
  }

  @objc private func showMicrophoneHint() {
    statusLabel.text = localized(
      "Tippe jetzt unten rechts auf das iOS-Mikrofon  ↘︎",
      "Now tap the iOS microphone at the bottom right  ↘︎"
    )
    statusLabel.textColor = accent
    UISelectionFeedbackGenerator().selectionChanged()
  }

  @objc private func pasteLatest() {
    guard hasFullAccess else {
      statusLabel.text = localized(
        "Vollzugriff ist für die Zwischenablage erforderlich",
        "Full Access is required to use the clipboard"
      )
      statusLabel.textColor = .systemOrange
      return
    }
    guard let text = UIPasteboard.general.string, !text.isEmpty else {
      statusLabel.text = localized(
        "Noch kein Diktat in der Zwischenablage",
        "No dictation in the clipboard yet"
      )
      statusLabel.textColor = .systemOrange
      return
    }
    textDocumentProxy.insertText(text)
    statusLabel.text = localized("✓  Text eingefügt", "✓  Text pasted")
    statusLabel.textColor = .systemGreen
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }
}
