import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../utils/haptics.dart';

class TaskSortButton extends StatelessWidget {
  const TaskSortButton({super.key, required this.app});

  final AppState app;

  Widget _item(BuildContext context, String label, TaskSort value) {
    final selected = app.sort == value;
    return MenuItemButton(
      onPressed: () {
        Haptics.select();
        app.setSort(value);
      },
      leadingIcon: selected
          ? Icon(
              Icons.check_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            )
          : const SizedBox(width: 18),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      animated: app.settings.animations,
      consumeOutsideTap: false,
      style: const MenuStyle(alignment: Alignment.bottomRight),
      menuChildren: [
        _item(context, '最新优先', TaskSort.newest),
        _item(context, '最早优先', TaskSort.oldest),
        _item(context, '按名称', TaskSort.name),
        _item(context, '按大小', TaskSort.size),
        _item(context, '按进度', TaskSort.progress),
      ],
      builder: (context, controller, child) => IconButton(
        tooltip: '排序',
        icon: const Icon(Icons.sort_rounded),
        onPressed: () {
          Haptics.select();
          controller.isOpen ? controller.close() : controller.open();
        },
      ),
    );
  }
}
