import 'package:flutter/material.dart';
import 'controller.dart';

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
            Text(
              'lantern',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                fontSize: 29,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Chip(
              label: Text(
                c.active ? 'VISIBLE NEARBY' : 'INVISIBLE',
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: Color(0xFF66756E),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(
          fontSize: 36,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          color: ink,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        detail,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: Color(0xFF52645D),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
  Widget _panel(Widget child, {Color color = Colors.white}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
  Widget _onboarding() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 28),
      _heading(
        'LESS DISTANCE. MORE CONNECTION.',
        'Be here.\nStay together.',
        'A little light between you and the people nearby. Message without mobile data. Share your location only when you choose.',
      ),
      _panel(
        const Icon(Icons.flare_rounded, size: 100, color: ink),
        color: amber,
      ),
      TextField(
        controller: _name,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'What should people call you?',
          hintText: 'Your first name or nickname',
        ),
        onSubmitted: c.saveName,
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () => c.saveName(_name.text),
        child: const Text('Make yourself at home'),
      ),
      const SizedBox(height: 18),
      const Text(
        'Only your display name is saved. Messages and locations stay in memory for the current connection. No account needed.',
        style: TextStyle(height: 1.5),
      ),
    ],
  );
  Widget _nearby() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      _heading(
        'YOUR NEARBY CIRCLE',
        'Good company.\nNo signal needed.',
        c.active
            ? 'You are visible as ${c.name}. Connect with someone you can confirm in person.'
            : 'Become visible when you want company. You decide who connects.',
      ),
      _panel(
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.active ? amber : paper,
              ),
              child: Icon(
                c.active ? Icons.radar : Icons.wifi_tethering_off,
                size: 54,
                color: ink,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              c.active ? 'Your lantern is on' : 'A quiet moment',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              c.active
                  ? '${c.peers.length} nearby ${c.peers.length == 1 ? 'person' : 'people'} discovered'
                  : 'You are not discoverable.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: c.busy
                    ? null
                    : c.active
                    ? c.stop
                    : c.start,
                icon: Icon(c.active ? Icons.stop_circle_outlined : Icons.flare),
                label: Text(
                  c.busy
                      ? 'Turning on…'
                      : c.active
                      ? 'Turn off & disconnect'
                      : 'Turn on Lantern',
                ),
              ),
            ),
          ],
        ),
      ),
      if (c.invitation != null)
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect with ${c.invitation!.peer.name}?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (c.invitation!.code.isNotEmpty) ...[
                const Text(
                  'Compare this code on both phones. Accept only if it matches.',
                ),
                const SizedBox(height: 12),
                Text(
                  c.invitation!.code,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                ),
              ] else
                const Text(
                  'Confirm the invitation with the person beside you. iPhone display names are not verified identities.',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: () => c.respond(true),
                    child: Text(
                      c.invitation!.code.isEmpty
                          ? 'Accept connection'
                          : 'Codes match · Accept',
                    ),
                  ),
                  TextButton(
                    onPressed: () => c.respond(false),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ],
          ),
          color: amber,
        ),
      if (c.connected != null)
        _panel(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text('Connected to ${c.connected!.name}'),
            subtitle: const Text('Location is off until you share it.'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => setState(() => _tab = 1),
          ),
        ),
      if (c.requesting != null && c.invitation == null)
        _panel(
          Row(
            children: [
              const Expanded(child: Text('Waiting for the other person…')),
              TextButton(onPressed: c.disconnect, child: const Text('Cancel')),
            ],
          ),
        ),
      if (c.active && c.connected == null)
        ...c.peers.values.map(
          (peer) => _panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: paper,
                child: Text(
                  peer.name.isEmpty
                      ? '?'
                      : peer.name.characters.first.toUpperCase(),
                ),
              ),
              title: Text(peer.name),
              subtitle: const Text('Nearby · identity not yet confirmed'),
              trailing: TextButton(
                onPressed: c.requesting == null && c.invitation == null
                    ? () => c.request(peer)
                    : null,
                child: const Text('Connect'),
              ),
            ),
          ),
        ),
      const Text(
        'ANDROID ↔ ANDROID  ·  IPHONE ↔ IPHONE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Keep both apps open, Bluetooth and Wi-Fi enabled. No internet is needed for conversations. This version does not connect Android to iPhone.',
        style: TextStyle(height: 1.5, color: Color(0xFF52645D)),
      ),
    ],
  );
  Widget _chat() {
    if (c.connected == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _heading(
            'A LITTLE CLOSER',
            'Start with\na hello.',
            'Connect with a nearby person first. Your conversation disappears when you disconnect.',
          ),
          FilledButton(
            onPressed: () => setState(() => _tab = 0),
            child: const Text('Find someone nearby'),
          ),
        ],
      );
    }
    final remote = c.remoteLocation;
    return Column(
      children: [
        ListTile(
          title: Text(
            c.connected!.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
          ),
          subtitle: const Text('Private session · kept only in memory'),
          trailing: IconButton(
            tooltip: 'Disconnect and clear conversation',
            onPressed: c.disconnect,
            icon: const Icon(Icons.link_off),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: c.sharing ? c.stopSharing : _confirmLocation,
            icon: Icon(
              c.sharing ? Icons.location_off : Icons.location_on_outlined,
            ),
            label: Text(
              c.sharing
                  ? 'Stop sharing location'
                  : 'Share location for 15 minutes',
            ),
          ),
        ),
        if (remote != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THEIR LAST LOCATION',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    '${remote.fix.latitude.toStringAsFixed(5)}, ${remote.fix.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Accuracy ±${remote.fix.accuracy.round()} m · expires after 30 seconds without an update',
                  ),
                  const Text('Coordinates only. No offline map is included.'),
                ],
              ),
              color: const Color(0xFFE4EADF),
            ),
          ),
        Expanded(
          child: c.notes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'You’re connected. Say hello.\nLocation sharing is optional.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.6),
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: c.notes.length,
                  itemBuilder: (context, index) {
                    final note = c.notes[c.notes.length - 1 - index];
                    return Align(
                      alignment: note.mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 330),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: note.mine ? ink : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              note.text,
                              style: TextStyle(
                                color: note.mine ? Colors.white : ink,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              note.mine
                                  ? switch (note.delivery) {
                                      Delivery.sending => 'Sending…',
                                      Delivery.sent =>
                                        'Sent · awaiting receipt',
                                      Delivery.delivered => 'Delivered',
                                      Delivery.failed => 'Failed · send again',
                                    }
                                  : '${note.time.hour.toString().padLeft(2, '0')}:${note.time.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: note.mine
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _message,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'A message for right here…',
                    counterText: '',
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                tooltip: 'Send message',
                icon: const Icon(Icons.arrow_upward),
              ),
            ],
          ),
        ),
      ],
    );
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
