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
            title: '视觉效果',
            icon: Icons.auto_awesome_rounded,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.animations,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(animations: value));
                },
                title: const Text('界面动画'),
                subtitle: const Text('页面切换、主题过渡与界面微动效'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.blur,
                onChanged: (value) {
                  Haptics.select();
                  state.updateSettings(settings.copyWith(blur: value));
                },
                title: const Text('高斯模糊'),
                subtitle: const Text('抽屉、下载弹层与详情面板使用毛玻璃效果'),
              ),
              IgnorePointer(
                ignoring: !settings.blur,
                child: AnimatedOpacity(
                  opacity: settings.blur ? 1 : 0.4,
                  duration: settings.animations
                      ? const Duration(milliseconds: 200)
                      : Duration.zero,
                  child: SettingsSliderTile(
                    title: '模糊强度',
                    subtitle: '数值越大，背景越模糊',
                    value: settings.blurSigma,
                    min: 2,
                    max: 40,
                    divisions: 19,
                    valueText: '${settings.blurSigma.round()}',
                    onChanged: (value) => state.updateSettings(
                      settings.copyWith(blurSigma: value),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
