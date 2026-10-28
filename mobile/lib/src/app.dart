import 'dart:async';
import 'package:flutter/material.dart';
import 'controller.dart';
import 'services.dart';
import 'offline_guide.dart';
import 'media_service.dart';
import 'device_tools.dart';
import 'web_screen.dart';
import 'map_screen.dart';
import 'compass.dart';
import 'measurement_tools.dart';

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

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final _name = TextEditingController();
  final _message = TextEditingController();
  int _tab = 0;
  bool _sending = false;
  bool _requestAcknowledgement = false;
  bool _notifications = false;
  String? _playingNoteId;
  final _device = const PlatformDeviceTools();
  late final TorchController _torch;
  final _media = MediaSession();
  @override
  void initState() {
    super.initState();
    _torch = TorchController(_device);
    _media.addListener(_mediaChanged);
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_sessionChanged);
    c.onNoteReceived = (_) {
      if (_notifications) {
        unawaited(_notifyIncoming());
      }
    };
  }

  Future<void> _notifyIncoming() async {
    try {
      final shown = await _device.notifyMessage();
      if (!shown && mounted) {
        setState(() => _notifications = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notifications = false);
      }
    }
  }

  void _sessionChanged() {
    if (c.reconnectReason != null) {
      _tab = 0;
    }
    if (c.connected == null) {
      _requestAcknowledgement = false;
    }
    if (_playingNoteId != null &&
        !c.notes.any((note) => note.id == _playingNoteId)) {
      _playingNoteId = null;
      unawaited(_media.stopPlayback());
    }
  }

  void _mediaChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_media.background());
    }
  }

  String _reconnectMessage() {
    const cleared = 'Messages and requests were cleared; nothing was queued.';
    return switch (c.reconnectReason!) {
      ReconnectReason.backgrounded =>
        'Lantern stopped in the background. $cleared Turn it on and confirm the person again.',
      ReconnectReason.nativeStopped =>
        'The nearby session stopped. $cleared Turn Lantern on and confirm the person again.',
      ReconnectReason.peerDisconnected =>
        'The nearby connection${c.reconnectPeerName == null ? '' : ' to ${c.reconnectPeerName}'} ended. $cleared Choose and confirm the person again.',
    };
  }

  void _continueAfterInterruption() {
    setState(() => _tab = 0);
    if (c.restartNeeded) {
      unawaited(c.start());
    } else {
      c.dismissReconnectNotice();
    }
  }

  LanternController get c => widget.controller;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.onNoteReceived = null;
    c.removeListener(_sessionChanged);
    _media.removeListener(_mediaChanged);
    _media.dispose();
    _torch.dispose();
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 110) {
              return const Icon(Icons.flare_rounded, size: 26);
            }
            return const Row(
              children: [
                Icon(Icons.flare_rounded, size: 26),
                SizedBox(width: 6),
                Expanded(
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
            );
          },
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
                if (c.reconnectReason != null)
                  MaterialBanner(
                    key: const Key('reconnect-notice'),
                    leading: const Icon(Icons.link_off),
                    forceActionsBelow: true,
                    content: Semantics(
                      liveRegion: true,
                      label: 'Connection interrupted. ${_reconnectMessage()}',
                      excludeSemantics: true,
                      child: Text(_reconnectMessage()),
                    ),
                    actions: [
                      TextButton(
                        onPressed: _continueAfterInterruption,
                        child: Text(
                          c.restartNeeded ? 'Turn on Lantern' : 'Find nearby',
                        ),
                      ),
                      TextButton(
                        onPressed: c.dismissReconnectNotice,
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
    key: const ValueKey('onboarding'),
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
        'Your display name and explicitly saved offline content stay on this device. Conversations stay in memory for the current connection. No account needed.',
        style: TextStyle(height: 1.5),
      ),
    ],
  );
  Widget _nearby() => ListView(
    key: const ValueKey('nearby'),
    padding: const EdgeInsets.all(24),
    children: [
      _heading(
        'YOUR NEARBY CIRCLE',
        'Nearby people.\nYour choice.',
        c.active
            ? 'You are visible as ${c.name}. Connect with someone you can confirm in person.'
            : 'Become visible when you want company. You decide who connects.',
      ),
      _panel(
        Column(
          children: [
            _toolTitle(
              'Nearby connection',
              'Turn on Lantern on both phones. Tap Connect beside the person you know. Compare Android pairing codes on both screens before accepting. On iPhone, confirm the invitation face to face; display names are not verified identities. Turning off clears the conversation and stops location sharing.',
            ),
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
            subtitle: Text(
              c.sharing
                  ? 'Your location is being shared.'
                  : 'Your location sharing is off.',
            ),
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
          if (_media.draft != null) _attachmentDraft(),
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
          subtitle: const Text('Session only · clears on disconnect'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _help(
                'Conversation',
                'Type a message and tap the arrow to send. Sent means the transport accepted it; Delivered means the other app acknowledged it, not that the person read it. For an ordinary non-expiring work request, choose Request acknowledgement before sending. The recipient can accept or decline once. That response has its own delivery status; acceptance does not prove the work is complete. Lantern waits up to 10 seconds to submit text, then up to 30 seconds for an app receipt. You can explicitly retry ordinary text twice in this connection; it may already have arrived. Disappearing messages and attachments cannot be retried here. Use Field tools to set message expiry. The broken-link button disconnects and clears this conversation.',
              ),
              IconButton(
                tooltip: 'Disconnect and clear conversation',
                onPressed: c.disconnect,
                icon: const Icon(Icons.link_off),
              ),
            ],
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
          TextButton.icon(
            onPressed: () => setState(() => _tab = 2),
            icon: const Icon(Icons.near_me_outlined),
            label: const Text('Their location is available · View field tools'),
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
                            if (note.attachmentBytes != null) _attachment(note),
                            if (note.text.isNotEmpty)
                              SelectableText(
                                note.text,
                                style: TextStyle(
                                  color: note.mine ? Colors.white : ink,
                                  fontSize: 16,
                                ),
                              ),
                            if (note.expiresAt != null)
                              Text(
                                'Disappears at ${_clock(note.expiresAt!)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: note.mine
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            if (note.replyTo != null)
                              Text(
                                'Response to request',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: note.mine
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            if (note.responseRequested) ...[
                              const SizedBox(height: 6),
                              Text(
                                switch (note.workDecision) {
                                  WorkDecision.accepted =>
                                    note.mine
                                        ? 'Accepted by colleague'
                                        : 'You accepted',
                                  WorkDecision.declined =>
                                    note.mine
                                        ? 'Declined by colleague'
                                        : 'You declined',
                                  null =>
                                    note.mine
                                        ? 'Response requested · waiting'
                                        : 'Response requested',
                                },
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: note.mine
                                      ? Colors.white
                                      : const Color(0xFF244B3F),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              note.mine
                                  ? switch (note.delivery) {
                                      Delivery.sending => 'Sending…',
                                      Delivery.sent =>
                                        'Sent · awaiting receipt',
                                      Delivery.delivered => 'Delivered',
                                      Delivery.failed =>
                                        note.attachmentBytes == null
                                            ? 'Delivery unconfirmed'
                                            : 'Transfer failed',
                                    }
                                  : '${note.time.hour.toString().padLeft(2, '0')}:${note.time.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: note.mine
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                            if (c.canRetry(note))
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _retryMessage(note),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry message'),
                              ),
                            if (c.canRespondToRequest(note))
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  FilledButton(
                                    onPressed: () => _respondToRequest(
                                      note,
                                      WorkDecision.accepted,
                                    ),
                                    child: const Text('Accept request'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _respondToRequest(
                                      note,
                                      WorkDecision.declined,
                                    ),
                                    child: const Text('Decline request'),
                                  ),
                                ],
                              ),
                            if (note.mine && note.deliveryDetail != null)
                              Text(
                                note.deliveryDetail!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            if (note.mine &&
                                note.attachmentBytes == null &&
                                note.delivery == Delivery.failed &&
                                (note.expiresAt != null ||
                                    note.sendAttempts >=
                                        LanternController.maxTextSubmissions))
                              Text(
                                note.expiresAt != null
                                    ? 'Retry unavailable for disappearing messages.'
                                    : 'Retry limit reached. Confirm with your colleague.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_media.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_media.error),
          ),
        if (_media.draft != null) _attachmentDraft(),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Choose photo · may disconnect',
              onPressed: _media.busy || _media.recording
                  ? null
                  : () => _media.pickPhoto(camera: false),
              icon: const Icon(Icons.photo_outlined),
            ),
            IconButton(
              tooltip: 'Take photo · may disconnect',
              onPressed: _media.busy || _media.recording
                  ? null
                  : () => _media.pickPhoto(camera: true),
              icon: const Icon(Icons.camera_alt_outlined),
            ),
            IconButton(
              tooltip: _media.recording
                  ? 'Stop recording and review'
                  : 'Record voice · up to 30 seconds',
              onPressed: _media.busy
                  ? null
                  : _media.recording
                  ? _media.stopRecording
                  : _media.startRecording,
              icon: Icon(_media.recording ? Icons.stop_circle : Icons.mic_none),
            ),
            IconButton(
              tooltip: 'Insert emoji',
              onPressed: _emojiPicker,
              icon: const Icon(Icons.emoji_emotions_outlined),
            ),
            _help(
              'Photos and voice',
              'Choose or take a photo, or record up to 30 seconds. Review the draft before sending. Photos are resized and re-encoded without embedded location metadata; each attachment is limited to 1 MiB. The photo picker may disconnect this foreground-only app. Your draft stays on this phone until you reconnect, send or discard it. Voice recording stops and is discarded when the app backgrounds. Recipients can copy attachments. Voice never plays automatically.',
            ),
            if (_media.recording) const Text('Recording · maximum 30 seconds'),
            if (_media.playing)
              TextButton(
                onPressed: _media.stopPlayback,
                child: const Text('Stop audio'),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _requestAcknowledgement,
                onChanged: c.messageLifetimeSeconds == null
                    ? (value) => setState(
                        () => _requestAcknowledgement = value ?? false,
                      )
                    : null,
                title: const Text('Request acknowledgement'),
                subtitle: Text(
                  c.messageLifetimeSeconds == null
                      ? 'The recipient can accept or decline once.'
                      : 'Turn off message expiry to request a response.',
                ),
              ),
              Row(
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
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _retryMessage(Note note) async {
    if (!c.canRetry(note)) {
      return;
    }
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retry this message?'),
        content: const Text(
          'The message may already have arrived without a receipt. Retry sends the same message ID to this colleague in this connection. It does not confirm that they read or accepted the request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry now'),
          ),
        ],
      ),
    );
    if (mounted && retry == true) {
      await c.retry(note);
    }
  }

  Future<void> _respondToRequest(Note note, WorkDecision decision) async {
    if (!c.canRespondToRequest(note)) {
      return;
    }
    final verb = decision == WorkDecision.accepted ? 'accept' : 'decline';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${verb[0].toUpperCase()}${verb.substring(1)} request?'),
        content: Text(
          'This tells ${c.connected?.name ?? 'your connected colleague'} that you chose to $verb this request. It does not confirm that the work is complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              decision == WorkDecision.accepted ? 'Accept' : 'Decline',
            ),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await c.respondToRequest(note, decision);
    }
  }

  Widget _attachment(Note note) {
    final bytes = note.attachmentBytes!;
    if (note.attachmentMime!.startsWith('image/')) {
      return Image.memory(
        bytes,
        width: 220,
        height: 150,
        fit: BoxFit.contain,
        cacheWidth: 440,
        errorBuilder: (_, _, _) => const Text('Photo cannot be displayed'),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: note.mine ? Colors.white : ink,
      ),
      onPressed: () {
        _playingNoteId = note.id;
        unawaited(_media.play(bytes));
      },
      icon: const Icon(Icons.play_arrow),
      label: const Text('Play voice note'),
    );
  }

  Widget _attachmentDraft() {
    final draft = _media.draft!;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      color: const Color(0xFFE4EADF),
      child: Row(
        children: [
          if (draft.isPhoto)
            Image.memory(
              draft.bytes,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              cacheWidth: 96,
            )
          else
            IconButton(
              tooltip: 'Preview voice draft',
              onPressed: () => _media.play(draft.bytes),
              icon: const Icon(Icons.play_arrow),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${draft.isPhoto ? 'Photo' : 'Voice'} draft · ${(draft.bytes.length / 1024).ceil()} KiB${c.connected == null ? '\nReconnect to send.' : ''}',
            ),
          ),
          IconButton(
            tooltip: 'Discard attachment',
            onPressed: _media.clearDraft,
            icon: const Icon(Icons.close),
          ),
          IconButton(
            tooltip: 'Review recipient and send attachment',
            onPressed: c.connected == null || c.sendingAttachment
                ? null
                : _sendAttachment,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Future<void> _sendAttachment() async {
    final draft = _media.draft;
    final peer = c.connected;
    if (draft == null || peer == null) {
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send to ${peer.name}?'),
        content: Text(
          'Send this ${draft.isPhoto ? 'photo' : 'voice note'} to the connected person. They may save or copy it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send attachment'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted && c.connected?.id == peer.id) {
      if (await c.sendAttachment(draft.bytes, draft.mime)) {
        _media.clearDraft();
      }
    }
  }

  Future<void> _emojiPicker() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Insert an emoji'),
      content: Wrap(
        spacing: 8,
        children: ['👍', '✅', '📍', '🔧', '🧹', '🕐', '👋', '🙏']
            .map(
              (emoji) => TextButton(
                onPressed: () {
                  _message.text = '${_message.text}$emoji';
                  _message.selection = TextSelection.collapsed(
                    offset: _message.text.length,
                  );
                  Navigator.pop(context);
                },
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget _devicePanel() => ListenableBuilder(
    listenable: _torch,
    builder: (context, _) => _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toolTitle(
            'Device tools',
            'Torch switches on the camera light. Flash SOS blinks the light locally; it sends no message and calls nobody. Stop it at any time. Both stop when Lantern backgrounds. Avoid flashing near anyone sensitive to flashing lights. Notifications are optional, generic and only generated while this app receives messages; they do not keep connections alive in the background.',
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _torch.busy ? null : _torch.toggle,
                icon: Icon(
                  _torch.torchOn ? Icons.flashlight_off : Icons.flashlight_on,
                ),
                label: Text(_torch.torchOn ? 'Torch off' : 'Torch on'),
              ),
              OutlinedButton.icon(
                onPressed: _torch.sosActive ? _torch.stop : _confirmFlashSos,
                icon: const Icon(Icons.sos),
                label: Text(_torch.sosActive ? 'Stop flashing' : 'Flash SOS'),
              ),
            ],
          ),
          if (_torch.error != null) Text(_torch.error!),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Generic message notifications'),
            subtitle: const Text(
              'Opt-in for this app session. No message text shown.',
            ),
            value: _notifications,
            onChanged: _setNotifications,
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                await _device.openAppSettings();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Settings unavailable: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open system permissions'),
          ),
        ],
      ),
    ),
  );

  Future<void> _setNotifications(bool enabled) async {
    try {
      final allowed = enabled && await _device.requestNotifications();
      if (!enabled) {
        await _device.clearNotifications();
      }
      if (mounted) {
        setState(() => _notifications = allowed);
      }
      if (enabled && !allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications not permitted. Change this in system settings.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notifications unavailable: $e')),
        );
      }
    }
  }

  Future<void> _confirmFlashSos() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flash an SOS signal?'),
        content: const Text(
          'Blinks your phone light. It does not contact anyone. Avoid use around people sensitive to flashing lights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start flashing'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await _torch.startSos();
    }
  }

  String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Widget _help(String title, String text) => IconButton(
    tooltip: 'Explain $title',
    icon: const Icon(Icons.help_outline, size: 22),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    ),
  );

  Widget _toolTitle(String title, String help) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      _help(title, help),
    ],
  );

  Widget _tools() => ListView(
    key: const ValueKey('field-tools'),
    padding: const EdgeInsets.all(20),
    children: [
      _devicePanel(),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const CompassScreen())),
        icon: const Icon(Icons.explore_outlined),
        label: const Text('Compass · find north'),
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MeasurementToolsScreen(),
          ),
        ),
        icon: const Icon(Icons.calculate_outlined),
        label: const Text('Calculator & measurements'),
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => MapScreen(controller: c)),
        ),
        icon: const Icon(Icons.map_outlined),
        label: const Text('Open maps'),
      ),
      Tooltip(
        message: 'Browse online or read pages you deliberately saved offline.',
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const WebScreen())),
          icon: const Icon(Icons.public),
          label: const Text('Web & saved pages'),
        ),
      ),
      _heading(
        'WHILE YOU ARE HERE',
        'Field tools',
        'Tap a question mark for instructions. These tools run only while Lantern stays open.',
      ),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolTitle(
              'Disappearing messages',
              'Choose how long new messages remain visible. Existing messages keep their original expiry. Disconnecting clears the conversation. Recipients can still copy or screenshot messages.',
            ),
            const Text('Applies to messages you send next.'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: c.messageLifetimeSeconds ?? 0,
              decoration: const InputDecoration(labelText: 'Message lifetime'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Until disconnect')),
                DropdownMenuItem(value: 60, child: Text('1 minute')),
                DropdownMenuItem(value: 300, child: Text('5 minutes')),
                DropdownMenuItem(value: 900, child: Text('15 minutes')),
                DropdownMenuItem(value: 3600, child: Text('1 hour')),
              ],
              onChanged: (value) {
                c.setMessageLifetime(value == 0 ? null : value);
                if (value != null && value != 0 && _requestAcknowledgement) {
                  setState(() => _requestAcknowledgement = false);
                }
              },
            ),
          ],
        ),
      ),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolTitle(
              'Location sharing',
              'Connect first. Share sends precise coordinates to that one person for up to 15 minutes. Stop immediately with Stop sharing. Closing or backgrounding Lantern stops sharing. Old received positions expire after 30 seconds. Copies made by a recipient cannot be removed.',
            ),
            Text(
              c.sharing
                  ? 'Sharing until ${_clock(c.shareUntil!)}'
                  : 'Your location sharing is off.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: c.connected == null
                  ? null
                  : c.sharing
                  ? c.stopSharing
                  : _confirmLocation,
              icon: Icon(
                c.sharing ? Icons.location_off : Icons.location_on_outlined,
              ),
              label: Text(c.sharing ? 'Stop sharing' : 'Share for 15 minutes'),
            ),
            if (c.connected == null)
              const Text('Connect on the Nearby tab first.'),
            if (c.remoteLocation != null) ...[
              const Divider(height: 28),
              const Text(
                'Their latest position',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _position(c.remoteLocation!.fix),
              const Text('Expires after 30 seconds without an update.'),
            ],
          ],
        ),
      ),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolTitle(
              'Offline navigation',
              'Start local GPS to keep a breadcrumb trail on this phone. This does not share your position. Save a named waypoint, then read its straight-line distance and bearing. Bearings are degrees clockwise from true north, not turn-by-turn directions. Clear trail also removes all waypoints. No maps or obstacle information are included. Data stays in memory.',
            ),
            Text(
              c.navigating
                  ? 'Local GPS active · ${c.breadcrumbs.length} trail points'
                  : 'Local GPS is off.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: c.navigating ? c.stopNavigation : c.startNavigation,
              icon: Icon(c.navigating ? Icons.gps_off : Icons.gps_fixed),
              label: Text(c.navigating ? 'Stop local GPS' : 'Start local GPS'),
            ),
            if (c.navigating && c.localFix == null)
              const Text(
                'Waiting for a GPS fix. Move near a window or outdoors.',
              ),
            if (c.localFix != null) _position(c.localFix!, showVector: false),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: c.localFix == null ? null : _saveWaypoint,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Save waypoint'),
                ),
                TextButton(
                  onPressed: c.breadcrumbs.isEmpty ? null : c.clearTrail,
                  child: const Text('Clear trail & waypoints'),
                ),
              ],
            ),
            if (c.breadcrumbs.isNotEmpty) ...[
              const Text(
                'Trail start',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _position(c.breadcrumbs.first),
            ],
            ...c.waypoints.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _position(entry.value),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolTitle(
              'Buddy check-in',
              'Connect and ask that person to be your guardian. They must accept. Start a timer and tap Check in before it ends. If it expires, Lantern attempts an alert to that connected person. Keep both apps open and within range. Disconnecting or backgrounding cancels the timer. It does not call emergency services, work in the background, or guarantee help. SOS does not silently start location sharing.',
            ),
            const Text('Foreground only. Not an emergency or rescue service.'),
            const SizedBox(height: 12),
            if (c.guardianStatus.isNotEmpty) Text(c.guardianStatus),
            if (c.guardianRequested) ...[
              Text(
                '${c.connected?.name ?? 'Your peer'} asks you to be their guardian.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => c.respondGuardian(true),
                    child: const Text('Accept guardian role'),
                  ),
                  TextButton(
                    onPressed: () => c.respondGuardian(false),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ],
            if (!c.guardianAccepted)
              OutlinedButton(
                onPressed: c.connected == null ? null : c.requestGuardian,
                child: const Text('Ask connected person to be guardian'),
              ),
            if (c.guardianAccepted) ...[
              if (c.checkInUntil == null)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => c.armCheckIn(const Duration(minutes: 5)),
                      child: const Text('5-minute check-in'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          c.armCheckIn(const Duration(minutes: 15)),
                      child: const Text('15-minute check-in'),
                    ),
                  ],
                )
              else ...[
                Text(
                  'Check in by ${_clock(c.checkInUntil!)}. Keep Lantern open.',
                ),
                FilledButton(
                  onPressed: c.cancelCheckIn,
                  child: const Text('Check in · cancel timer'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _confirmSos,
                icon: const Icon(Icons.sos),
                label: const Text('Send buddy SOS'),
              ),
            ],
            if (c.incomingAlert.isNotEmpty) ...[
              const Divider(),
              Text(
                c.incomingAlert,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _position(Fix fix, {bool showVector = true}) {
    final vector = showVector ? c.navigationTo(fix) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}',
          ),
          Text('GPS accuracy ±${fix.accuracy.round()} m'),
          if (vector != null)
            Text(
              '${vector.distanceMeters.round()} m straight-line · ${vector.bearingDegrees.round()}° from true north',
            ),
        ],
      ),
    );
  }

  Future<void> _saveWaypoint() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this position'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Waypoint name',
            hintText: 'Car, camp or meeting point',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // The dialog exit animation may still read its controller. Keep disposal
    // after its route has left the widget tree.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      c.saveWaypoint(name);
    }
  }

  Future<void> _confirmSos() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send a buddy SOS?'),
        content: Text(
          'Ask ${c.connected?.name ?? 'your guardian'} for help over this connection. Delivery needs both phones connected and open. This does not call emergency services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await c.sendSos();
    }
  }

  Future<void> _send() async {
    if (_sending) {
      return;
    }
    final text = _message.text;
    setState(() => _sending = true);
    final existing = c.notes.toSet();
    final submission = c.send(text, responseRequested: _requestAcknowledgement);
    // An admitted note owns this draft even if its native call later times out.
    // Leaving it in the composer would create a new ID on the next Send tap.
    final admitted = c.notes.any(
      (note) => note.mine && !existing.contains(note),
    );
    if (admitted && _message.text == text) {
      _message.clear();
      _requestAcknowledgement = false;
    }
    await submission;
    if (!mounted) {
      return;
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
        'Lantern 0.2.0 · Early device-testing build\nNot an emergency or rescue service. Range and availability depend on your phones and surroundings. A recipient can copy messages or coordinates. Android Nearby uses Google Play services, which may collect SDK diagnostics.',
        style: TextStyle(height: 1.6, fontSize: 12),
      ),
    ],
  );
}
