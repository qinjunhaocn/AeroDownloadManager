import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../state/app_state.dart';
import '../../../utils/haptics.dart';
import '../../../utils/search_engines.dart';
import '../../widgets/text_input_dialog.dart';

Future<void> editTextSetting(
  BuildContext context, {
  required String title,
  required String hint,
  required String initial,
  required ValueChanged<String> onSaved,
  int maxLines = 1,
}) async {
  Haptics.select();
  final result = await showAeroTextInputDialog(
    context,
    title: title,
    initial: initial,
    hint: hint,
    maxLines: maxLines,
  );
  if (result != null) onSaved(result);
}

Future<void> chooseSearchEngine(
  BuildContext context,
  AppState state,
  AppSettings settings,
) async {
  Haptics.select();
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('搜索引擎'),
      children: [
        for (final engine in SearchEngines.all)
          SimpleDialogOption(
            onPressed: () {
              Haptics.select();
              Navigator.pop(context, engine.id);
            },
            child: Row(
              children: [
                Icon(
                  settings.searchEngine == engine.id
                      ? Icons.check_circle_rounded
                      : Icons.search_rounded,
                  size: 20,
                  color: settings.searchEngine == engine.id
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 12),
                Text(engine.name),
              ],
            ),
          ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return;
  Haptics.select();
  await state.updateSettings(settings.copyWith(searchEngine: selected));
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueText;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Text(
              valueText,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: (_) => Haptics.select(),
        ),
      ],
    );
  }
}

class SettingsColorDot extends StatelessWidget {
  const SettingsColorDot({
    super.key,
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final animations = context.select<AppState, bool>(
      (state) => state.settings.animations,
    );
    final duration = animations
        ? const Duration(milliseconds: 200)
        : Duration.zero;
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: duration,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: duration,
            child: selected
                ? const Icon(
                    Icons.check,
                    key: ValueKey('selected'),
                    size: 20,
                    color: Colors.white,
                  )
                : const SizedBox(key: ValueKey('unselected')),
          ),
        ),
      ),
    );
  }
}
