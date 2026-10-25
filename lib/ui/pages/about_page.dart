import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/constants.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.downloading_rounded,
                size: 52,
                color: scheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              kAppName,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Center(
            child: Text(
              '版本 $kAppVersion ($kAppBuild)',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              kAppTagline,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 26),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '功能',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  const _FeatureRow(
                    icon: Icons.multitrack_audio_rounded,
                    title: '多线程分段下载',
                    subtitle: '经典均分 / 智能动态分裂，支持断点续传与限速',
                  ),
                  const _FeatureRow(
                    icon: Icons.hub_outlined,
                    title: 'BitTorrent',
                    subtitle: '支持 .torrent、磁力链接（BEP 9 元数据）、DHT 与 UDP 追踪器',
                  ),
                  const _FeatureRow(
                    icon: Icons.travel_explore_rounded,
                    title: '内置浏览器',
                    subtitle: '网页下载拦截、Cookie/Referer 透传（Android/Windows）',
                  ),
                  const _FeatureRow(
                    icon: Icons.palette_outlined,
                    title: 'Material You',
                    subtitle: '莫奈取色、深浅色主题与多套种子配色',
                  ),
                  const _FeatureRow(
                    icon: Icons.share_outlined,
                    title: '系统集成',
                    subtitle: '分享链接、打开种子、前台服务通知、剪贴板监听',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('GitHub 仓库'),
              subtitle: const Text(kRepoUrl),
              onTap: () => launchUrl(Uri.parse(kRepoUrl)),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: scheme.errorContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: scheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '安全说明',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '为了与 ADM 保持一致，Aero 默认接受任意 TLS 证书，并允许明文 HTTP。'
                    '这意味着在不可信网络中可能存在中间人风险，请自行判断下载来源。'
                    '代理功能仅支持 HTTP 代理。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onErrorContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: kAppName,
              applicationVersion: '$kAppVersion ($kAppBuild)',
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('开源许可'),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Make downloads fast again.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
