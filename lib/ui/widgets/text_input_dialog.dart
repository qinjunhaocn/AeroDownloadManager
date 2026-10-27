import 'package:flutter/material.dart';

import '../../utils/haptics.dart';
import 'glass_surface.dart';

/// Shows a single-field dialog whose [TextEditingController] is owned by the
/// dialog route itself.
///
/// Disposing a controller right after `await showDialog(...)` is unsafe: the
/// route's exit animation is still running and the [TextField] still listens to
/// the controller, which trips `ChangeNotifier.dispose()`'s `_dependents.isEmpty`
/// assertion. Owning the controller in the dialog state avoids that entirely.
Future<String?> showAeroTextInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  int maxLines = 1,
  String confirmLabel = '保存',
  String cancelLabel = '取消',
  TextInputType? keyboardType,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => GlassSurface(
      borderRadius: BorderRadius.circular(28),
      child: _AeroTextInputDialog(
        title: title,
        initial: initial,
        hint: hint,
        maxLines: maxLines,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        keyboardType: keyboardType,
      ),
    ),
  );
}

class _AeroTextInputDialog extends StatefulWidget {
  const _AeroTextInputDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.cancelLabel,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String title;
  final String initial;
  final String? hint;
  final int maxLines;
  final String confirmLabel;
  final String cancelLabel;
  final TextInputType? keyboardType;

  @override
  State<_AeroTextInputDialog> createState() => _AeroTextInputDialogState();
}

class _AeroTextInputDialogState extends State<_AeroTextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Haptics.select();
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        textInputAction: widget.maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: widget.maxLines > 1 ? null : (_) => _submit(),
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Haptics.select();
            Navigator.of(context).pop();
          },
          child: Text(widget.cancelLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
