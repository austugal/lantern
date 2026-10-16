import 'package:flutter/material.dart';
import 'controller.dart';
import 'services.dart';
import 'offline_guide.dart';

const ink = Color(0xFF182E2B);
const paper = Color(0xFFF6F3EA);
const amber = Color(0xFFE8B959);

class LanternApp extends StatefulWidget {
  const LanternApp({super.key, required this.controller});
  final LanternController controller;
  @override
  State<LanternApp> createState() => _LanternAppState();
}

class _LanternAppState extends State<LanternApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive also occurs during OS permission prompts; only stop on actual
    // background/hide. Native hosts independently stop when backgrounded.
    if (state == AppLifecycleState.resumed) {
      widget.controller.setForeground(true);
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.controller.setForeground(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Lantern',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        secondary: amber,
        surface: paper,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    home: Home(controller: widget.controller),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.controller});
  final LanternController controller;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _name = TextEditingController();
  final _message = TextEditingController();
  int _tab = 0;
  bool _sending = false;
  LanternController get c => widget.controller;
  @override
  void dispose() {
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flare_rounded, size: 30),
            SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'lantern',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontSize: 29,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open offline guide',
            onPressed: () => showOfflineGuide(context),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          _help(
            'Quick start',
            '1. Both people open Lantern on the same type of phone.\n2. Enable Bluetooth and Wi-Fi, then turn on Lantern.\n3. Connect and confirm the invitation in person.\n4. Open Conversation to message. Field tools adds optional location and check-ins.\n\nKeep Lantern open. Backgrounding disconnects and stops sharing. Android and iPhone cannot connect to each other in this build.',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Chip(
              label: Text(
                c.active ? 'VISIBLE' : 'OFF',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              avatar: Icon(
                c.active ? Icons.wifi_tethering : Icons.shield_outlined,
                size: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                if (c.error.isNotEmpty)
                  MaterialBanner(
                    content: Text(c.error),
                    actions: [
                      TextButton(
                        onPressed: c.clearError,
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                if (c.guardianRequested || c.incomingAlert.isNotEmpty)
                  MaterialBanner(
                    leading: const Icon(Icons.notifications_active_outlined),
                    content: Text(
                      c.incomingAlert.isNotEmpty
                          ? c.incomingAlert
                          : 'Your connected peer requests a guardian.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _tab = 2),
                        child: const Text('View field tools'),
                      ),
                    ],
                  ),
                if (c.sharing)
                  Container(
                    width: double.infinity,
                    color: amber,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Your live location is being shared',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: c.stopSharing,
                          child: const Text('STOP'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: !c.ready
                      ? const Center(child: CircularProgressIndicator())
                      : c.name.isEmpty
                      ? _onboarding()
                      : _tab == 0
                      ? _nearby()
                      : _tab == 1
                      ? _chat()
                      : _tab == 2
                      ? _tools()
                      : _profile(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: c.name.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (v) => setState(() => _tab = v),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.radar), label: 'Nearby'),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Conversation',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  label: 'Field tools',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'You',
                ),
              ],
            ),
    ),
  );
  Widget _heading(String eyebrow, String title, String detail) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
     …7091 tokens truncated…ssed: () => Navigator.pop(context, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await c.sendSos();
  }

  Future<void> _send() async {
    if (_sending) {
      return;
    }
    final text = _message.text;
    setState(() => _sending = true);
    final success = await c.send(text);
    if (!mounted) {
      return;
    }
    if (success && _message.text == text) {
      _message.clear();
    }
    setState(() => _sending = false);
  }

  Future<void> _confirmLocation() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share your live location?'),
        content: Text(
          '${c.connected?.name} will receive your precise coordinates while this app is open, for up to 15 minutes. You can stop at any time. They may copy what you share.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share location'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await c.startSharing();
    }
  }

  Widget _profile() => ListView(
    key: const ValueKey('profile'),
    padding: const EdgeInsets.all(24),
    children: [
      _heading(
        'A NAME, NOT AN ACCOUNT',
        'Hello, ${c.name}.',
        'A familiar name makes it easier to find each other. It is visible to nearby people only while Lantern is on.',
      ),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolTitle(
              'Display name',
              'Enter a nickname and save. This disconnects the current session. Nearby people see this name while Lantern is on; it is not proof of identity.',
            ),
            TextField(
              controller: _name,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: 'Display name',
                hintText: c.name,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => c.saveName(_name.text),
              child: const Text('Save name & disconnect'),
            ),
          ],
        ),
      ),
      _panel(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your boundaries, built in.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16),
            Text(
              '• You choose when to be discoverable.\n• Every connection requires consent.\n• Location is off by default.\n• Backgrounding disconnects and stops sharing.\n• Messages and locations are not saved.\n• Disconnecting clears this device’s conversation.',
              style: TextStyle(height: 1.8),
            ),
          ],
        ),
      ),
      const Text(
        'Lantern 0.1.0 · Early device-testing build\nNot an emergency or rescue service. Range and availability depend on your phones and surroundings. A recipient can copy messages or coordinates. Android Nearby uses Google Play services, which may collect SDK diagnostics.',
        style: TextStyle(height: 1.6, fontSize: 12),
      ),
    ],
  );
}
