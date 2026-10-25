import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../utils/haptics.dart';

class TaskSortButton extends StatelessWidget {
  const TaskSortButton({super.key, required this.app});

  final AppState app;

  PopupMenuItem<TaskSort> _item(
    BuildContext context,
    String label,
    TaskSort value,
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

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TaskSort>(
      tooltip: '排序',
      icon: const Icon(Icons.sort_rounded),
      initialValue: app.sort,
      onOpened: Haptics.select,
      onSelected: (value) {
        Haptics.select();
        app.setSort(value);
      },
      itemBuilder: (context) => [
        _item(context, '最新优先', TaskSort.newest),
        _item(context, '最早优先', TaskSort.oldest),
        _item(context, '按名称', TaskSort.name),
        _item(context, '按大小', TaskSort.size),
        _item(context, '按进度', TaskSort.progress),
      ],
    );
  }
}
