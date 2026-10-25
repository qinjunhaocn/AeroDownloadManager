import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/engine/download_manager.dart';
import '../../state/app_state.dart';
import '../../core/models/app_settings.dart';
import '../../utils/constants.dart';
import '../../utils/haptics.dart';
import '../../utils/formatters.dart';
import '../widgets/text_input_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final settings = context.select<AppState, AppSettings>((s) => s.settings);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          _SectionCard(
            title: '外观',
            icon: Icons.palette_outlined,
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('系统'),
                    tooltip: '跟随系统',
                  ),
                  ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                ],
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  ),
                ),
                selected: {settings.themeMode},
                onSelectionChanged: (value) {
                  Haptics.select();
                  state.setThemeMode(value.first);
                },
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.monet,
                onChanged: (value) {
                  Haptics.select();
                  state.setMonet(value);
                },
                title: const Text('莫奈取色'),
                subtitle: const Text(
                  '使用系统壁纸/主题色生成 Material You 配色（Android 12+、Windows、Linux）',
                ),
              ),
              IgnorePointer(
                ignoring: settings.monet,
                child: AnimatedOpacity(
                  opacity: settings.monet ? 0.4 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in kSeedColors)
                        _ColorDot(
                          color: item.color,
                          name: item.name,
                          selected: settings.seedColor == item.color.toARGB32(),
                          onTap: () {
                            Haptics.select();
                            state.setSeedColor(item.color.toARGB32());
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (Platform.isAndroid)
            _SectionCard(
              title: '交互',
              icon: Icons.touch_app_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.haptics,
                  onChanged: (value) async {
                    Haptics.select();
                    await state.updateSettings(
                      settings.copyWith(haptics: value),
                    );
                    if (value) Haptics.tap();
                  },
                  title: const Text('触感反馈'),
                  subtitle: const Text('点击、选择、删除等操作时振动'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.predictiveBack,
                  onChanged: (value) async {
                    Haptics.select();
                    await state.updateSettings(
                      settings.copyWith(predictiveBack: value),
                    );
                  },
                  title: const Text('预测性返回手势'),
                  subtitle: const Text('Android 14+ 滑动返回时预览上一页；默认关闭'),
                ),
              ],
            ),
          _SectionCard(
            title: '下载',
            icon: Icons.download_outlined,
            children: [
              _SliderTile(
                title: '同时下载数量',
                subtitle: '队列中并行运行的任务数',
                value: settings.maxConcurrent.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                valueText: '${settings.maxConcurrent}',
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(maxConcurrent: value.round()),
                ),
              ),
              _SliderTile(
                title: '每站点并发上限',
                subtitle: '0 表示跟随「同时下载数量」',
                value: settings.maxConcurrentPerHost.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                valueText: settings.maxConcurrentPerHost == 0
                    ? '跟随全局'
                    : '${settings.maxConcurrentPerHost}',
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(maxConcurrentPerHost: value.round()),
                ),
              ),
              _SliderTile(
                title: '单任务线程数',
                subtitle: '默认连接/分段数量（1–32）',
                value: settings.threads.toDouble(),
                min: 1,
                max: 32,
                divisions: 31,
                valueText: '${settings.threads}',
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(threads: value.round()),
                ),
              ),
              _SliderTile(
                title: '最小分段大小',
                subtitle: '智能分段与均分时的下限',
                value: settings.minSegmentKB.toDouble(),
                min: 128,
                max: 4096,
                divisions: 31,
                valueText: formatBytes(settings.minSegmentKB * 1024),
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(minSegmentKB: value.round()),
                ),
              ),
              _SliderTile(
                title: '全局限速',
                subtitle: '0 表示不限速',
                value: settings.speedLimitKBps.toDouble(),
                min: 0,
                max: 20480,
                divisions: 160,
                valueText: settings.speedLimitKBps == 0
                    ? '不限速'
                    : formatSpeed(settings.speedLimitKBps * 1024),
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(speedLimitKBps: value.round()),
                ),
              ),
              const SizedBox(height: 6),
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
                  ButtonSegment(value: 0, label: Text('经典')),
                  ButtonSegment(value: 1, label: Text('智能')),
                ],
                selected: {settings.algorithm},
                onSelectionChanged: (value) {
                  Haptics.select();
                  state.updateSettings(
                    settings.copyWith(algorithm: value.first),
                  );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.preallocate,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(preallocate: value));
                },
                title: const Text('预分配磁盘空间'),
                subtitle: const Text('大文件多线程下载前预留空间'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.autoStart,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(autoStart: value));
                },
                title: const Text('启动后自动开始'),
                subtitle: const Text('打开应用时继续上次未完成的任务'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.autoRetry,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(autoRetry: value));
                },
                title: const Text('错误自动重试'),
                subtitle: const Text('连接中断后按退避时间自动重试'),
              ),
            ],
          ),
          _SectionCard(
            title: '连接',
            icon: Icons.lan_outlined,
            children: [
              _SliderTile(
                title: '连接超时',
                subtitle: '建立连接与等待响应的最长时间',
                value: settings.timeoutSec.toDouble(),
                min: 5,
                max: 60,
                divisions: 55,
                valueText: '${settings.timeoutSec} 秒',
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(timeoutSec: value.round()),
                ),
              ),
              _SliderTile(
                title: '最大重试次数',
                subtitle: '单条连接失败后的最大尝试次数',
                value: settings.maxRetries.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                valueText: '${settings.maxRetries}',
                onChanged: (value) => state.updateSettings(
                  settings.copyWith(maxRetries: value.round()),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('代理'),
                subtitle: Text(
                  settings.proxy.isEmpty ? '未设置（仅支持 HTTP 代理）' : settings.proxy,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editText(
                  context,
                  title: 'HTTP 代理',
                  hint: 'host:port',
                  initial: settings.proxy,
                  onSaved: (value) =>
                      state.updateSettings(settings.copyWith(proxy: value)),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('默认 User-Agent'),
                subtitle: Text(
                  settings.userAgent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editText(
                  context,
                  title: 'User-Agent',
                  hint: kDefaultUserAgent,
                  initial: settings.userAgent,
                  maxLines: 3,
                  onSaved: (value) => state.updateSettings(
                    settings.copyWith(
                      userAgent: value.isEmpty ? kDefaultUserAgent : value,
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.wifiOnly,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(wifiOnly: value));
                },
                title: const Text('仅 Wi-Fi 下载'),
                subtitle: const Text('移动网络下自动暂停，连接 Wi-Fi 后继续'),
              ),
            ],
          ),
          _SectionCard(
            title: '通知与行为',
            icon: Icons.notifications_outlined,
            children: [
              if (Platform.isAndroid)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.notifications,
                  onChanged: (value) => state.updateSettings(
                    settings.copyWith(notifications: value),
                  ),
                  title: const Text('显示下载通知'),
                  subtitle: const Text('在通知栏显示进度与完成提醒'),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.clipboardWatch,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(
                    settings.copyWith(clipboardWatch: value),
                  );
                },
                title: const Text('监听剪贴板链接'),
                subtitle: const Text('切换回应用时提示下载剪贴板中的链接'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.confirmDelete,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(confirmDelete: value));
                },
                title: const Text('删除前确认'),
              ),
            ],
          ),
          _SectionCard(
            title: '存储',
            icon: Icons.storage_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('默认下载目录'),
                subtitle: Text(
                  settings.downloadDir.isEmpty ? '未设置' : settings.downloadDir,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: '选择目录',
                      onPressed: () async {
                        final path = await FilePicker.getDirectoryPath(
                          dialogTitle: '选择默认下载目录',
                        );
                        if (path != null && path.isNotEmpty) {
                          await state.updateSettings(
                            settings.copyWith(downloadDir: path),
                          );
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded),
                    ),
                    IconButton(
                      tooltip: '恢复默认',
                      onPressed: () async {
                        Haptics.select();
                        final path =
                            await DownloadManager.platformDefaultDirectory();
                        await state.updateSettings(
                          settings.copyWith(downloadDir: path),
                        );
                      },
                      icon: const Icon(Icons.restore_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _SectionCard(
            title: '关于',
            icon: Icons.info_outline_rounded,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.downloading_rounded),
                title: Text('$kAppName $kAppVersion'),
                subtitle: const Text('多线程下载 · BitTorrent · 内置浏览器'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.code_rounded),
                title: const Text('GitHub 仓库'),
                subtitle: const Text(kRepoUrl),
                onTap: () {
                  Haptics.select();
                  launchUrl(Uri.parse(kRepoUrl));
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  '安全说明：为兼容 ADM 的下载行为，Aero 默认接受任意 TLS 证书（与 ADM 的 '
                  'TrustManager 行为一致）。请勿在不信任的网络中下载敏感内容。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _editText(
    BuildContext context, {
    required String title,
    required String hint,
    required String initial,
    required ValueChanged<String> onSaved,
    int maxLines = 1,
  }) async {
    Haptics.select();
    final result = await showAeroTextInputDialog(
      context,
      title: title,
      initial: initial,
      hint: hint,
      maxLines: maxLines,
    );
    if (result != null) onSaved(result);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
            const SizedBox(height: 10),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
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
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Text(
              valueText,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: (_) => Haptics.select(),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, size: 20, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
