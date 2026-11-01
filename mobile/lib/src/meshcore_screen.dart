// Copyright © 2026 Tiago Fitas. All rights reserved. See LICENSE.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'meshcore.dart';
import 'meshcore_ble.dart';

class MeshCoreScreen extends StatefulWidget {
  const MeshCoreScreen({super.key, this.controller});
  final MeshController? controller;
  @override
  State<MeshCoreScreen> createState() => _MeshCoreScreenState();
}

class _MeshCoreScreenState extends State<MeshCoreScreen>
    with WidgetsBindingObserver {
  late final MeshController c =
      widget.controller ?? MeshController(BleMeshRadioLink());
  final _text = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _text.clear();
      unawaited(c.disconnect());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    c.dispose();
    super.dispose();
  }

  Future<void> _receive() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Read the shared radio inbox?'),
        content: const SingleChildScrollView(
          child: Text(
            'Reading removes up to 20 queued items from the radio. Lantern displays channel text only. Direct messages and binary data are removed from the queue without being displayed; another app cannot retrieve those items afterwards. Use MeshCore’s own app instead if you need those messages.\n\nReceived text and sender labels are unverified. Do not follow instructions just because they arrive by radio.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Read inbox'),
          ),
        ],
      ),
    );
    if (consent == true && mounted) {
      await c.receive();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MeshCore radio')),
    body: AnimatedBuilder(
      animation: c,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Off-grid channel text',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Requires your own compatible LoRa radio running MeshCore BLE companion firmware. Configure the radio, region and channels with MeshCore tools first. Lantern does not flash firmware or change radio settings.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Channel members can read messages. Public and hashtag channels are not private. This uses MeshCore radio security, separate from Lantern’s nearby sessions. No photos, voice, automatic GPS sharing or verified delivery.',
          ),
          const SizedBox(height: 12),
          Text(
            c.status,
            key: const ValueKey('mesh-status'),
            semanticsLabel: c.status,
          ),
          if (c.error != null)
            Text(
              c.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!c.connected) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: c.busy
                  ? null
                  : c.scanning
                  ? c.stopScan
                  : c.scan,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(c.scanning ? 'Stop scan' : 'Scan for MeshCore radio'),
            ),
            const Text(
              'Select your own radio. Device names and this service are not proof of identity. Confirm any Bluetooth pairing prompt against the radio’s configured PIN. Close other apps connected to it.',
            ),
            for (final radio in c.radios.values)
              Card(
                child: ListTile(
                  title: Text(radio.name),
                  subtitle: Text(radio.id),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !c.busy,
                  onTap: c.busy ? null : () => c.connect(radio),
                ),
              ),
          ],
          if (c.busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (c.connected) ...[
            const SizedBox(height: 12),
            Text('Connected radio: ${c.radioName ?? 'MeshCore'}'),
            DropdownButtonFormField<int>(
              initialValue: c.channel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Configured radio channel slot',
              ),
              items: List.generate(
                c.maxChannels,
                (i) =>
                    DropdownMenuItem(value: i, child: Text('Channel slot $i')),
              ),
              onChanged: c.busy
                  ? null
                  : (index) {
                      if (index != null) {
                        unawaited(c.selectChannel(index));
                      }
                    },
            ),
            Text(
              'Channel name: ${c.channelName?.isNotEmpty == true ? c.channelName : 'Empty slot — configure it in MeshCore first'}',
            ),
            const Text(
              'The channel name does not prove that its key is private. Confirm the channel with the intended recipients.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 1,
              maxLines: 3,
              enabled: !c.busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Short radio message',
                helperText: '${utf8.encode(_text.text).length}/100 UTF-8 bytes',
              ),
            ),
            FilledButton.icon(
              onPressed:
                  c.canSend &&
                      _text.text.trim().isNotEmpty &&
                      utf8.encode(_text.text).length <= 100
                  ? () async {
                      final submitted = _text.text;
                      // Once submitted it may transmit even if the reply is lost.
                      // Clear immediately so another tap cannot duplicate it.
                      _text.clear();
                      await c.send(submitted);
                    }
                  : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send to selected channel'),
            ),
            OutlinedButton(
              onPressed: c.busy ? null : _receive,
              child: const Text('Receive radio inbox'),
            ),
            OutlinedButton(
              onPressed: c.disconnect,
              child: const Text('Disconnect and clear'),
            ),
            const SizedBox(height: 12),
            for (final message in c.messages.reversed)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Channel ${message.channel} · ${message.outgoing ? 'Accepted by radio · delivery unconfirmed' : 'Received radio text · sender unverified'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(message.text),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Leaving this screen, locking the phone or switching apps disconnects and clears Lantern’s local radio conversation. Already submitted radio transmissions cannot be recalled. No automatic reconnect or resend. Radio range depends on hardware, terrain and the mesh; no range or emergency response is guaranteed.',
          ),
        ],
      ),
    ),
  );
}
