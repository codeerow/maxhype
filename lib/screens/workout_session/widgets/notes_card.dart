import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// "Notes" card used on the logging screen — a single card with a header
/// label and a multiline text field (transparent over the card background).
/// Matches the design ref where Notes is one cohesive block, not a label
/// stacked above a separate input box.
class NotesCard extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const NotesCard({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends State<NotesCard> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant NotesCard old) {
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
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
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
              hintText: 'No notes added…',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            onChanged: _onChanged,
          ),
        ],
      ),
    );
  }
}
