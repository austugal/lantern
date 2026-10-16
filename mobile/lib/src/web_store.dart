import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

const maxReadingPages = 20;
const maxReadingCharacters = 200000;
const maxReadingBytes = 1024 * 1024;
const maxReadingStoreBytes = 24 * 1024 * 1024;

/// Navigation guard, not a firewall: DNS and website subresources are handled
/// by the system WebView. Restrict addresses to public-style HTTPS hostnames.
Uri? publicWebUri(String input) {
  input = input.trim();
  if (input.isEmpty ||
      input.length > 4096 ||
      RegExp(r'[\s\\\x00-\x1f\x7f]').hasMatch(input)) {
    return null;
  }
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(input)) {
    input = 'https://$input';
  }
  final uri = Uri.tryParse(input);
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (!host.contains('.') ||
      InternetAddress.tryParse(host) != null ||
      !RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) {
    return null;
  }
  final labels = host.split('.');
  if (host.length > 253 ||
      labels.any(
        (label) =>
            label.isEmpty ||
            label.length > 63 ||
            !RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
      )) {
    return null;
  }
  if (!RegExp(r'^(?:[a-z]{2,63}|xn--[a-z0-9-]+)$').hasMatch(labels.last)) {
    return null;
  }
  if ([
    'localhost',
    'local',
    'lan',
    'internal',
    'home',
    'invalid',
    'test',
  ].contains(labels.last)) {
    return null;
  }
  return uri.replace(host: host);
}

class SavedWebPage {
  const SavedWebPage({
    required this.id,
    required this.url,
    required this.title,
    required this.text,
    required this.savedAt,
  });
  final String id, url, title, text;
  final DateTime savedAt;

  Map<String, Object> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'text': text,
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  factory SavedWebPage.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['url'] is! String ||
        value['title'] is! String ||
        value['text'] is! String ||
        value['savedAt'] is! String) {
      throw const FormatException('Saved page has invalid fields.');
    }
    final page = SavedWebPage(
      id: value['id'] as String,
      url: value['url'] as String,
      title: value['title'] as String,
      text: value['text'] as String,
      savedAt: DateTime.parse(value['savedAt'] as String),
    );
    page.validate();
    return page;
  }

  void validate() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) ||
        publicWebUri(url) == null ||
        title.length > 300 ||
        text.trim().isEmpty ||
        text.length > maxReadingCharacters ||
        utf8.encode(text).length > maxReadingBytes) {
      throw const FormatException(
        'Saved page is invalid or exceeds the reading limit.',
      );
    }
  }
}

/// A bounded, atomic JSON store. Invalid existing files are never overwritten
/// by add/delete: callers must explicitly clear a corrupted collection.
class WebReadingStore {
  WebReadingStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  Future<void> _writes = Future<void>.value();

  Future<File> _file() async {
    final root = await _directory();
    await root.create(recursive: true);
    return File('${root.path}/lantern-saved-reading-v1.json');
  }

  Future<List<SavedWebPage>> read() async {
    await _writes;
    return _readFile(await _file());
  }

  Future<List<SavedWebPage>> _readFile(File file) async {
    if (!await file.exists()) {
      return [];
    }
    if (await file.length() > maxReadingStoreBytes) {
      throw const FormatException('Saved reading file is too large.');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['pages'] is! List ||
        (decoded['pages'] as List).length > maxReadingPages) {
      throw const FormatException(
        'Saved reading file is corrupt or unsupported.',
      );
    }
    final pages = (decoded['pages'] as List)
        .map(SavedWebPage.fromJson)
        .toList();
    if (pages.map((page) => page.id).toSet().length != pages.length) {
      throw const FormatException(
        'Saved reading contains duplicate identifiers.',
      );
    }
    return pages;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> save(SavedWebPage page) => _serialize(() async {
    page.validate();
    final file = await _file();
    final pages = await _readFile(file);
    if (pages.any((existing) => existing.id == page.id)) {
      throw StateError('This saved-page identifier already exists.');
    }
    if (pages.length >= maxReadingPages) {
      throw StateError(
        'Saved reading is full. Delete a page before saving another.',
      );
    }
    await _write(file, [page, ...pages]);
  });

  Future<void> delete(String id) => _serialize(() async {
    final file = await _file();
    final pages = await _readFile(file);
    await _write(file, pages.where((page) => page.id != id).toList());
  });

  Future<void> clear() => _serialize(() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  });

  Future<void> _write(File file, List<SavedWebPage> pages) async {
    final encoded = utf8.encode(
      jsonEncode({
        'version': 1,
        'pages': pages.map((page) => page.toJson()).toList(),
      }),
    );
    if (encoded.length > maxReadingStoreBytes) {
      throw StateError('Saved reading exceeds its storage limit.');
    }
    final temp = File('${file.path}.pending');
    try {
      await temp.writeAsBytes(encoded, flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }
}
