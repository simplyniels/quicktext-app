import AVFoundation
import Flutter
import Security
import UIKit

private func localized(_ german: String, _ english: String) -> String {
  Locale.preferredLanguages.first?.lowercased().hasPrefix("de") == true ? german : english
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var channel: FlutterMethodChannel?
  private var recorder: AVAudioRecorder?
  private var recordingURL: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QuickTextSystem") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "de.quicktext.mobile/system",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let settings = UserDefaults.standard
    switch call.method {
    case "getStatus":
      result([
        "platform": "ios",
        "microphone": microphoneGranted,
        "accessibility": false,
        "apiKey": KeychainStore.read() != nil,
        "language": settings.string(forKey: "language") ?? "de",
        "workflow": settings.string(forKey: "workflow") ?? "transcription",
        "customTerms": settings.string(forKey: "custom_terms") ?? "",
        "themeMode": settings.string(forKey: "theme_mode") ?? "system",
      ])
    case "saveSettings":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "arguments", message: localized("Einstellungen fehlen", "Settings are missing"), details: nil))
        return
      }
      if let key = arguments["apiKey"] as? String, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        do { try KeychainStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines)) }
        catch { result(FlutterError(code: "keychain", message: localized("API-Key konnte nicht gespeichert werden", "The API key could not be saved"), details: nil)); return }
      }
      if let language = arguments["language"] as? String { settings.set(language, forKey: "language") }
      if let workflow = arguments["workflow"] as? String { settings.set(workflow, forKey: "workflow") }
      if let terms = arguments["customTerms"] as? String { settings.set(terms, forKey: "custom_terms") }
      if let theme = arguments["themeMode"] as? String { settings.set(theme, forKey: "theme_mode") }
      result(true)
    case "requestPermissions":
      if #available(iOS 17.0, *) {
        AVAudioApplication.requestRecordPermission { _ in result(true) }
      } else {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in result(true) }
      }
    case "openAccessibility", "openKeyboardSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else { result(false); return }
      UIApplication.shared.open(url) { result($0) }
    case "startRecording":
      do { try startRecording(); result(true) }
      catch { result(FlutterError(code: "recording", message: error.localizedDescription, details: nil)) }
    case "stopRecording":
      stopAndTranscribe(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startRecording() throws {
    guard microphoneGranted else {
      throw QuickTextError.message(localized("Bitte zuerst Mikrofonzugriff erlauben.", "Please allow microphone access first."))
    }
    guard KeychainStore.read() != nil else {
      throw QuickTextError.message(localized("Bitte zuerst den OpenAI API-Key speichern.", "Please save the OpenAI API key first."))
    }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .default, options: [])
    try session.setPreferredSampleRate(44_100)
    try session.setActive(true)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("quick-text-\(UUID().uuidString).m4a")
    let newRecorder = try AVAudioRecorder(url: url, settings: [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44_100,
      AVNumberOfChannelsKey: 1,
      AVEncoderBitRateKey: 64_000,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ])
    guard newRecorder.prepareToRecord(), newRecorder.record(forDuration: 60) else {
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw QuickTextError.message(localized("Die Audioaufnahme konnte nicht gestartet werden.", "The audio recording could not be started."))
    }
    recorder = newRecorder
    recordingURL = url
  }

  private var microphoneGranted: Bool {
    if #available(iOS 17.0, *) {
      return AVAudioApplication.shared.recordPermission == .granted
    }
    return AVAudioSession.sharedInstance().recordPermission == .granted
  }

  private func stopAndTranscribe(result: @escaping FlutterResult) {
    recorder?.stop()
    recorder = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    guard let url = recordingURL, let key = KeychainStore.read() else {
      result(FlutterError(code: "recording", message: localized("Keine Aufnahme gefunden", "No recording found"), details: nil))
      return
    }
    recordingURL = nil
    let settings = UserDefaults.standard
    Task {
      defer { try? FileManager.default.removeItem(at: url) }
      do {
        let transcript = try await OpenAIClient.transcribe(
          file: url,
          key: key,
          language: settings.string(forKey: "language") ?? "de",
          terms: settings.string(forKey: "custom_terms") ?? ""
        )
        let output = try await OpenAIClient.rewrite(
          text: transcript,
          key: key,
          workflow: settings.string(forKey: "workflow") ?? "transcription"
        )
        await MainActor.run {
          UIPasteboard.general.string = output
          result(output)
        }
      } catch {
        await MainActor.run {
          result(FlutterError(code: "transcription", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}

private enum QuickTextError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    if case .message(let value) = self { return value }
    return localized("Quick Text Fehler", "Quick Text error")
  }
}

private enum KeychainStore {
  private static let service = "de.quicktext.mobile.openai"
  private static let account = "api-key"

  static func save(_ value: String) throws {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    SecItemDelete(query as CFDictionary)
    var item = query
    item[kSecValueData as String] = Data(value.utf8)
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw QuickTextError.message(localized("Keychain-Zugriff fehlgeschlagen", "Keychain access failed")) }
  }

  static func read() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

private enum OpenAIClient {
  static func transcribe(file: URL, key: String, language: String, terms: String) async throws -> String {
    let boundary = "QuickText-\(UUID().uuidString)"
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 90
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    var body = Data()
    func field(_ name: String, _ value: String) {
      body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
    }
    field("model", "whisper-1")
    if language.range(of: "^[a-z]{2}$", options: .regularExpression) != nil { field("language", language) }
    if !terms.isEmpty { field("prompt", "Eigennamen und Begriffe: \(terms)") }
    body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
    body.append(try Data(contentsOf: file))
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    request.httpBody = body
    let json = try await send(request)
    guard let text = json["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw QuickTextError.message("Leere Transkription")
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func rewrite(text: String, key: String, workflow: String) async throws -> String {
    guard workflow != "transcription" else { return text }
    let model: String
    let prompt: String
    switch workflow {
    case "improve":
      model = "gpt-4o-mini"; prompt = "Du bist ein Lektor. Entferne Füllwörter, korrigiere Grammatik und Zeichensetzung und verbessere den Lesefluss, ohne Bedeutung oder Ton zu verändern. Gib nur den fertigen Text zurück."
    case "calm":
      model = "gpt-4o"; prompt = "Formuliere den gesprochenen Text als ruhige, respektvolle und konstruktive Nachricht. Erhalte Anliegen und Fakten, entferne Beleidigungen und Eskalation. Gib nur die fertige Nachricht zurück."
    case "emoji":
      model = "gpt-4o-mini"; prompt = "Gib das Transkript möglichst originalgetreu zurück, korrigiere offensichtliche Fehler und füge etwa alle ein bis zwei Sätze passende Emojis ein. Gib nur den fertigen Text zurück."
    default: return text
    }
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 90
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": model,
      "messages": [["role": "system", "content": prompt], ["role": "user", "content": text]],
    ])
    let json = try await send(request)
    guard let choices = json["choices"] as? [[String: Any]],
          let message = choices.first?["message"] as? [String: Any],
          let output = message["content"] as? String else { throw QuickTextError.message("Leere Textantwort") }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func send(_ request: URLRequest) async throws -> [String: Any] {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw QuickTextError.message("Ungültige Serverantwort") }
    let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    guard (200...299).contains(http.statusCode) else {
      let error = json["error"] as? [String: Any]
      throw QuickTextError.message((error?["message"] as? String) ?? "OpenAI-Anfrage fehlgeschlagen (HTTP \(http.statusCode))")
    }
    return json
  }
}
