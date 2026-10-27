import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../state/app_state.dart';
import 'settings_widgets.dart';
import '../../../utils/formatters.dart';
import '../../../utils/haptics.dart';

class DownloadSettingsPage extends StatelessWidget {
  const DownloadSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final settings = context.select<AppState, AppSettings>((s) => s.settings);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('下载')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          SettingsSectionCard(
            title: '下载',
            icon: Icons.download_outlined,
            children: [
              SettingsSliderTile(
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
              SettingsSliderTile(
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
              SettingsSliderTile(
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
              SettingsSliderTile(
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
              SettingsSliderTile(
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
        ],
      ),
    );
  }
}
