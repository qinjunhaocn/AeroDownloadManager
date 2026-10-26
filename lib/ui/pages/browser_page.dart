import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import '../../utils/search_engines.dart';
import '../widgets/add_download_sheet.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, this.initialUrl, this.active = true});

  final String? initialUrl;

  /// Whether the browser tab is the visible tab. Only the active browser may
  /// intercept the system back gesture.
  final bool active;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  static bool get _webViewSupported => Platform.isAndroid || Platform.isWindows;

  late final TextEditingController _urlController;
  final FocusNode _urlFocus = FocusNode();
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = false;
  String _currentUrl = '';
  bool _hasUrl = false;
  bool _creatingWebView = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _pendingUrl = '';
  AppState? _app;
  String _homeUrl = '';

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final initial = widget.initialUrl?.trim() ?? '';
    final configuredHome = app.settings.browserHome.trim();
    _homeUrl = configuredHome;
    final target = initial.isNotEmpty
        ? initial
        : (configuredHome.isNotEmpty ? configuredHome : 'https://www.bing.com');
    final normalized = normalizeUrlInput(target);
    _urlController = TextEditingController(text: normalized);
    _pendingUrl = normalized;
    _currentUrl = normalized;
    _loading = normalized.isNotEmpty;
    _creatingWebView = normalized.isNotEmpty;
    _urlFocus.addListener(() {
      if (_urlFocus.hasFocus) {
        // Let the text field apply its own cursor placement first, then select
        // the whole address (desktop browser behaviour).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _urlFocus.hasFocus) _selectAllUrl();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_creatingWebView) {
        setState(() {
          _hasUrl = true;
          _creatingWebView = false;
        });
      }
      final requested = _app?.takePendingBrowserUrl();
      if (requested != null) _openRequested(requested);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    if (!identical(_app, app)) {
      _app?.removeListener(_onAppStateChanged);
      _app = app;
      app.addListener(_onAppStateChanged);
    }
  }

  void _onAppStateChanged() {
    final app = _app;
    if (app == null) return;
    final home = app.settings.browserHome.trim();
    if (home.isNotEmpty && home != _homeUrl) {
      _homeUrl = home;
      // Applying a new default page from Settings updates the preloaded tab
      // while it is in the background; don't interrupt an active page.
      if (!widget.active) {
        _openRequested(home);
      }
    }
    final url = app.takePendingBrowserUrl();
    if (url == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openRequested(url);
    });
  }

  /// Tapping the address bar selects everything, matching desktop browsers.
  void _selectAllUrl() {
    final text = _urlController.text;
    if (text.isEmpty) return;
    _urlController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  @override
  void dispose() {
    _app?.removeListener(_onAppStateChanged);
    _urlFocus.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool _looksLikeUrl(String value) {
    if (value.contains(RegExp(r'\s'))) return false;
    final candidate = Uri.tryParse('https://$value');
    if (candidate == null || candidate.host.isEmpty) return false;
    final host = candidate.host;
    if (host == 'localhost') return true;
    if (InternetAddress.tryParse(host) != null) return true;
    return host.contains('.');
  }

  String _resolveInput(String input) {
    final value = input.trim();
    if (value.isEmpty) return '';
    if (value.contains('://')) return value;
    if (_looksLikeUrl(value)) return normalizeUrlInput(value);
    final engine = context.read<AppState>().settings.searchEngine;
    return SearchEngines.searchUrl(engine, value);
  }

  Future<void> _go(String input, {bool haptic = true}) async {
    final url = _resolveInput(input);
    if (url.isEmpty) return;
    if (haptic) Haptics.select();
    _urlController.text = url;
    _urlController.selection = TextSelection.collapsed(offset: url.length);
    if (!_webViewSupported) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    if (!_hasUrl) {
      if (_creatingWebView) return;
      _creatingWebView = true;
      setState(() {
        _pendingUrl = url;
        _currentUrl = url;
        _loading = true;
        _progress = 0;
      });
      // Let the loading state paint before the platform WebView is created;
      // creating it synchronously on the tap frame is what made the first
      // navigation feel like a freeze.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hasUrl = true;
          _creatingWebView = false;
        });
      });
      return;
    }
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _openRequested(String url) {
    final normalized = normalizeUrlInput(url);
    if (normalized.isEmpty) return;
    _urlController.text = normalized;
    _currentUrl = normalized;
    final controller = _controller;
    if (controller != null && _hasUrl) {
      controller.loadUrl(urlRequest: URLRequest(url: WebUri(normalized)));
      return;
    }
    setState(() {
      _pendingUrl = normalized;
      _currentUrl = normalized;
      _hasUrl = true;
      _loading = true;
      _progress = 0;
      _creatingWebView = false;
    });
  }

  Future<void> _goHome() async {
    Haptics.select();
    final home = context.read<AppState>().settings.browserHome.trim();
    await _go(home.isEmpty ? 'https://www.bing.com' : home, haptic: false);
  }

  Future<void> _refreshHistoryState() async {
    final controller = _controller;
    var back = false;
    var forward = false;
    if (controller != null) {
      try {
        back = await controller.canGoBack();
        forward = await controller.canGoForward();
      } catch (_) {
        // WebView may be tearing down; treat as no history.
      }
    }
    if (!mounted) return;
    if (back != _canGoBack || forward != _canGoForward) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
  }

  Future<void> _goBack() async {
    if (!_canGoBack) return;
    Haptics.select();
    await _controller?.goBack();
    await _refreshHistoryState();
  }

  Future<void> _goForward() async {
    if (!_canGoForward) return;
    Haptics.select();
    await _controller?.goForward();
    await _refreshHistoryState();
  }

  Future<void> _reload() async {
    if (!_hasUrl) return;
    Haptics.select();
    await _controller?.reload();
  }

  Future<void> _openExternal() async {
    Haptics.select();
    final value = _currentUrl.isNotEmpty
        ? _currentUrl
        : _resolveInput(_urlController.text);
    if (value.isEmpty) return;
    await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
  }

  void _clearAddress() {
    Haptics.select();
    _urlController.clear();
  }

  Future<void> _currentPageUrl() async {
    if (!_webViewSupported) return;
    final controller = _controller;
    if (controller == null) return;
    final url = await controller.getUrl();
    if (url != null) _currentUrl = url.toString();
  }

  Future<void> _addCurrentPage() async {
    Haptics.tap();
    await _currentPageUrl();
    if (!mounted) return;
    final url = _currentUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先打开一个网页')));
      return;
    }
    await showAddDownloadSheet(context, initialUrl: url, forceDownload: true);
  }

  Future<void> _handleDownload(DownloadStartRequest request) async {
    final url = request.url.toString();
    if (url.isEmpty) return;
    String cookie = '';
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(url),
      );
      cookie = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    // Browser-initiated downloads should be reviewed in the Queue tab instead
    // of being added silently.
    context.read<AppState>().requestTab(0);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await showAddDownloadSheet(
      context,
      initialUrl: url,
      initialName: request.suggestedFilename ?? '',
      userAgent: request.userAgent ?? '',
      referer: _currentUrl,
      cookie: cookie,
      forceDownload: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final interceptBack = widget.active && _canGoBack;
    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.active && _canGoBack) {
          _goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocus,
                    textInputAction: TextInputAction.go,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '输入网址',
                    ),
                    onSubmitted: _go,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: '打开',
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: () => _go(_urlController.text),
            ),
            MenuAnchor(
              consumeOutsideTap: false,
              style: const MenuStyle(alignment: Alignment.bottomRight),
              menuChildren: [
                MenuItemButton(
                  onPressed: _goHome,
                  leadingIcon: const Icon(Icons.home_outlined),
                  child: const Text('主页'),
                ),
                const Divider(height: 1),
                MenuItemButton(
                  onPressed: _canGoBack ? _goBack : null,
                  leadingIcon: const Icon(Icons.arrow_back_rounded),
                  child: const Text('后退'),
                ),
                MenuItemButton(
                  onPressed: _canGoForward ? _goForward : null,
                  leadingIcon: const Icon(Icons.arrow_forward_rounded),
                  child: const Text('前进'),
                ),
                MenuItemButton(
                  onPressed: _hasUrl ? _reload : null,
                  leadingIcon: const Icon(Icons.refresh_rounded),
                  child: const Text('刷新'),
                ),
                const Divider(height: 1),
                MenuItemButton(
                  onPressed: _addCurrentPage,
                  leadingIcon: const Icon(Icons.download_rounded),
                  child: const Text('下载此页'),
                ),
                MenuItemButton(
                  onPressed: _openExternal,
                  leadingIcon: const Icon(Icons.open_in_browser_rounded),
                  child: const Text('用系统浏览器打开'),
                ),
                MenuItemButton(
                  onPressed: _clearAddress,
                  leadingIcon: const Icon(Icons.clear_rounded),
                  child: const Text('清空地址栏'),
                ),
              ],
              builder: (context, controller, child) => IconButton(
                tooltip: '更多',
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () {
                  Haptics.select();
                  controller.isOpen ? controller.close() : controller.open();
                },
              ),
            ),
          ],
          bottom: _loading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress <= 0 ? null : _progress,
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: _webViewSupported
            ? (_hasUrl
                  ? InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(_pendingUrl)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        supportZoom: true,
                        mediaPlaybackRequiresUserGesture: false,
                        useHybridComposition: true,
                        transparentBackground: false,
                        allowFileAccess: false,
                        allowContentAccess: false,
                      ),
                      onWebViewCreated: (controller) {
                        _controller = controller;
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          _loading = true;
                          _progress = 0;
                          if (url != null) {
                            _currentUrl = url.toString();
                            _urlController.text = _currentUrl;
                          }
                        });
                      },
                      onProgressChanged: (controller, progress) {
                        setState(() {
                          _progress = progress / 100;
                          _loading = progress < 100;
                        });
                      },
                      onLoadStop: (controller, url) async {
                        setState(() => _loading = false);
                        if (url != null) {
                          _currentUrl = url.toString();
                          _urlController.text = _currentUrl;
                        }
                        await _refreshHistoryState();
                      },
                      onUpdateVisitedHistory: (controller, url, isReload) {
                        _refreshHistoryState();
                      },
                      onDownloadStartRequest: (controller, request) {
                        _handleDownload(request);
                      },
                    )
                  : (_loading
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : const SizedBox.expand()))
            : _DesktopFallback(
                urlController: _urlController,
                onGo: _go,
                onAddDownload: () => showAddDownloadSheet(
                  context,
                  initialUrl: _urlController.text,
                ),
              ),
      ),
    );
  }
}

class _DesktopFallback extends StatelessWidget {
  const _DesktopFallback({
    required this.urlController,
    required this.onGo,
    required this.onAddDownload,
  });

  final TextEditingController urlController;
  final Future<void> Function(String) onGo;
  final VoidCallback onAddDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 72,
                color: scheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'Linux 内置浏览器',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Linux 版暂未集成 WebView 组件。你仍可以使用系统浏览器打开网页，'
                '或直接把地址加入 Aero 下载。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => onGo(urlController.text),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('用系统浏览器打开'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onAddDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('下载此链接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
