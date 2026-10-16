import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'web_store.dart';

/// Shared by production browser and the native integration fixture.
Future<WebViewController> createReadingWebView() async {
  final web = WebViewController(
    onPermissionRequest: (request) => unawaited(request.deny()),
  );
  await web.setJavaScriptMode(JavaScriptMode.disabled);
  final platform = web.platform;
  if (platform is AndroidWebViewController) {
    await platform.setGeolocationEnabled(false);
    await platform.setAllowFileAccess(false);
    await platform.setAllowContentAccess(false);
    await platform.setGeolocationPermissionsPromptCallbacks(
      onShowPrompt: (_) async =>
          const GeolocationPermissionsResponse(allow: false, retain: false),
    );
  }
  return web;
}

/// Evaluates only this fixed read-only expression through the native engine.
/// Does not enable page scripts, register a JS bridge, or execute website text.
Future<Map<String, dynamic>> captureWebText(WebViewController web) async {
  final result = await web
      .runJavaScriptReturningResult(
        "JSON.stringify({url:location.href,title:document.title.slice(0,300),text:(document.body?document.body.innerText:'').slice(0,200000)})",
      )
      .timeout(const Duration(seconds: 5));
  Object? decoded = result;
  for (var i = 0; i < 2 && decoded is String; i++) {
    decoded = jsonDecode(decoded);
  }
  if (decoded is! Map<String, dynamic> ||
      decoded['url'] is! String ||
      decoded['title'] is! String ||
      decoded['text'] is! String) {
    throw const FormatException('Page text extraction is unavailable.');
  }
  return decoded;
}

/// Opens on saved reading. A WebView is created only after explicit online use.
class WebScreen extends StatefulWidget {
  const WebScreen({super.key, this.store});
  final WebReadingStore? store;
  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebReadingStore _store = widget.store ?? WebReadingStore();
  List<SavedWebPage> _pages = [];
  String _error = '';
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final pages = await _store.read();
      if (mounted) {
        setState(() {
          _pages = pages;
          _error = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Saved reading could not be opened. The file may be corrupt. It has not been overwritten.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _browse() async {
    final confirmed = await _confirm(
      context,
      'Browse online?',
      'Websites receive your requests and may store cookies. Internet is required. JavaScript is disabled; script-heavy sites, logins and live services may not work. Web camera, microphone and location are not enabled. No page is saved automatically.',
      'Open online browser',
    );
    if (confirmed && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _OnlineBrowser(store: _store)),
      );
      await _reload();
    }
  }

  Future<void> _delete(SavedWebPage page) async {
    if (!await _confirm(
      context,
      'Delete saved page?',
      'Remove this text snapshot from Lantern on this device.',
      'Delete',
    )) {
      return;
    }
    try {
      await _store.delete(page.id);
      await _reload();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not delete page: $e');
      }
    }
  }

  Future<void> _clear() async {
    if (!await _confirm(
      context,
      'Delete all saved reading?',
      'This also resets an unreadable saved-reading file. This cannot be undone.',
      'Delete all',
    )) {
      return;
    }
    try {
      await _store.clear();
      await _reload();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not delete saved reading: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Web & saved reading')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved text opens offline. No images, video, login sessions or working websites are saved.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _browse,
                      icon: const Icon(Icons.public),
                      label: const Text('Browse online'),
                    ),
                    TextButton(
                      onPressed: _clear,
                      child: const Text('Delete all saved reading'),
                    ),
                  ],
                ),
                if (_error.isNotEmpty) Text(_error),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _pages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No saved pages. Browse online, then explicitly save readable page text.',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: Text(
                          page.title.isEmpty ? 'Saved page' : page.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${Uri.parse(page.url).host} · ${page.savedAt.toLocal().toString().substring(0, 16)}',
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SavedReadingScreen(page: page),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete saved page',
                          onPressed: () => _delete(page),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

/// Plain Flutter text only: no WebView, HTML renderer or clickable URL.
class SavedReadingScreen extends StatelessWidget {
  const SavedReadingScreen({super.key, required this.page});
  final SavedWebPage page;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline saved text')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(page.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            SelectableText(page.url),
            Text(
              'Saved ${page.savedAt.toLocal()} · Snapshot may be incomplete or out of date.',
            ),
            const Divider(height: 32),
            SelectableText(
              page.text,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OnlineBrowser extends StatefulWidget {
  const _OnlineBrowser({required this.store});
  final WebReadingStore store;
  @override
  State<_OnlineBrowser> createState() => _OnlineBrowserState();
}

class _OnlineBrowserState extends State<_OnlineBrowser> {
  final _address = TextEditingController();
  WebViewController? _web;
  String _error = '', _loadedUrl = '';
  int _progress = 100;
  bool _busy = false, _configured = false, _pageReady = false;
  bool _clearingPage = false;

  @override
  void initState() {
    super.initState();
    unawaited(_configure());
  }

  Future<void> _configure() async {
    try {
      final web = await createReadingWebView();
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_clearingPage && request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            if (publicWebUri(request.url) == null) {
              if (mounted) {
                setState(
                  () => _error =
                      'Blocked navigation. Use a public HTTPS website address.',
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onProgress: (value) {
            if (mounted) {
              setState(() => _progress = value);
            }
          },
          onPageStarted: (url) {
            if (url == 'about:blank') {
              return;
            }
            if (mounted) {
              setState(() {
                _pageReady = false;
                _loadedUrl = url;
                _address.text = url;
              });
            }
          },
          onPageFinished: (url) {
            if (url == 'about:blank') {
              return;
            }
            if (mounted) {
              setState(() {
                _loadedUrl = url;
                _address.text = url;
                _pageReady = publicWebUri(url) != null;
              });
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _pageReady = false;
                _error =
                    'Page could not load. Check your internet connection or try another HTTPS website.';
              });
            }
          },
        ),
      );
      if (mounted) {
        setState(() {
          _web = web;
          _configured = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'System browser could not start: $e');
      }
    }
  }

  Future<void> _go() async {
    final uri = publicWebUri(_address.text);
    if (uri == null) {
      setState(
        () => _error =
            'Enter a public HTTPS hostname. Local addresses, IP literals, credentials and custom schemes are blocked.',
      );
      return;
    }
    try {
      setState(() {
        _error = '';
        _pageReady = false;
      });
      FocusScope.of(context).unfocus();
      await _web?.loadRequest(uri);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not open address: $e');
      }
    }
  }

  Future<void> _history(bool back) async {
    final web = _web;
    if (web == null) {
      return;
    }
    try {
      if (back ? await web.canGoBack() : await web.canGoForward()) {
        if (back) {
          await web.goBack();
        } else {
          await web.goForward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Navigation unavailable: $e');
      }
    }
  }

  Future<void> _save() async {
    final web = _web;
    if (web == null || !_pageReady || _busy) {
      return;
    }
    final confirmed = await _confirm(
      context,
      'Save readable text on this device?',
      'Saves visible page text and its address, up to 200,000 characters. This may contain personal information displayed by the website. Images, forms, videos and login sessions are not saved. Saved text is not additionally encrypted by Lantern.',
      'Save text',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final before = await web.currentUrl();
      if (before == null || publicWebUri(before) == null) {
        throw StateError('No public page is loaded.');
      }
      final decoded = await captureWebText(web);
      final after = await web.currentUrl();
      if (decoded['url'] != before || after != before) {
        throw StateError('Page changed or its text was unavailable.');
      }
      final page = SavedWebPage(
        id: 'p${DateTime.now().microsecondsSinceEpoch}',
        url: before,
        title: decoded['title'] as String,
        text: decoded['text'] as String,
        savedAt: DateTime.now(),
      );
      await widget.store.save(page);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Text saved. Open it from Saved reading without internet.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Page text was not saved: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _clearBrowserData() async {
    if (!await _confirm(
      context,
      'Clear browser data?',
      'Closes the current page and clears this WebView cache, website local storage and cookies. This can sign you out. Saved reading is kept; delete it separately.',
      'Clear browser data',
    )) {
      return;
    }
    try {
      _clearingPage = true;
      await _web?.loadHtmlString('<!doctype html><html><body></body></html>');
      if (mounted) {
        setState(() {
          _pageReady = false;
          _loadedUrl = '';
          _address.clear();
        });
      }
      await _web?.clearCache();
      await _web?.clearLocalStorage();
      await WebViewCookieManager().clearCookies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Browser cache, local storage and cookies cleared.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Some browser data could not be cleared: $e');
      }
    } finally {
      _clearingPage = false;
    }
  }

  @override
  void dispose() {
    // Replace the online document before releasing the native view.
    _clearingPage = true;
    unawaited(
      _web
          ?.loadHtmlString('<!doctype html><html><body></body></html>')
          .catchError((Object _) {}),
    );
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Online browser'),
      actions: [
        IconButton(
          tooltip: 'Clear browser cookies and cache',
          onPressed: _clearBrowserData,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _address,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'HTTPS website address',
                      hintText: 'https://example.com',
                    ),
                    onSubmitted: (_) => _go(),
                  ),
                ),
                IconButton(
                  tooltip: 'Open website online',
                  onPressed: _configured ? _go : null,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Online · website requests use internet. JavaScript disabled. Saving stores text only.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Back in browser',
                onPressed: _configured ? () => _history(true) : null,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: 'Forward in browser',
                onPressed: _configured ? () => _history(false) : null,
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: 'Reload online page',
                onPressed: _loadedUrl.isEmpty
                    ? null
                    : () async {
                        try {
                          await _web?.reload();
                        } catch (e) {
                          if (mounted) {
                            setState(() => _error = 'Reload failed: $e');
                          }
                        }
                      },
                icon: const Icon(Icons.refresh),
              ),
              TextButton.icon(
                onPressed: _pageReady && !_busy ? _save : null,
                icon: const Icon(Icons.download_outlined),
                label: Text(_busy ? 'Saving…' : 'Save text offline'),
              ),
            ],
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error, maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          Expanded(
            child: _web == null
                ? const Center(child: Text('Preparing system browser…'))
                : WebViewWidget(controller: _web!),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
