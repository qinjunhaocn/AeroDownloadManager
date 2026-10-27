import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../state/app_state.dart';
import 'settings_widgets.dart';

import 'dart:io';

import '../../../utils/haptics.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final settings = context.select<AppState, AppSettings>((s) => s.settings);
    return Scaffold(
      appBar: AppBar(title: const Text('通知与交互')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          if (Platform.isAndroid)
            SettingsSectionCard(
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
          SettingsSectionCard(
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
        ],
      ),
    );
  }
}
