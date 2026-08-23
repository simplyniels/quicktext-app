import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_strings.dart';

void main() => runApp(const QuickTextApp());

final quickTextThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

abstract final class QuickTextColors {
  static const accent = Color(0xFFD27849);
  static const accentLight = Color(0xFFE68B5A);
  static const accentDark = Color(0xFFE0844F);
  static const lightBackground = Color(0xFFFBF6EE);
  static const lightSurface = Color(0xFFFFFCF7);
  static const lightInput = Color(0xFFF4ECDC);
  static const lightText = Color(0xFF23201B);
  static const lightSecondary = Color(0xFF6B655B);
  static const darkBackground = Color(0xFF0F0D0A);
  static const darkSurface = Color(0xFF1A1612);
  static const darkInput = Color(0xFF221D17);
  static const darkText = Color(0xFFF6EFE3);
  static const darkSecondary = Color(0xFFA89E8B);
}

class AuroraMicrophoneIcon extends StatelessWidget {
  const AuroraMicrophoneIcon({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _AuroraMicrophonePainter()),
  );
}

class _AuroraMicrophonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      colors: [Color(0xFFF0A078), Color(0xFFD27849)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Offset.zero & size);
    final fill = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.095
      ..strokeCap = StrokeCap.round;

    final capsule = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * 0.34,
        size.height * 0.12,
        size.width * 0.66,
        size.height * 0.60,
      ),
      Radius.circular(size.width * 0.17),
    );
    canvas.drawRRect(capsule, fill);

    final cradle = Path()
      ..moveTo(size.width * 0.22, size.height * 0.45)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.72,
        size.width * 0.78,
        size.height * 0.72,
        size.width * 0.78,
        size.height * 0.45,
      );
    canvas.drawPath(cradle, stroke);
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.71),
      Offset(size.width * 0.50, size.height * 0.86),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.36, size.height * 0.87),
      Offset(size.width * 0.64, size.height * 0.87),
      stroke,
    );

    final sparkle = Path()
      ..moveTo(size.width * 0.82, size.height * 0.05)
      ..lineTo(size.width * 0.86, size.height * 0.15)
      ..lineTo(size.width * 0.96, size.height * 0.19)
      ..lineTo(size.width * 0.86, size.height * 0.23)
      ..lineTo(size.width * 0.82, size.height * 0.33)
      ..lineTo(size.width * 0.78, size.height * 0.23)
      ..lineTo(size.width * 0.68, size.height * 0.19)
      ..lineTo(size.width * 0.78, size.height * 0.15)
      ..close();
    canvas.drawPath(sparkle, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

ThemeMode themeModeFromSetting(String value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

ThemeData quickTextTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark
      ? QuickTextColors.darkBackground
      : QuickTextColors.lightBackground;
  final surface = dark
      ? QuickTextColors.darkSurface
      : QuickTextColors.lightSurface;
  final foreground = dark
      ? QuickTextColors.darkText
      : QuickTextColors.lightText;
  final secondary = dark
      ? QuickTextColors.darkSecondary
      : QuickTextColors.lightSecondary;
  final accent = dark ? QuickTextColors.accentDark : QuickTextColors.accent;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        surface: surface,
      ).copyWith(
        primary: accent,
        onPrimary: Colors.white,
        onSurface: foreground,
        surfaceContainerHighest: dark
            ? QuickTextColors.darkInput
            : QuickTextColors.lightInput,
        outline: accent.withValues(alpha: 0.26),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['SF Pro Text', 'Roboto', 'sans-serif'],
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['SF Pro Text', 'Roboto', 'sans-serif'],
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: accent.withValues(alpha: dark ? 0.18 : 0.14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? QuickTextColors.darkInput : QuickTextColors.lightInput,
      hintStyle: TextStyle(color: secondary.withValues(alpha: 0.78)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: accent.withValues(alpha: 0.16)),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accent.withValues(alpha: 0.16)),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accent, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : foreground,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : Colors.transparent,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: accent.withValues(alpha: 0.28)),
        ),
      ),
    ),
  );
}

class QuickTextApp extends StatelessWidget {
  const QuickTextApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: quickTextThemeMode,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Quick Text',
        theme: quickTextTheme(Brightness.light),
        darkTheme: quickTextTheme(Brightness.dark),
        themeMode: mode,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        localeResolutionCallback: (locale, supportedLocales) =>
            locale?.languageCode == 'de'
            ? const Locale('de')
            : const Locale('en'),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('de.quicktext.mobile/system');
  final _keyController = TextEditingController();
  final _termsController = TextEditingController();
  bool _microphone = false;
  bool _accessibility = false;
  bool _apiKey = false;
  bool _busy = true;
  bool _showKey = false;
  bool _recording = false;
  bool _processing = false;
  bool _setupExpanded = false;
  int _recordingSeconds = 0;
  String? _lastResult;
  Timer? _recordingTimer;
  String _language = 'de';
  String _workflow = 'transcription';
  String _themeMode = 'system';
  List<String> _dictionary = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyController.dispose();
    _termsController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = Map<String, dynamic>.from(
        await _channel.invokeMethod('getStatus'),
      );
      if (!mounted) return;
      setState(() {
        _microphone = status['microphone'] == true;
        _accessibility = status['accessibility'] == true;
        _apiKey = status['apiKey'] == true;
        _language = status['language'] as String? ?? 'de';
        _workflow = status['workflow'] as String? ?? 'transcription';
        _themeMode = status['themeMode'] as String? ?? 'system';
        _dictionary = _parseTerms(status['customTerms'] as String? ?? '');
        _busy = false;
      });
      quickTextThemeMode.value = themeModeFromSetting(_themeMode);
    } on PlatformException {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> _parseTerms(String raw) => raw
      .split(RegExp(r'[,;\n]'))
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toList();

  void _addTerms(String input) {
    final added = _parseTerms(input)
        .where(
          (term) => !_dictionary.any(
            (existing) => existing.toLowerCase() == term.toLowerCase(),
          ),
        )
        .toList();
    _termsController.clear();
    if (added.isEmpty) return;
    setState(() => _dictionary = [..._dictionary, ...added]);
    unawaited(_saveDictionary());
  }

  void _removeTerm(String term) {
    setState(() => _dictionary = _dictionary.where((t) => t != term).toList());
    unawaited(_saveDictionary());
  }

  Future<void> _saveDictionary() => _channel.invokeMethod('saveSettings', {
    'customTerms': _dictionary.join(', '),
  });

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    await _channel.invokeMethod('saveSettings', {
      'apiKey': _keyController.text,
      'language': _language,
      'workflow': _workflow,
      'customTerms': _dictionary.join(', '),
      'themeMode': _themeMode,
    });
    _keyController.clear();
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).text(
              'Einstellungen sicher gespeichert',
              'Settings saved securely',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_processing) return;
    try {
      if (!_recording) {
        await _channel.invokeMethod('startRecording');
        _recordingTimer?.cancel();
        setState(() {
          _recording = true;
          _recordingSeconds = 0;
          _lastResult = null;
        });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _recordingSeconds++);
          if (_recordingSeconds >= 60 && _recording) _toggleRecording();
        });
      } else {
        _recordingTimer?.cancel();
        setState(() {
          _recording = false;
          _processing = true;
        });
        final text = await _channel.invokeMethod<String>('stopRecording');
        if (!mounted) return;
        setState(() {
          _processing = false;
          _lastResult = text;
        });
      }
    } on PlatformException catch (error) {
      _recordingTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                AppStrings.of(
                  context,
                ).text('Aufnahme fehlgeschlagen', 'Recording failed'),
          ),
        ),
      );
    }
  }

  Future<void> _openKeyboardSetup() async {
    final strings = AppStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.text(
            'Quick-Text-Tastatur aktivieren',
            'Enable the Quick Text keyboard',
          ),
        ),
        content: Text(
          strings.text(
            'Öffne Einstellungen → Allgemein → Tastatur → Tastaturen → Neue Tastatur hinzufügen. Wähle Quick Text und aktiviere anschließend „Vollen Zugriff erlauben“, damit die Tastatur den von Quick Text kopierten Text einfügen kann.',
            'Open Settings → General → Keyboard → Keyboards → Add New Keyboard. Select Quick Text, then enable “Allow Full Access” so the keyboard can insert text copied by Quick Text.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.text('Später', 'Later')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _channel.invokeMethod('openKeyboardSettings');
            },
            child: Text(strings.text('Einstellungen öffnen', 'Open Settings')),
          ),
        ],
      ),
    );
  }

  Widget _dictionaryCard(AppStrings strings) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? QuickTextColors.darkSecondary
        : QuickTextColors.lightSecondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _termsController,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: _addTerms,
              decoration: InputDecoration(
                hintText: strings.text(
                  'Wort hinzufügen, z. B. „Blackboat“',
                  'Add a word, e.g. “Blackboat”',
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: strings.text('Hinzufügen', 'Add'),
                  onPressed: () => _addTerms(_termsController.text),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_dictionary.isEmpty)
              Text(
                strings.text(
                  'Noch keine Wörter. Ergänze Namen, Marken oder Fachbegriffe, die bisher falsch transkribiert wurden — jedes Wort wird sofort gespeichert.',
                  'No words yet. Add names, brands, or technical terms that were transcribed incorrectly — each word is saved instantly.',
                ),
                style: TextStyle(color: secondary, fontSize: 13, height: 1.4),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final term in _dictionary)
                    InputChip(
                      label: Text(term),
                      onDeleted: () => _removeTerm(term),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _setupSection(AppStrings strings, bool isIOS, bool ready) {
    final title = _SectionTitle(
      strings.text('Einrichtung', 'Setup'),
      ready
          ? strings.text(
              'Abgeschlossen — bei Bedarf hier anpassen.',
              'Complete — adjust here if needed.',
            )
          : strings.text(
              'Einmal erledigen, danach überall diktieren.',
              'Set it up once, then dictate anywhere.',
            ),
    );
    if (ready && !_setupExpanded) {
      return [
        title,
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE7F8EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF197544),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    strings.text('Alles eingerichtet', 'Everything is set up'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _setupExpanded = true),
                  child: Text(strings.text('Anzeigen', 'Show')),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      title,
      const SizedBox(height: 16),
      _SetupStep(
        number: '1',
        title: strings.text('OpenAI verbinden', 'Connect OpenAI'),
        subtitle: _apiKey
            ? strings.text(
                'API-Key sicher im ${isIOS ? 'iOS Keychain' : 'Android Keystore'} gespeichert',
                'API key stored securely in ${isIOS ? 'iOS Keychain' : 'Android Keystore'}',
              )
            : strings.text(
                'Für GPT Transcribe und die Text-Workflows',
                'For GPT Transcribe and text workflows',
              ),
        done: _apiKey,
        child: TextField(
          controller: _keyController,
          obscureText: !_showKey,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
          decoration: InputDecoration(
            hintText: _apiKey
                ? strings.text(
                    'Neuen Key eingeben, um ihn zu ersetzen',
                    'Enter a new key to replace it',
                  )
                : 'sk-…',
            suffixIcon: IconButton(
              icon: Icon(
                _showKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _showKey = !_showKey),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _SetupStep(
        number: '2',
        title: strings.text('Mikrofon erlauben', 'Allow microphone'),
        subtitle: _microphone
            ? strings.text('Zugriff ist aktiv', 'Access is enabled')
            : strings.text(
                'Nur während einer gestarteten Aufnahme',
                'Only while a recording is active',
              ),
        done: _microphone,
        action: _microphone
            ? null
            : () => _channel.invokeMethod('requestPermissions'),
        actionLabel: strings.text('Erlauben', 'Allow'),
      ),
      const SizedBox(height: 12),
      _SetupStep(
        number: '3',
        title: isIOS
            ? strings.text(
                'Quick-Text-Tastatur aktivieren',
                'Enable Quick Text keyboard',
              )
            : strings.text(
                'Floating Bubble aktivieren',
                'Enable floating bubble',
              ),
        subtitle: isIOS
            ? strings.text(
                'Fügt das letzte Diktat am Cursor ein',
                'Inserts the latest dictation at the cursor',
              )
            : _accessibility
            ? strings.text(
                'Quick Text ist als Bedienungshilfe aktiv',
                'Quick Text accessibility is enabled',
              )
            : strings.text(
                'Erkennt Textfelder und fügt nur dein Diktat ein',
                'Detects text fields and inserts only your dictation',
              ),
        done: isIOS ? false : _accessibility,
        action: isIOS
            ? _openKeyboardSetup
            : () => _channel.invokeMethod('openAccessibility'),
        actionLabel: isIOS
            ? strings.text('Anleitung', 'Instructions')
            : _accessibility
            ? strings.text('Öffnen', 'Open')
            : strings.text('Aktivieren', 'Enable'),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _busy ? null : _save,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_rounded),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Text(strings.text('Einstellungen speichern', 'Save settings')),
        ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      if (ready)
        Center(
          child: TextButton(
            onPressed: () => setState(() => _setupExpanded = false),
            child: Text(strings.text('Ausblenden', 'Hide')),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isIOS = Platform.isIOS;
    final ready = _microphone && _apiKey && (isIOS || _accessibility);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        QuickTextColors.accentLight,
                        QuickTextColors.accent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Text',
                        style: TextStyle(
                          fontFamily: 'Source Serif 4',
                          fontFamilyFallback: ['Georgia', 'serif'],
                          fontSize: 27,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        strings.text(
                          'Sprich. Sende. Fertig.',
                          'Speak. Send. Done.',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? QuickTextColors.darkSecondary
                              : QuickTextColors.lightSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(ready: ready),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE89163),
                    QuickTextColors.accent,
                    Color(0xFFC26B3F),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33D27849),
                    blurRadius: 44,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: isIOS
                        ? const Icon(
                            Icons.mic_rounded,
                            color: QuickTextColors.accent,
                            size: 34,
                          )
                        : const Center(child: AuroraMicrophoneIcon()),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    isIOS
                        ? strings.text(
                            'Sprich in Quick Text.\nFüge es überall ein.',
                            'Speak in Quick Text.\nPaste it anywhere.',
                          )
                        : strings.text(
                            'Deine Stimme, direkt\nim Textfeld.',
                            'Your voice, directly\nin the text field.',
                          ),
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Source Serif 4',
                      fontFamilyFallback: const ['Georgia', 'serif'],
                      fontSize: 34,
                      height: 1.08,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isIOS
                        ? strings.text(
                            'Nimm dein Diktat hier auf. Quick Text transkribiert, verbessert und kopiert es; die Quick-Text-Tastatur setzt es anschließend am Cursor ein.',
                            'Record your dictation here. Quick Text transcribes, improves, and copies it; the Quick Text keyboard then inserts it at the cursor.',
                          )
                        : ready
                        ? strings.text(
                            'Tippe in WhatsApp, Mail oder eine andere App. Die Quick-Text-Bubble erscheint automatisch über deiner Tastatur.',
                            'Type in WhatsApp, Mail, or another app. The Quick Text bubble appears automatically above your keyboard.',
                          )
                        : strings.text(
                            'Drei kurze Schritte aktivieren die schwebende Spracheingabe in deinen Apps.',
                            'Three quick steps enable floating voice input in your apps.',
                          ),
                    style: const TextStyle(
                      color: Color(0xFFFFF5EB),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isIOS) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: _recording ? 88 : 76,
                        height: _recording ? 88 : 76,
                        decoration: BoxDecoration(
                          color: _recording
                              ? const Color(0xFFFF4F67)
                              : QuickTextColors.accent,
                          shape: BoxShape.circle,
                          boxShadow: _recording
                              ? const [
                                  BoxShadow(
                                    color: Color(0x55FF4F67),
                                    blurRadius: 28,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : null,
                        ),
                        child: IconButton(
                          onPressed: ready ? _toggleRecording : null,
                          icon: Icon(
                            _recording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _processing
                            ? strings.text('Transkribiere …', 'Transcribing …')
                            : _recording
                            ? '${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')} · ${strings.text('Zum Beenden tippen', 'Tap to stop')}'
                            : ready
                            ? strings.text(
                                'Tippen und sprechen',
                                'Tap and speak',
                              )
                            : strings.text(
                                'Bitte zuerst Setup abschließen',
                                'Please complete setup first',
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_processing) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (_lastResult != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.text(
                                  'In Zwischenablage kopiert',
                                  'Copied to clipboard',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF197544),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _lastResult!,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            if (!ready) ...[
              ..._setupSection(strings, isIOS, ready),
              const SizedBox(height: 28),
            ],
            _SectionTitle(
              strings.text('Wörterbuch', 'Dictionary'),
              strings.text(
                'Eigennamen & Fachbegriffe, die die KI erkennen soll.',
                'Names & terms the AI should recognize.',
              ),
            ),
            const SizedBox(height: 12),
            _dictionaryCard(strings),
            const SizedBox(height: 28),
            _SectionTitle(
              strings.text('Diktat', 'Dictation'),
              strings.text(
                'So soll Quick Text deinen Text ausgeben.',
                'Choose how Quick Text should output your text.',
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.text('Workflow', 'Workflow'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _workflow,
                      items: [
                        DropdownMenuItem(
                          value: 'transcription',
                          child: Text(
                            strings.text(
                              'Quick Text · Originalgetreu',
                              'Quick Text · Faithful',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'improve',
                          child: Text(
                            strings.text(
                              'Quick Text+ · Verbessern',
                              'Quick Text+ · Improve',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'calm',
                          child: Text(
                            strings.text(
                              r'Quick Text $%&! · Ruhiger',
                              r'Quick Text $%&! · Calmer',
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'emoji',
                          child: Text('Quick Text :) · Emojis'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _workflow = value);
                        unawaited(
                          _channel.invokeMethod('saveSettings', {
                            'workflow': value,
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.text('Sprache', 'Dictation language'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'de',
                          label: Text(strings.text('Deutsch', 'German')),
                        ),
                        const ButtonSegment(
                          value: 'en',
                          label: Text('English'),
                        ),
                        ButtonSegment(
                          value: 'fr',
                          label: Text(strings.text('Französisch', 'French')),
                        ),
                        ButtonSegment(
                          value: 'auto',
                          label: Text(strings.text('Auto', 'Auto')),
                        ),
                      ],
                      selected: {_language},
                      onSelectionChanged: (value) {
                        final selection = value.first;
                        setState(() => _language = selection);
                        unawaited(
                          _channel.invokeMethod('saveSettings', {
                            'language': selection,
                          }),
                        );
                      },
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.text('Darstellung', 'Appearance'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'system',
                          icon: const Icon(Icons.brightness_auto_outlined),
                          label: Text(strings.text('Auto', 'Auto')),
                        ),
                        ButtonSegment(
                          value: 'light',
                          icon: const Icon(Icons.light_mode_outlined),
                          label: Text(strings.text('Hell', 'Light')),
                        ),
                        ButtonSegment(
                          value: 'dark',
                          icon: const Icon(Icons.dark_mode_outlined),
                          label: Text(strings.text('Dunkel', 'Dark')),
                        ),
                      ],
                      selected: {_themeMode},
                      onSelectionChanged: (value) {
                        final selection = value.first;
                        setState(() => _themeMode = selection);
                        quickTextThemeMode.value = themeModeFromSetting(
                          selection,
                        );
                        unawaited(
                          _channel.invokeMethod('saveSettings', {
                            'themeMode': selection,
                          }),
                        );
                      },
                      showSelectedIcon: false,
                    ),
                  ],
                ),
              ),
            ),
            if (ready) ...[
              const SizedBox(height: 28),
              ..._setupSection(strings, isIOS, ready),
            ],
            const SizedBox(height: 16),
            Text(
              isIOS
                  ? strings.text(
                      'Quick Text nimmt Audio nur nach Tippen auf die Mikrofontaste auf und sendet es direkt an OpenAI. Die Tastatur liest die Zwischenablage ausschließlich nach deinem Tap auf „Einfügen“.',
                      'Quick Text records audio only after you tap the microphone button and sends it directly to OpenAI. The keyboard reads the clipboard only after you tap “Paste”.',
                    )
                  : strings.text(
                      'Quick Text liest keine Nachrichten aus anderen Apps. Der Accessibility-Service reagiert ausschließlich auf fokussierte, nicht-sensible Textfelder. Audio wird nur nach Tippen auf die Bubble aufgenommen und direkt an OpenAI gesendet.',
                      'Quick Text does not read messages from other apps. The accessibility service reacts only to focused, non-sensitive text fields. Audio is recorded only after you tap the bubble and is sent directly to OpenAI.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? QuickTextColors.darkSecondary
                    : QuickTextColors.lightSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.ready});
  final bool ready;
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: ready
            ? const Color(0xFFE4F1E7)
            : QuickTextColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        ready ? strings.text('Bereit', 'Ready') : 'Setup',
        style: TextStyle(
          color: ready ? const Color(0xFF3E7652) : QuickTextColors.accent,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontFamily: 'Source Serif 4',
          fontFamilyFallback: ['Georgia', 'serif'],
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? QuickTextColors.darkSecondary
              : QuickTextColors.lightSecondary,
          fontSize: 15,
        ),
      ),
    ],
  );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.done,
    this.child,
    this.action,
    this.actionLabel,
  });
  final String number;
  final String title;
  final String subtitle;
  final bool done;
  final Widget? child;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFFE7F8EE)
                      : QuickTextColors.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF197544),
                          size: 21,
                        )
                      : Text(
                          number,
                          style: const TextStyle(
                            color: QuickTextColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? QuickTextColors.darkSecondary
                            : QuickTextColors.lightSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: action,
                  child: Text(actionLabel ?? 'Öffnen'),
                ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 14), child!],
        ],
      ),
    ),
  );
}
