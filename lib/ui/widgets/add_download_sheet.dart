import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/engine/link_inspector.dart';
import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import '../../utils/search_engines.dart';
import '../pages/editor_page.dart';

Future<void> showAddDownloadSheet(
  BuildContext context, {
  String? initialUrl,
  String initialName = '',
  String userAgent = '',
  String referer = '',
  String cookie = '',
  bool forceDownload = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddDownloadSheet(
      initialUrl: initialUrl,
      initialName: initialName,
      userAgent: userAgent,
      referer: referer,
      cookie: cookie,
      forceDownload: forceDownload,
    ),
  );
}

class _AddDownloadSheet extends StatefulWidget {
  const _AddDownloadSheet({
    this.initialUrl,
    this.initialName = '',
    this.userAgent = '',
    this.referer = '',
    this.cookie = '',
    this.forceDownload = false,
  });

  final String? initialUrl;
  final String initialName;
  final String userAgent;
  final String referer;
  final String cookie;
  final bool forceDownload;

  @override
  State<_AddDownloadSheet> createState() => _AddDownloadSheetState();
}

class _AddDownloadSheetState extends State<_AddDownloadSheet> {
  late final TextEditingController _urlController;
  late final TextEditingController _nameController;
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
    _nameController = TextEditingController(text: widget.initialName);
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
    _nameController.dispose();
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
    final value = normalizeUrlInput(_urlController.text);
    if (value.isEmpty) return;
    Haptics.tap();
    final app = context.read<AppState>();
    Navigator.of(context).pop();
    app.openInBrowser(value);
  }

  void _selectAllName() {
    final text = _nameController.text;
    if (text.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
    });
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
      final value = normalizeUrlInput(_urlController.text);
      if (value.toLowerCase().startsWith('magnet:')) {
        await context.read<AppState>().manager.addMagnet(url: value);
      } else if (_linkKind == LinkKind.torrent) {
        await context.read<AppState>().manager.addTorrentUrl(url: value);
      } else {
        await context.read<AppState>().manager.addHttp(
          url: value,
          name: _nameController.text.trim(),
          userAgent: widget.userAgent,
          referer: widget.referer,
          cookie: widget.cookie,
        );
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

  void _advanced() {
    Haptics.select();
    final url = normalizeUrlInput(_urlController.text);
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
                  if (text.toLowerCase().startsWith('magnet:')) return null;
                  if (text.contains(RegExp(r'\s'))) {
                    return '请输入有效链接或域名';
                  }
                  final uri = Uri.tryParse(normalizeUrlInput(text));
                  if (uri == null ||
                      uri.host.isEmpty ||
                      (uri.scheme != 'http' && uri.scheme != 'https')) {
                    return '请输入有效链接或域名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                onTap: _selectAllName,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '文件名（可选）',
                  hintText: '留空则自动提取',
                  prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                ),
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
