import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/download_task.dart';
import '../../core/platform/file_opener.dart';
import '../../state/app_state.dart';
import '../../utils/constants.dart';
import '../../utils/file_types.dart';
import '../../utils/formatters.dart';
import '../widgets/add_download_sheet.dart';
import '../widgets/task_tile.dart';
import 'about_page.dart';
import 'browser_page.dart';
import 'editor_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  AppState? _app;
  bool _handlingIncoming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    if (!identical(_app, app)) {
      _app?.removeListener(_onAppChanged);
      _app = app;
      _app!.addListener(_onAppChanged);
      _onAppChanged();
    }
  }

  void _onAppChanged() {
    if (!mounted) return;
    final url = _app?.takeIncomingUrl();
    if (url == null || _handlingIncoming) return;
    _handlingIncoming = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _handlingIncoming = false;
        return;
      }
      await showAddDownloadSheet(context, initialUrl: url);
      _handlingIncoming = false;
      _onAppChanged();
    });
  }

  @override
  void dispose() {
    _app?.removeListener(_onAppChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final manager = app.manager;
    return Scaffold(
      appBar: _buildAppBar(app),
      drawer: _buildDrawer(app),
      body: Column(
        children: [
          if (app.clipboardUrl != null) _clipboardBanner(app),
          if (manager.activeCount > 0) _summaryCard(app),
          Expanded(child: _buildTaskList(app)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddDownloadSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建'),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BarAction(
              icon: Icons.play_arrow_rounded,
              label: '全部开始',
              onTap: manager.startAll,
            ),
            _BarAction(
              icon: Icons.pause_rounded,
              label: '全部暂停',
              onTap: () => manager.pauseAll(),
            ),
            _BarAction(
              icon: Icons.public_rounded,
              label: '浏览器',
              onTap: () => _openBrowser(app),
            ),
            _BarAction(
              icon: Icons.settings_outlined,
              label: '设置',
              onTap: () => _openSettings(app),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // App bar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(AppState app) {
    if (app.selectionMode) {
      return AppBar(
        leading: IconButton(
          tooltip: '取消选择',
          icon: const Icon(Icons.close_rounded),
          onPressed: app.clearSelection,
        ),
        title: Text('已选择 ${app.selectedIds.length} 项'),
        actions: [
          IconButton(
            tooltip: '全选',
            onPressed: app.selectAll,
            icon: const Icon(Icons.select_all_rounded),
          ),
          IconButton(
            tooltip: '开始',
            onPressed: () {
              for (final task in app.selectedTasks) {
                if (task.status != TaskStatus.completed) {
                  app.manager.start(task);
                }
              }
              app.clearSelection();
            },
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: '暂停',
            onPressed: () async {
              for (final task in app.selectedTasks) {
                if (task.status.isActive) await app.manager.pause(task);
              }
              app.clearSelection();
            },
            icon: const Icon(Icons.pause_rounded),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () async {
              final selected = app.selectedTasks;
              if (selected.isEmpty) return;
              final confirmed = await _confirmDeleteMany(selected);
              if (!confirmed) return;
              for (final task in selected) {
                await app.manager.remove(task, deleteFile: true);
              }
              app.clearSelection();
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      );
    }

    if (_searching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            setState(() => _searching = false);
            _searchController.clear();
            app.setSearch('');
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索任务名称或链接',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: app.setSearch,
        ),
        actions: [
          if (app.searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                app.setSearch('');
              },
            ),
        ],
      );
    }

    final manager = app.manager;
    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: '菜单',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(kAppName),
          Text(
            manager.activeCount > 0
                ? '${manager.activeCount} 个进行中 · ${formatSpeed(manager.totalSpeed)}'
                : '${manager.tasks.length} 个任务 · ${formatBytes(manager.tasks.fold<int>(0, (sum, t) => sum + t.downloaded))}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: '搜索',
          onPressed: () => setState(() => _searching = true),
          icon: const Icon(Icons.search_rounded),
        ),
        PopupMenuButton<TaskSort>(
          tooltip: '排序',
          icon: const Icon(Icons.sort_rounded),
          initialValue: app.sort,
          onSelected: app.setSort,
          itemBuilder: (context) => [
            _sortItem(app, TaskSort.newest, '最新优先'),
            _sortItem(app, TaskSort.oldest, '最早优先'),
            _sortItem(app, TaskSort.name, '按名称'),
            _sortItem(app, TaskSort.size, '按大小'),
            _sortItem(app, TaskSort.progress, '按进度'),
          ],
        ),
        PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) => _onOverflow(app, value),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'browser', child: Text('内置浏览器')),
            PopupMenuItem(value: 'settings', child: Text('设置')),
            PopupMenuItem(value: 'clear', child: Text('清除已完成')),
            PopupMenuItem(value: 'about', child: Text('关于 Aero')),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<TaskSort> _sortItem(
    AppState app,
    TaskSort value,
    String label,
  ) {
    final selected = app.sort == value;
    return PopupMenuItem<TaskSort>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_rounded : Icons.remove_rounded,
            size: 18,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _onOverflow(AppState app, String value) async {
    switch (value) {
      case 'browser':
        _openBrowser(app);
        break;
      case 'settings':
        _openSettings(app);
        break;
      case 'clear':
        await app.manager.clearCompleted();
        break;
      case 'about':
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
        break;
    }
  }

  void _openBrowser(AppState app) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowserPage(initialUrl: app.settings.browserHome),
      ),
    );
  }

  void _openSettings(AppState app) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  // ---------------------------------------------------------------------------
  // Drawer
  // ---------------------------------------------------------------------------

  Widget _buildDrawer(AppState app) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      width: 300,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.downloading_rounded,
                          color: scheme.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        kAppName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${formatSpeed(app.manager.totalSpeed)} · '
                    '${app.manager.activeCount} 进行中 / ${app.manager.queuedCount} 排队',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            _drawerItem(
              app,
              icon: Icons.all_inbox_rounded,
              label: '全部任务',
              filter: TaskFilter.all,
            ),
            _drawerItem(
              app,
              icon: Icons.downloading_rounded,
              label: '正在下载',
              filter: TaskFilter.active,
            ),
            _drawerItem(
              app,
              icon: Icons.schedule_rounded,
              label: '排队等待',
              filter: TaskFilter.queued,
            ),
            _drawerItem(
              app,
              icon: Icons.check_circle_outline_rounded,
              label: '已完成',
              filter: TaskFilter.completed,
            ),
            _drawerItem(
              app,
              icon: Icons.error_outline_rounded,
              label: '出错',
              filter: TaskFilter.error,
            ),
            _drawerItem(
              app,
              icon: Icons.hub_outlined,
              label: '种子任务',
              filter: TaskFilter.torrents,
            ),
            const Divider(indent: 16, endIndent: 16, height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                '按类型筛选',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: app.categoryFilter == null,
                    onSelected: (_) => app.setCategory(null),
                  ),
                  for (final category in DownloadCategory.values)
                    ChoiceChip(
                      label: Text(category.label),
                      avatar: Icon(category.icon, size: 16),
                      selected: app.categoryFilter == category,
                      onSelected: (_) => app.setCategory(category),
                    ),
                ],
              ),
            ),
            const Divider(indent: 16, endIndent: 16, height: 20),
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: const Text('内置浏览器'),
              onTap: () {
                Navigator.of(context).pop();
                _openBrowser(app);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              onTap: () {
                Navigator.of(context).pop();
                _openSettings(app);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('关于 Aero'),
              onTap: () {
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

  Widget _drawerItem(
    AppState app, {
    required IconData icon,
    required String label,
    required TaskFilter filter,
  }) {
    final selected = app.filter == filter && app.categoryFilter == null;
    final count = app.countFor(filter);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.6),
        leading: Icon(icon, size: 20),
        title: Text(label),
        trailing: Text(
          '$count',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        onTap: () {
          app.setFilter(filter);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _clipboardBanner(AppState app) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.content_paste_rounded,
            size: 20,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '剪贴板中发现链接：${shortPath(app.clipboardUrl!, max: 42)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final url = app.clipboardUrl;
              app.dismissClipboard();
              if (url != null) {
                showAddDownloadSheet(context, initialUrl: url);
              }
            },
            child: const Text('下载'),
          ),
          IconButton(
            tooltip: '忽略',
            iconSize: 18,
            onPressed: app.dismissClipboard,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(AppState app) {
    final scheme = Theme.of(context).colorScheme;
    final manager = app.manager;
    final withTotal = manager.tasks.where((t) => t.total > 0 && !t.isFinished);
    final totalBytes = withTotal.fold<int>(0, (sum, t) => sum + t.total);
    final doneBytes = withTotal.fold<int>(0, (sum, t) => sum + t.downloaded);
    final progress = totalBytes > 0 ? doneBytes / totalBytes : null;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatSpeed(manager.totalSpeed),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${manager.activeCount} 个进行中'
                        '${manager.queuedCount > 0 ? ' · ${manager.queuedCount} 个排队' : ''}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (progress != null)
                  Text(
                    formatPercent(progress),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(AppState app) {
    final tasks = app.visibleTasks;
    if (tasks.isEmpty) {
      return _EmptyState(
        hasTasks: app.manager.tasks.isNotEmpty,
        onAdd: () => showAddDownloadSheet(context),
        onReset: () {
          app.setFilter(TaskFilter.all);
          app.setCategory(null);
          app.setSearch('');
          _searchController.clear();
        },
      );
    }

    final simpleView =
        app.filter != TaskFilter.all ||
        app.categoryFilter != null ||
        app.searchQuery.trim().isNotEmpty;

    if (simpleView) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: tasks.length,
        itemBuilder: (context, index) => _taskTile(app, tasks[index]),
      );
    }

    final active = tasks
        .where(
          (t) =>
              t.status != TaskStatus.completed && t.status != TaskStatus.error,
        )
        .toList();
    final finished = tasks
        .where(
          (t) =>
              t.status == TaskStatus.completed || t.status == TaskStatus.error,
        )
        .toList();

    final children = <Widget>[];
    if (active.isNotEmpty) {
      children.add(_sectionHeader('进行中', active.length));
      children.addAll(active.map((t) => _taskTile(app, t)));
    }
    if (finished.isNotEmpty) {
      children.add(_sectionHeader('已结束', finished.length));
      children.addAll(finished.map((t) => _taskTile(app, t)));
    }
    children.add(const SizedBox(height: 88));
    return ListView(children: children);
  }

  Widget _sectionHeader(String title, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _taskTile(AppState app, DownloadTask task) {
    return TaskTile(
      task: task,
      selectionMode: app.selectionMode,
      selected: app.selectedIds.contains(task.id),
      onTap: () {
        if (app.selectionMode) {
          app.toggleSelection(task.id);
        } else {
          _showDetails(app, task);
        }
      },
      onLongPress: () => app.toggleSelection(task.id),
      onToggleSelect: () => app.toggleSelection(task.id),
      onPrimaryAction: () => _primaryAction(app, task),
      onMenuSelected: (action) => _menuAction(app, task, action),
    );
  }

  Future<void> _primaryAction(AppState app, DownloadTask task) async {
    switch (task.status) {
      case TaskStatus.completed:
        await _openFile(task);
        break;
      case TaskStatus.error:
        await app.manager.retry(task);
        break;
      case TaskStatus.paused:
      case TaskStatus.queued:
        app.manager.start(task);
        break;
      case TaskStatus.connecting:
      case TaskStatus.downloading:
      case TaskStatus.waiting:
        await app.manager.pause(task);
        break;
    }
  }

  Future<void> _menuAction(
    AppState app,
    DownloadTask task,
    String action,
  ) async {
    switch (action) {
      case 'details':
        _showDetails(app, task);
        break;
      case 'open':
        await _openFile(task);
        break;
      case 'folder':
        await _openFolder(task);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: task.url));
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('链接已复制')));
        break;
      case 'retry':
        await app.manager.retry(task);
        break;
      case 'delete':
        await _deleteTask(app, task);
        break;
    }
  }

  Future<void> _openFile(DownloadTask task) async {
    if (task.filePath.isEmpty) return;
    if (FileSystemEntity.isDirectorySync(task.filePath)) {
      await _openFolder(task);
      return;
    }
    final ok = await FileOpener.openFile(task.filePath);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开文件，可能尚未下载完成')));
    }
  }

  Future<void> _openFolder(DownloadTask task) async {
    if (task.filePath.isEmpty) return;
    final ok = await FileOpener.openFolder(task.filePath);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开所在文件夹')));
    }
  }

  Future<void> _deleteTask(AppState app, DownloadTask task) async {
    if (app.settings.confirmDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除任务'),
          content: Text('确定删除「${task.displayName}」吗？\n已下载的文件也会被删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await app.manager.remove(task, deleteFile: true);
  }

  Future<bool> _confirmDeleteMany(List<DownloadTask> tasks) async {
    final app = context.read<AppState>();
    if (!app.settings.confirmDelete) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定删除选中的 ${tasks.length} 个任务吗？\n已下载的文件也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _showDetails(AppState app, DownloadTask task) {
    final navigator = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _TaskDetailsSheet(
        task: task,
        onOpen: () => _openFile(task),
        onFolder: () => _openFolder(task),
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: task.url));
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('链接已复制')));
        },
        onEdit: task.isTorrent || task.isFinished
            ? null
            : () async {
                navigator.pop();
                if (task.status.isActive) await app.manager.pause(task);
                if (!mounted) return;
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditorPage(task: task),
                  ),
                );
              },
        onToggle: () async {
          navigator.pop();
          if (task.status.isActive) {
            await app.manager.pause(task);
          } else {
            app.manager.start(task);
          }
        },
        onRetry: () async {
          navigator.pop();
          await app.manager.retry(task);
        },
        onDelete: () async {
          navigator.pop();
          await _deleteTask(app, task);
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Detail sheet
// -----------------------------------------------------------------------------

class _TaskDetailsSheet extends StatelessWidget {
  const _TaskDetailsSheet({
    required this.task,
    required this.onOpen,
    required this.onFolder,
    required this.onCopy,
    required this.onEdit,
    required this.onToggle,
    required this.onRetry,
    required this.onDelete,
  });

  final DownloadTask task;
  final Future<void> Function() onOpen;
  final Future<void> Function() onFolder;
  final Future<void> Function() onCopy;
  final Future<void> Function()? onEdit;
  final Future<void> Function() onToggle;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = task.category;
    final isActive = task.status.isActive;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  task.isTorrent ? Icons.hub_outlined : category.icon,
                  color: category.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.displayName,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${task.status.label} · ${formatPercent(task.progress)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: task.progress, minHeight: 6),
          ),
          const SizedBox(height: 16),
          _kv(context, '大小', task.total > 0 ? formatBytes(task.total) : '未知'),
          _kv(context, '已下载', formatBytes(task.downloaded)),
          if (task.isTorrent) ...[
            _kv(context, '速度', formatSpeed(task.speed)),
            _kv(context, '上传', formatSpeed(task.uploadSpeed)),
            _kv(context, '节点 / 种子', '${task.peers} / ${task.seeders}'),
            _kv(context, 'Info hash', task.infoHash),
          ] else ...[
            _kv(context, '速度', formatSpeed(task.speed)),
            if (task.eta != null)
              _kv(context, '剩余时间', formatDuration(task.eta!.inMilliseconds)),
            _kv(context, '线程', '${task.segments.length}'),
            _kv(context, 'Range', task.noRange ? '已禁用（单连接）' : '启用'),
            if (task.checksum.isNotEmpty)
              _kv(context, '校验', task.checksumType.toUpperCase()),
          ],
          _kv(context, '保存位置', task.filePath),
          _kv(
            context,
            '创建时间',
            formatDateTime(DateTime.fromMillisecondsSinceEpoch(task.createdAt)),
          ),
          if (task.finishedAt != null)
            _kv(
              context,
              '完成时间',
              formatDateTime(
                DateTime.fromMillisecondsSinceEpoch(task.finishedAt!),
              ),
            ),
          if (task.message.isNotEmpty) _kv(context, '状态信息', task.message),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => onToggle(),
                icon: Icon(
                  isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isActive ? '暂停' : '继续'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpen(),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开'),
              ),
              OutlinedButton.icon(
                onPressed: () => onFolder(),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('文件夹'),
              ),
              OutlinedButton.icon(
                onPressed: () => onCopy(),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('复制链接'),
              ),
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: () => onEdit!(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
              if (task.status == TaskStatus.error)
                OutlinedButton.icon(
                  onPressed: () => onRetry(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              OutlinedButton.icon(
                onPressed: () => onDelete(),
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String key, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              key,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small widgets
// -----------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasTasks,
    required this.onAdd,
    required this.onReset,
  });

  final bool hasTasks;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasTasks
                    ? Icons.filter_alt_off_rounded
                    : Icons.download_done_rounded,
                size: 44,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasTasks ? '当前筛选没有任务' : '还没有下载任务',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasTasks ? '试试切换分类或清除搜索条件' : '粘贴链接、选择种子文件，或从浏览器一键添加',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (hasTasks)
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('重置筛选'),
              )
            else
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('新建下载'),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
