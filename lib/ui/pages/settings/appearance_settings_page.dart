import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../state/app_state.dart';
import 'settings_widgets.dart';
import '../../../utils/constants.dart';
import '../../../utils/haptics.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final settings = context.select<AppState, AppSettings>((s) => s.settings);
    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          SettingsSectionCard(
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
                        SettingsColorDot(
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
          SettingsSectionCard(
            title: '动效',
            icon: Icons.animation_rounded,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.animations,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(animations: value));
                },
                title: const Text('界面动画'),
                subtitle: const Text('页面切换、菜单、搜索与进度过渡动画'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
