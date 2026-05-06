import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Multiline notes input. Debounces onChanged so we don't dispatch a bloc
/// event per keystroke; the bloc itself also debounces persistence.
class NotesField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const NotesField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<NotesField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant NotesField old) {
    super.didUpdateWidget(old);
    if (widget.initialValue != _controller.text &&
        !_controller.selection.isValid) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String s) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      widget.onChanged(s);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: TextField(
        controller: _controller,
        minLines: 3,
        maxLines: 6,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: 'Add notes for this exercise…',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        onChanged: _onChanged,
      ),
    );
  }
}
