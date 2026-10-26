import 'package:flutter/material.dart';

import '../../core/models/download_task.dart';
import '../../utils/file_types.dart';
import '../../utils/formatters.dart';
import '../../utils/haptics.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelect,
    required this.onMenuSelected,
  });

  final DownloadTask task;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;
  final void Function(String action) onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = task.category;
    final statusColor = _statusColor(scheme);
    final isActive = task.status.isActive;
    final showIndeterminate = isActive && task.total <= 0 && !task.isTorrent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      clipBehavior: Clip.antiAlias,
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerLow,
      child: InkWell(
        onTap: selectionMode ? onToggleSelect : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 2, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggleSelect(),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              _TypeAvatar(category: category, task: task),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!selectionMode) _menu(context),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: showIndeterminate ? null : task.progress,
                        minHeight: 4,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          task.total > 0
                              ? formatPercent(task.progress)
                              : (task.status == TaskStatus.completed
                                    ? '100%'
                                    : '—'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _metaLine(task),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if (task.status == TaskStatus.error &&
                        task.message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme scheme) {
    switch (task.status) {
      case TaskStatus.error:
        return scheme.error;
      case TaskStatus.completed:
        return scheme.tertiary;
      case TaskStatus.waiting:
      case TaskStatus.queued:
        return scheme.secondary;
      case TaskStatus.paused:
        return scheme.onSurfaceVariant;
      case TaskStatus.connecting:
      case TaskStatus.downloading:
        return scheme.primary;
    }
  }

  String _metaLine(DownloadTask task) {
    String base;
    if (task.isTorrent) {
      final size = task.total > 0 ? formatBytes(task.total) : '大小未知';
      base = '$size · ${task.peers} 节点 · ${task.seeders} 种子';
    } else if (task.total > 0) {
      final threads = task.segments.isEmpty ? 0 : task.segments.length;
      final suffix = threads > 1 ? ' · $threads 线程' : '';
      base =
          '${formatBytes(task.downloaded)} / ${formatBytes(task.total)}$suffix';
    } else {
      base = '${formatBytes(task.downloaded)} 已下载';
    }
    if (task.isActive && task.eta != null) {
      base += ' · 剩余 ${formatDuration(task.eta!.inMilliseconds)}';
    }
    return base;
  }

  Widget _menu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      consumeOutsideTap: false,
      style: const MenuStyle(alignment: Alignment.bottomRight),
      menuChildren: [
        MenuItemButton(
          onPressed: () {
            Haptics.select();
            onMenuSelected('details');
          },
          leadingIcon: const Icon(Icons.info_outline_rounded),
          child: const Text('详情'),
        ),
        MenuItemButton(
          onPressed: () {
            Haptics.select();
            onMenuSelected('open');
          },
          leadingIcon: const Icon(Icons.open_in_new_rounded),
          child: const Text('打开文件'),
        ),
        MenuItemButton(
          onPressed: () {
            Haptics.select();
            onMenuSelected('folder');
          },
          leadingIcon: const Icon(Icons.folder_open_rounded),
          child: const Text('打开所在文件夹'),
        ),
        MenuItemButton(
          onPressed: () {
            Haptics.select();
            onMenuSelected('copy');
          },
          leadingIcon: const Icon(Icons.link_rounded),
          child: const Text('复制链接'),
        ),
        if (task.status == TaskStatus.error)
          MenuItemButton(
            onPressed: () {
              Haptics.select();
              onMenuSelected('retry');
            },
            leadingIcon: const Icon(Icons.refresh_rounded),
            child: const Text('重试'),
          ),
        const Divider(height: 1),
        MenuItemButton(
          onPressed: () {
            Haptics.select();
            onMenuSelected('delete');
          },
          leadingIcon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          child: Text('删除', style: TextStyle(color: scheme.error)),
        ),
      ],
      builder: (context, controller, child) => IconButton(
        tooltip: '更多',
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        icon: const Icon(Icons.more_vert_rounded),
        onPressed: () {
          Haptics.select();
          controller.isOpen ? controller.close() : controller.open();
        },
      ),
    );
  }
}

class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar({required this.category, required this.task});

  final DownloadCategory category;
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = task.isTorrent ? scheme.tertiary : category.color;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        task.isTorrent
            ? Icons.hub_outlined
            : task.isActive
            ? Icons.downloading_rounded
            : category.icon,
        color: color,
        size: 20,
      ),
    );
  }
}
