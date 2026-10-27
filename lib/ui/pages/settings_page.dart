import 'package:flutter/material.dart';

import '../../utils/haptics.dart';
import 'about_page.dart';
import 'settings/appearance_settings_page.dart';
import 'settings/browser_settings_page.dart';
import 'settings/connection_settings_page.dart';
import 'settings/download_settings_page.dart';
import 'settings/notification_settings_page.dart';
import 'settings/storage_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: const [
          _SettingsGroup(
            title: '常规',
            entries: [
              _SettingsEntry(
                icon: Icons.palette_outlined,
                title: '外观',
                subtitle: '主题模式、莫奈取色与配色',
                page: AppearanceSettingsPage(),
              ),
              _SettingsEntry(
                icon: Icons.download_outlined,
                title: '下载',
                subtitle: '并发、线程、分段与限速',
                page: DownloadSettingsPage(),
              ),
              _SettingsEntry(
                icon: Icons.lan_outlined,
                title: '连接',
                subtitle: '超时、重试、代理与 User-Agent',
                page: ConnectionSettingsPage(),
              ),
            ],
          ),
          _SettingsGroup(
            title: '应用',
            entries: [
              _SettingsEntry(
                icon: Icons.notifications_outlined,
                title: '通知与交互',
                subtitle: '通知、剪贴板、触感反馈与返回手势',
                page: NotificationSettingsPage(),
              ),
              _SettingsEntry(
                icon: Icons.public_rounded,
                title: '浏览器',
                subtitle: '默认主页与搜索引擎',
                page: BrowserSettingsPage(),
              ),
              _SettingsEntry(
                icon: Icons.storage_outlined,
                title: '存储',
                subtitle: '默认下载目录',
                page: StorageSettingsPage(),
              ),
            ],
          ),
          _SettingsGroup(
            title: '其他',
            entries: [
              _SettingsEntry(
                icon: Icons.info_outline_rounded,
                title: '关于 Aero',
                subtitle: '版本信息、功能说明与 GitHub 仓库',
                page: AboutPage(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.entries});

  final String title;
  final List<_SettingsEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                entries[i],
                if (i != entries.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Haptics.select();
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
      },
    );
  }
}
