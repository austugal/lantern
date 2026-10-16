import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'controller.dart';
import 'offline_map.dart';
import 'services.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.controller});
  final LanternController controller;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final _map = MapController();
  OfflineArea? _area;
  HttpClient? _downloadClient;
  bool _foreground = true;
  bool _online = false, _busy = false, _startedGps = false;
  String? _status;
  static DateTime? _lastDownload;
  LanternController get c => widget.controller;
  LatLng _point(Fix f) => LatLng(f.latitude, f.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restore());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && mounted) {
      _downloadClient?.close(force: true);
      setState(() => _online = false);
    }
  }

  Future<File> _file() async => File(
    '${(await getApplicationSupportDirectory()).path}/lantern-area.geojson',
  );

  Future<String> _read(File file) async {
    if (await file.length() > OfflineArea.maxBytes) {
      throw const FormatException('Choose a map smaller than 5 MB.');
    }
    return file.readAsString();
  }

  Future<void> _restore() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return;
      }
      final area = OfflineArea.parse(await _read(file));
      if (mounted) {
        setState(() => _area = area);
        _centreArea(area);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'Saved map could not be loaded. Import or save an area again.',
        );
      }
    }
  }

  Future<void> _save(String json) async {
    final area = OfflineArea.parse(json);
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(json, flush: true);
    await temp.rename(file.path);
    if (!mounted) {
      return;
    }
    setState(() {
      _area = area;
      _online = false;
      _status = 'Area saved. This basic map now works without internet.';
    });
    _centreArea(area);
  }

  void _centreArea(OfflineArea area) {
    final p = area.shapes.first.points.first;
    _map.move(LatLng(p[1], p[0]), 16);
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Could not complete map action: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() => _run(() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (selected == null || selected.files.single.path == null || !mounted) {
      return;
    }
    await _save(await _read(File(selected.files.single.path!)));
  });

  Future<void> _download() async {
    final fix = c.localFix;
    if (fix == null) {
      return;
    }
    if (_lastDownload != null &&
        DateTime.now().difference(_lastDownload!) <
            const Duration(minutes: 1)) {
      setState(
        () => _status = 'Please wait one minute between area downloads.',
      );
      return;
    }
    if (!await _confirm(
      'Save nearby area offline?',
      'Send ${fix.latitude.toStringAsFixed(6)}, ${fix.longitude.toStringAsFixed(6)} to overpass-api.de to download basic roads, building outlines and landmarks within about 500 metres. Up to 5 MB; internet required now. Replaces the saved area. The area and its location stay on this phone until deleted. Map details may be missing or outdated.',
    )) {
      return;
    }
    if (!mounted || !_foreground) {
      return;
    }
    _lastDownload = DateTime.now();
    await _run(() async {
      final data = await downloadNearbyArea(
        fix.latitude,
        fix.longitude,
        onClient: (client) => _downloadClient = client,
      );
      _downloadClient = null;
      if (mounted && _foreground) {
        await _save(data);
      }
    });
  }

  Future<void> _share(bool help) async {
    final fix = c.localFix;
    final stamp = c.localFixAt;
    final peer = c.connected;
    if (fix == null || stamp == null || peer == null) {
      return;
    }
    if (!await _confirm(
      help ? 'Send I need help?' : 'Share my position?',
      'Send ${fix.latitude.toStringAsFixed(6)}, ${fix.longitude.toStringAsFixed(6)}, accuracy ±${fix.accuracy.round()} m, fix ${stamp.toLocal().toIso8601String()} to ${peer.name} only. This is a one-time message, not live tracking. It does not contact emergency services and cannot reach people beyond the current connection.',
    )) {
      return;
    }
    if (!mounted || !_foreground || !identical(c.connected, peer)) {
      return;
    }
    if (DateTime.now().difference(stamp) > const Duration(seconds: 30)) {
      setState(
        () => _status =
            'Position is more than 30 seconds old. Wait for a fresh GPS fix and try again.',
      );
      return;
    }
    final text =
        '${help ? 'I need help. Find me here:' : 'My position:'} '
        '${fix.latitude.toStringAsFixed(6)}, ${fix.longitude.toStringAsFixed(6)}. '
        'GPS accuracy ±${fix.accuracy.round()} m. Fix time ${stamp.toUtc().toIso8601String()}. '
        'https://www.openstreetmap.org/?mlat=${fix.latitude}&mlon=${fix.longitude}#map=17/${fix.latitude}/${fix.longitude}';
    final sent = await c.send(text);
    if (mounted) {
      setState(
        () => _status = sent
            ? 'Sent to the current connection. Check the conversation for acknowledgement; this is not confirmation of rescue.'
            : 'Not sent. Check the connection and try another way to reach help.',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadClient?.close(force: true);
    if (_startedGps) {
      unawaited(c.stopNavigation());
    }
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final fix = c.localFix;
      final remote = c.remoteLocation;
      final area = _area;
      return Scaffold(
        appBar: AppBar(title: const Text('Map & find me')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: fix == null
                            ? const LatLng(20, 0)
                            : _point(fix),
                        initialZoom: fix == null ? 2 : 16,
                        minZoom: 2,
                        maxZoom: 19,
                      ),
                      children: [
                        if (_online)
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'org.austugal.lantern',
                            maxNativeZoom: 19,
                          ),
                        if (!_online && area != null)
                          PolylineLayer(
                            polylines: [
                              for (final shape in area.shapes.where(
                                (s) => s.points.length > 1,
                              ))
                                Polyline(
                                  points: shape.points
                                      .map((p) => LatLng(p[1], p[0]))
                                      .toList(),
                                  color: shape.closed
                                      ? Colors.blueGrey
                                      : Colors.orange.shade800,
                                  strokeWidth: shape.closed ? 1.5 : 3,
                                ),
                            ],
                          ),
                        if (c.breadcrumbs.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: c.breadcrumbs.map(_point).toList(),
                                color: Colors.teal,
                                strokeWidth: 4,
                              ),
                            ],
                          ),
                        if (fix != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _point(fix),
                                radius: fix.accuracy,
                                useRadiusInMeter: true,
                                color: Colors.blue.withValues(alpha: .12),
                                borderColor: Colors.blue,
                                borderStrokeWidth: 1,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (!_online && area != null)
                              for (final s
                                  in area.shapes
                                      .where((s) => s.points.length == 1)
                                      .take(300))
                                Marker(
                                  point: LatLng(
                                    s.points.first[1],
                                    s.points.first[0],
                                  ),
                                  width: 32,
                                  height: 32,
                                  child: Tooltip(
                                    message: s.label.isEmpty
                                        ? 'Map landmark'
                                        : s.label,
                                    child: const Icon(
                                      Icons.place,
                                      size: 20,
                                      color: Colors.brown,
                                    ),
                                  ),
                                ),
                            if (fix != null)
                              Marker(
                                point: _point(fix),
                                child: const Tooltip(
                                  message:
                                      'Your GPS position; circle shows accuracy',
                                  child: Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            if (remote != null)
                              Marker(
                                point: _point(remote.fix),
                                child: const Tooltip(
                                  message:
                                      'Colleague shared position; may be up to 30 seconds old',
                                  child: Icon(
                                    Icons.person_pin_circle,
                                    color: Colors.purple,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (!_online && area == null)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'No offline map saved. Enable online map or save/import an area.\nGPS markers alone are not a street map.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 4,
                      child: ColoredBox(
                        color: Colors.white,
                        child: Text(
                          _online
                              ? '© OpenStreetMap contributors · openstreetmap.org/copyright'
                              : area == null
                              ? 'No map data loaded'
                              : '${area.attribution}\nSaved ${area.savedAt.isEmpty ? 'date unknown' : area.savedAt}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fix == null
                            ? 'GPS is off or waiting for a fix.'
                            : '${fix.latitude.toStringAsFixed(6)}, ${fix.longitude.toStringAsFixed(6)} · accuracy ±${fix.accuracy.round()} m\nFix: ${c.localFixAt?.toLocal().toIso8601String() ?? 'unknown'}',
                      ),
                      const Text(
                        'Foreground only. GPS can be inaccurate indoors or under debris. No rescue service is contacted.',
                      ),
                      if (c.error.isNotEmpty) Text(c.error),
                      if (_status != null)
                        Text(
                          _status!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      if (_busy) const LinearProgressIndicator(),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            icon: Icon(
                              c.navigating
                                  ? Icons.location_off
                                  : Icons.my_location,
                            ),
                            label: Text(
                              c.navigating ? 'Stop GPS' : 'Start GPS',
                            ),
                            onPressed: () async {
                              if (c.navigating) {
                                await c.stopNavigation();
                              } else {
                                _startedGps = true;
                                await c.startNavigation();
                              }
                            },
                          ),
                          TextButton(
                            onPressed: fix == null
                                ? null
                                : () => _map.move(_point(fix), 16),
                            child: const Text('Centre on me'),
                          ),
                          TextButton(
                            onPressed: fix == null
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text:
                                            '${fix.latitude}, ${fix.longitude} (±${fix.accuracy.round()} m)',
                                      ),
                                    );
                                    if (mounted) {
                                      setState(
                                        () => _status =
                                            'Coordinates copied. Clipboard may be visible to other apps.',
                                      );
                                    }
                                  },
                            child: const Text('Copy coordinates'),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Online street map'),
                        subtitle: const Text(
                          'Internet required; provider receives the area you view.',
                        ),
                        value: _online,
                        onChanged: (value) async {
                          if (!value) {
                            setState(() => _online = false);
                            return;
                          }
                          if (await _confirm(
                                'Enable online maps?',
                                'OpenStreetMap tile servers receive your IP address and the regions you view. No map tiles are downloaded in bulk. Turn this off for offline-only use.',
                              ) &&
                              mounted) {
                            setState(() => _online = true);
                          }
                        },
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _busy || fix == null ? null : _download,
                            child: const Text('Save nearby area offline'),
                          ),
                          TextButton(
                            onPressed: area == null
                                ? null
                                : () => _centreArea(area),
                            child: const Text('View saved area'),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _import,
                            child: const Text('Import GeoJSON'),
                          ),
                          TextButton(
                            onPressed: _busy || area == null
                                ? null
                                : () => _run(() async {
                                    final file = await _file();
                                    if (await file.exists()) {
                                      await file.delete();
                                    }
                                    if (mounted) {
                                      setState(() {
                                        _area = null;
                                        _status = 'Saved area deleted.';
                                      });
                                    }
                                  }),
                            child: const Text('Delete saved map'),
                          ),
                          FilledButton(
                            onPressed: fix == null || c.connected == null
                                ? null
                                : () => _share(false),
                            child: const Text('Share my position'),
                          ),
                          FilledButton.tonal(
                            onPressed: fix == null || c.connected == null
                                ? null
                                : () => _share(true),
                            child: const Text('I need help — find me'),
                          ),
                        ],
                      ),
                      const Text(
                        'Offline area: basic roads, building outlines and landmarks, about 500 m around the saved position. No directions, traffic, damage reports or guaranteed coverage. Save before losing internet. Import supports GeoJSON Point, LineString and Polygon (5 MB maximum).',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
