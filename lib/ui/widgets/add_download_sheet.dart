import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/engine/link_inspector.dart';
import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import '../pages/browser_page.dart';
import '../pages/editor_page.dart';
import 'text_input_dialog.dart';

Future<void> showAddDownloadSheet(
  BuildContext context, {
  String? initialUrl,
  bool forceDownload = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _AddDownloadSheet(initialUrl: initialUrl, forceDownload: forceDownload),
  );
}

class _AddDownloadSheet extends StatefulWidget {
  const _AddDownloadSheet({this.initialUrl, this.forceDownload = false});

  final String? initialUrl;
  final bool forceDownload;

  @override
  State<_AddDownloadSheet> createState() => _AddDownloadSheetState();
}

class _AddDownloadSheetState extends State<_AddDownloadSheet> {
  late final TextEditingController _urlController;
  final FocusNode _urlFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  bool _checking = false;
  LinkKind? _linkKind;
  String? _inspectionMessage;
  Timer? _inspectDebounce;
  int _inspectSeq = 0;
  String _lastUrlText = '';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _lastUrlText = _urlController.text;
    if (widget.forceDownload) {
      _linkKind = LinkKind.download;
    }
    _urlController.addListener(_onUrlChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _urlFocus.requestFocus();
      if (!widget.forceDownload) {
        _scheduleInspect(_urlController.text);
      }
    });
  }

  @override
  void dispose() {
    _inspectDebounce?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final text = _urlController.text;
    // TextEditingController also notifies for selection/cursor changes.
    if (text == _lastUrlText) return;
    _lastUrlText = text;
    _scheduleInspect(text);
  }

  void _scheduleInspect(String value) {
    _inspectDebounce?.cancel();
    final seq = ++_inspectSeq;
    final text = value.trim();
    if (!mounted) return;
    if (text.isEmpty) {
      setState(() {
        _checking = false;
        _linkKind = null;
        _inspectionMessage = null;
      });
      return;
    }
    setState(() {
      _checking = true;
      _linkKind = null;
      _inspectionMessage = null;
    });
    _inspectDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      final settings = context.read<AppState>().settings;
      final result = await LinkInspector.inspect(
        text,
        userAgent: settings.userAgent,
        proxy: settings.proxy,
      );
      if (!mounted || seq != _inspectSeq) return;
      setState(() {
        _checking = false;
        _linkKind = result.kind;
        _inspectionMessage = result.message;
      });
    });
  }

  bool get _isBrowserLink => !_checking && _linkKind == LinkKind.browser;

  void _primaryAction() {
    if (_busy || _checking) return;
    if (_isBrowserLink) {
      _openInBrowser();
      return;
    }
    _start();
  }

  void _openInBrowser() {
    final value = _urlController.text.trim();
    if (value.isEmpty) return;
    Haptics.tap();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => BrowserPage(initialUrl: value)),
    );
  }

  Future<void> _paste() async {
    Haptics.select();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _urlController.text = text;
    _urlController.selection = TextSelection.collapsed(
      offset: _urlController.text.length,
    );
  }

  Future<void> _start() async {
    if (_busy) return;
    Haptics.tap();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final value = _urlController.text.trim();
      if (value.toLowerCase().startsWith('magnet:')) {
        await context.read<AppState>().manager.addMagnet(url: value);
      } else if (_linkKind == LinkKind.torrent) {
        await context.read<AppState>().manager.addTorrentUrl(url: value);
      } else {
        await context.read<AppState>().manager.addHttp(url: value);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已加入下载队列')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTorrent() async {
    Haptics.tap();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['torrent'],
    );
    final path = result.isEmpty ? null : result.first.path;
    if (path == null) return;
    if (!mounted) return;
    try {
      await context.read<AppState>().manager.addTorrentFile(path: path);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('种子任务已加入')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _addMagnet() async {
    Haptics.tap();
    final value = await showAeroTextInputDialog(
      context,
      title: '添加磁力链接',
      hint: 'magnet:?xt=urn:btih:…',
      maxLines: 6,
      confirmLabel: '添加',
    );
    if (value == null || value.isEmpty) return;
    if (!mounted) return;
    try {
      await context.read<AppState>().manager.addMagnet(url: value);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('磁力任务已加入，正在获取元数据')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _advanced() {
    Haptics.select();
    final url = _urlController.text.trim();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => EditorPage(initialUrl: url)),
    );
  }

  Widget _inspectionWidget(ColorScheme scheme) {
    if (_checking) {
      return Row(
        key: const ValueKey('checking'),
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            '正在检测链接类型…',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }
    final message = _inspectionMessage;
    if (message == null) return const SizedBox.shrink();
    final icon = switch (_linkKind) {
      LinkKind.browser => Icons.public_rounded,
      LinkKind.download => Icons.download_done_rounded,
      LinkKind.torrent => Icons.hub_outlined,
      _ => Icons.help_outline_rounded,
    };
    final color = _linkKind == LinkKind.browser
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return Row(
      key: ValueKey(message),
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.add_link_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    '新建下载',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                focusNode: _urlFocus,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _primaryAction(),
                decoration: InputDecoration(
                  hintText: '粘贴 http(s) 链接或 magnet 链接',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: IconButton(
                    tooltip: '粘贴',
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste_rounded),
                  ),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return '请输入链接';
                  final lower = text.toLowerCase();
                  if (!lower.startsWith('http://') &&
                      !lower.startsWith('https://') &&
                      !lower.startsWith('magnet:')) {
                    return '仅支持 http(s) 或 magnet 链接';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _inspectionWidget(scheme),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy || _checking
                    ? null
                    : (_isBrowserLink ? _openInBrowser : _start),
                icon: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isBrowserLink
                            ? Icons.public_rounded
                            : Icons.download_rounded,
                      ),
                label: Text(
                  _busy
                      ? '正在创建…'
                      : _checking
                      ? '正在检测链接…'
                      : _isBrowserLink
                      ? '在浏览器打开'
                      : _linkKind == LinkKind.torrent
                      ? '添加种子任务'
                      : '开始下载',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _advanced,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('高级选项'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTorrent,
                      icon: const Icon(Icons.file_present_rounded),
                      label: const Text('种子文件'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addMagnet,
                icon: const Icon(Icons.hub_outlined),
                label: const Text('粘贴磁力链接'),
              ),
              const SizedBox(height: 6),
              Text(
                '提示：下载会保存在默认目录，可在设置或高级选项中修改。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
