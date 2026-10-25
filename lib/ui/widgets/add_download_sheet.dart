import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../utils/haptics.dart';
import '../pages/editor_page.dart';
import 'text_input_dialog.dart';

Future<void> showAddDownloadSheet(BuildContext context, {String? initialUrl}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddDownloadSheet(initialUrl: initialUrl),
  );
}

class _AddDownloadSheet extends StatefulWidget {
  const _AddDownloadSheet({this.initialUrl});

  final String? initialUrl;

  @override
  State<_AddDownloadSheet> createState() => _AddDownloadSheetState();
}

class _AddDownloadSheetState extends State<_AddDownloadSheet> {
  late final TextEditingController _urlController;
  final FocusNode _urlFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _urlFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocus.dispose();
    super.dispose();
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
                onFieldSubmitted: (_) => _start(),
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
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.download_rounded),
                label: Text(_busy ? '正在创建…' : '开始下载'),
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
