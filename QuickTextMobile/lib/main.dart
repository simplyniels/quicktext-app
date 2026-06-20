import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const QuickTextApp());

class QuickTextApp extends StatelessWidget {
  const QuickTextApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6656F5);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quick Text',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7FB),
        fontFamily: 'sans-serif',
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF4F2F8),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const HomePage(),
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
  String _language = 'de';
  String _workflow = 'transcription';

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
        _termsController.text = status['customTerms'] as String? ?? '';
        _busy = false;
      });
    } on PlatformException {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    await _channel.invokeMethod('saveSettings', {
      'apiKey': _keyController.text,
      'language': _language,
      'workflow': _workflow,
      'customTerms': _termsController.text,
    });
    _keyController.clear();
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen sicher gespeichert')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _microphone && _accessibility && _apiKey;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6656F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Text',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Sprich. Sende. Fertig.',
                        style: TextStyle(color: Color(0xFF777280)),
                      ),
                    ],
                  ),
                ),
                _StatusPill(ready: ready),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7667FF), Color(0xFF4F3FD8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x336656F5),
                    blurRadius: 26,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Color(0xFF6656F5),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Deine Stimme, direkt\nim Textfeld.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ready
                        ? 'Tippe in WhatsApp, Mail oder eine andere App. Die Quick-Text-Bubble erscheint automatisch über deiner Tastatur.'
                        : 'Drei kurze Schritte aktivieren die schwebende Spracheingabe in deinen Apps.',
                    style: const TextStyle(
                      color: Color(0xFFE8E4FF),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const _SectionTitle(
              'Einrichtung',
              'Einmal erledigen, danach überall diktieren.',
            ),
            const SizedBox(height: 12),
            _SetupStep(
              number: '1',
              title: 'OpenAI verbinden',
              subtitle: _apiKey
                  ? 'API-Key sicher im Android Keystore gespeichert'
                  : 'Für whisper-1 und die Text-Workflows',
              done: _apiKey,
              child: TextField(
                controller: _keyController,
                obscureText: !_showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: _apiKey
                      ? 'Neuen Key eingeben, um ihn zu ersetzen'
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
            const SizedBox(height: 10),
            _SetupStep(
              number: '2',
              title: 'Mikrofon erlauben',
              subtitle: _microphone
                  ? 'Zugriff ist aktiv'
                  : 'Nur während einer gestarteten Aufnahme',
              done: _microphone,
              action: _microphone
                  ? null
                  : () => _channel.invokeMethod('requestPermissions'),
              actionLabel: 'Erlauben',
            ),
            const SizedBox(height: 10),
            _SetupStep(
              number: '3',
              title: 'Floating Bubble aktivieren',
              subtitle: _accessibility
                  ? 'Quick Text ist als Bedienungshilfe aktiv'
                  : 'Erkennt Textfelder und fügt nur dein Diktat ein',
              done: _accessibility,
              action: () => _channel.invokeMethod('openAccessibility'),
              actionLabel: _accessibility ? 'Öffnen' : 'Aktivieren',
            ),
            const SizedBox(height: 28),
            const _SectionTitle(
              'Diktat',
              'So soll Quick Text deinen Text ausgeben.',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Workflow',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _workflow,
                      items: const [
                        DropdownMenuItem(
                          value: 'transcription',
                          child: Text('Quick Text · Originalgetreu'),
                        ),
                        DropdownMenuItem(
                          value: 'improve',
                          child: Text('Quick Text+ · Verbessern'),
                        ),
                        DropdownMenuItem(
                          value: 'calm',
                          child: Text(r'Quick Text $%&! · Ruhiger'),
                        ),
                        DropdownMenuItem(
                          value: 'emoji',
                          child: Text('Quick Text :) · Emojis'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _workflow = value ?? _workflow),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sprache',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'de', label: Text('Deutsch')),
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'auto', label: Text('Auto')),
                      ],
                      selected: {_language},
                      onSelectionChanged: (value) =>
                          setState(() => _language = value.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _termsController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Eigennamen & Fachbegriffe',
                        hintText: 'Quick Text, Blackboat, …',
                      ),
                    ),
                  ],
                ),
              ),
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
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text('Einstellungen speichern'),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick Text liest keine Nachrichten aus anderen Apps. Der Accessibility-Service reagiert ausschließlich auf fokussierte, nicht-sensible Textfelder. Audio wird nur nach Tippen auf die Bubble aufgenommen und direkt an OpenAI gesendet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF777280),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: ready ? const Color(0xFFE7F8EE) : const Color(0xFFFFF1D8),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      ready ? 'Bereit' : 'Setup',
      style: TextStyle(
        color: ready ? const Color(0xFF197544) : const Color(0xFF946200),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
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
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: Color(0xFF777280))),
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
      padding: const EdgeInsets.all(17),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFFE7F8EE)
                      : const Color(0xFFEEEAFE),
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
                            color: Color(0xFF6656F5),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF777280),
                        fontSize: 13,
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
