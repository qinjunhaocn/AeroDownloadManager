import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../utils/constants.dart';
import '../../utils/file_types.dart';
import '../../utils/formatters.dart';
import '../../utils/haptics.dart';
import '../pages/about_page.dart';

/// Side drawer shared by the Queue and Completed tabs.
///
/// Filtering is reduced to task types; the status buckets live in the bottom
/// NavigationBar now. The global speed is the prominent figure next to the app
/// name, since it is no longer shown on the download list itself.
class AeroDrawer extends StatelessWidget {
  const AeroDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      width: 300,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.downloading_rounded,
                      color: scheme.primary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kAppName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${app.manager.activeCount} 进行中 · '
                          '${app.manager.queuedCount} 排队',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onPrimaryContainer.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatSpeed(app.manager.totalSpeed),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '总速度',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                '按类型筛选',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    showCheckmark: false,
                    selected: app.categoryFilter == null,
                    onSelected: (_) {
                      Haptics.select();
                      app.setCategory(null);
                    },
                  ),
                  for (final category in DownloadCategory.values)
                    ChoiceChip(
                      label: Text(category.label),
                      avatar: Icon(category.icon, size: 16),
                      showCheckmark: false,
                      selected: app.categoryFilter == category,
                      onSelected: (_) {
                        Haptics.select();
                        app.setCategory(category);
                      },
                    ),
                ],
              ),
            ),
            const Divider(indent: 16, endIndent: 16, height: 24),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('关于 Aero'),
              onTap: () {
                Haptics.select();
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                );
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'v$kAppVersion · $kPackageName',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
