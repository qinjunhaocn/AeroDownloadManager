import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/download_task.dart';
import '../../state/app_state.dart';
import '../../utils/file_types.dart';
import '../../utils/formatters.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, this.initialUrl = '', this.task});

  final String initialUrl;
  final DownloadTask? task;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _name;
  late final TextEditingController _directory;
  late final TextEditingController _userAgent;
  late final TextEditingController _referer;
  late final TextEditingController _cookie;
  late final TextEditingController _authorization;
  late final TextEditingController _headers;
  late final TextEditingController _checksum;

  int _threads = 0;
  int _speedLimitKBps = 0;
  int _algorithm = -1;
  String _checksumType = 'md5';
  bool _startNow = true;
  bool _busy = false;

  bool get _isEditing => widget.task != null;
  DownloadTask? get _task => widget.task;

  @override
  void initState() {
    super.initState();
    final task = _task;
    _url = TextEditingController(text: task?.url ?? widget.initialUrl);
    _name = TextEditingController(text: task?.name ?? '');
    _directory = TextEditingController(
      text:
          task?.directory ?? context.read<AppState>().manager.defaultDirectory,
    );
    _userAgent = TextEditingController(text: task?.userAgent ?? '');
    _referer = TextEditingController(text: task?.referer ?? '');
    _cookie = TextEditingController(text: task?.cookie ?? '');
    _authorization = TextEditingController(text: task?.authorization ?? '');
    _headers = TextEditingController(text: task?.headers ?? '');
    _checksum = TextEditingController(text: task?.checksum ?? '');
    _threads = task?.threads ?? 0;
    _speedLimitKBps = ((task?.speedLimit ?? 0) / 1024).round();
    _algorithm = task?.algorithm ?? -1;
    _checksumType = task?.checksumType ?? 'md5';
    _startNow = task == null;
  }

  @override
  void dispose() {
    for (final controller in [
      _url,
      _name,
      _directory,
      _userAgent,
      _referer,
      _cookie,
      _authorization,
      _headers,
      _checksum,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    try {
      final path = await FilePicker.getDirectoryPath(dialogTitle: '选择下载目录');
      if (path != null && path.isNotEmpty) {
        _directory.text = path;
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    try {
      final url = _url.text.trim();
      final directory = _directory.text.trim();
      final name = _name.text.trim();
      if (_isEditing) {
        final task = _task!;
        final urlChanged = task.url != url;
        final oldName = task.name;
        final oldDirectory = task.directory;
        task.url = url;
        task.name = name.isEmpty ? task.name : sanitizeFileName(name);
        if (directory.isNotEmpty) task.directory = directory;
        final locationChanged =
            oldName != task.name || oldDirectory != task.directory;
        task.threads = _threads;
        task.speedLimit = _speedLimitKBps * 1024;
        task.algorithm = _algorithm;
        task.userAgent = _userAgent.text.trim();
        task.referer = _referer.text.trim();
        task.cookie = _cookie.text.trim();
        task.authorization = _authorization.text.trim();
        task.headers = _headers.text.trim();
        task.checksum = _checksum.text.trim();
        task.checksumType = _checksumType;
        if (urlChanged || locationChanged) {
          task.segments.clear();
          task.downloaded = 0;
          task.total = 0;
          task.noRange = false;
          task.restartCount = 0;
          task.filePath = '';
          task.status = TaskStatus.paused;
          task.message = '链接或保存位置已修改，等待重新下载';
        }
        app.manager.saveNow();
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('任务已更新')));
      } else {
        await app.manager.addHttp(
          url: url,
          name: name,
          directory: directory,
          threads: _threads,
          speedLimit: _speedLimitKBps * 1024,
          algorithm: _algorithm,
          userAgent: _userAgent.text.trim(),
          referer: _referer.text.trim(),
          cookie: _cookie.text.trim(),
          authorization: _authorization.text.trim(),
          headers: _headers.text.trim(),
          checksum: _checksum.text.trim(),
          checksumType: _checksumType,
          startNow: _startNow,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_startNow ? '已开始下载' : '已加入任务列表')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppState>().settings;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑任务' : '新建下载'),
        actions: [
          IconButton(
            tooltip: '保存',
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Section(
              title: '链接',
              icon: Icons.link_rounded,
              children: [
                TextFormField(
                  controller: _url,
                  minLines: 2,
                  maxLines: 4,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '下载地址',
                    hintText: 'https://example.com/file.zip',
                    prefixIcon: Icon(Icons.public_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请输入下载地址';
                    final uri = Uri.tryParse(text);
                    if (uri == null ||
                        !uri.hasScheme ||
                        (uri.scheme != 'http' && uri.scheme != 'https')) {
                      return '仅支持 http(s) 链接';
                    }
                    return null;
                  },
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 10),
                  Text(
                    '修改链接会清空已下载的分段进度。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: '保存',
              icon: Icons.folder_outlined,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: '文件名（留空自动识别）',
                    prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _directory,
                        decoration: const InputDecoration(
                          labelText: '保存目录',
                          prefixIcon: Icon(Icons.folder_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '选择目录',
                      onPressed: _pickDirectory,
                      icon: const Icon(Icons.folder_open_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '默认目录：${shortPath(settings.downloadDir, max: 54)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: '连接',
              icon: Icons.tune_rounded,
              children: [
                _LabeledSlider(
                  label: '线程数',
                  value: _threads.toDouble(),
                  min: 0,
                  max: 32,
                  divisions: 32,
                  valueText: _threads == 0
                      ? '默认 (${settings.threads})'
                      : '$_threads',
                  onChanged: (value) =>
                      setState(() => _threads = value.round()),
                ),
                _LabeledSlider(
                  label: '限速',
                  value: _speedLimitKBps.toDouble(),
                  min: 0,
                  max: 20480,
                  divisions: 160,
                  valueText: _speedLimitKBps == 0
                      ? '不限速'
                      : formatSpeed(_speedLimitKBps * 1024),
                  onChanged: (value) =>
                      setState(() => _speedLimitKBps = value.round()),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '多线程模式',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: -1, label: Text('默认')),
                    ButtonSegment(value: 0, label: Text('经典')),
                    ButtonSegment(value: 1, label: Text('智能')),
                  ],
                  selected: {_algorithm},
                  onSelectionChanged: (value) =>
                      setState(() => _algorithm = value.first),
                ),
                const SizedBox(height: 8),
                Text(
                  '经典：探测后一次性均分；智能：运行中按剩余量动态分裂。',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: '请求',
              icon: Icons.http_rounded,
              children: [
                TextFormField(
                  controller: _userAgent,
                  decoration: const InputDecoration(
                    labelText: 'User-Agent（留空使用默认）',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referer,
                  decoration: const InputDecoration(
                    labelText: 'Referer',
                    prefixIcon: Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cookie,
                  decoration: const InputDecoration(
                    labelText: 'Cookie',
                    prefixIcon: Icon(Icons.cookie_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _authorization,
                  decoration: const InputDecoration(
                    labelText: 'Authorization（如 Bearer xxx / Basic xxx）',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _headers,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '自定义请求头（每行 Name: value）',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.list_alt_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: '校验（可选）',
              icon: Icons.verified_outlined,
              children: [
                Row(
                  children: [
                    DropdownButton<String>(
                      value: _checksumType,
                      items: const [
                        DropdownMenuItem(value: 'md5', child: Text('MD5')),
                        DropdownMenuItem(value: 'sha1', child: Text('SHA-1')),
                        DropdownMenuItem(
                          value: 'sha256',
                          child: Text('SHA-256'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _checksumType = value ?? 'md5'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _checksum,
                        decoration: const InputDecoration(
                          labelText: '摘要值',
                          hintText: '下载完成后校验',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_isEditing)
              SwitchListTile(
                value: _startNow,
                onChanged: (value) => setState(() => _startNow = value),
                title: const Text('保存后立即开始'),
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.download_rounded),
              label: Text(_isEditing ? '保存修改' : (_startNow ? '开始下载' : '加入列表')),
            ),
            const SizedBox(height: 8),
            Text(
              '提示：Aero 与 ADM 一样使用 HTTP Range 分段下载；'
              '若服务器不支持多线程，会自动降级为单连接。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueText;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              valueText,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
