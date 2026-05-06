import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';

/// One row in the SET / WARMUP table.
///
/// Three visual states:
/// - empty (placeholder text, light borders)
/// - filled (values present, not logged)
/// - logged (slightly muted background + checkmark on the right)
///
/// Uses the system numeric keyboard:
///  - weight: `numberWithOptions(decimal: true)`
///  - reps:  `TextInputType.number`
class SetRow extends StatefulWidget {
  /// Display marker on the left: a number ("1", "2", ...) or "W" for warmup.
  final String marker;
  final bool isWarmup;

  final double? weight;
  final int? reps;
  final bool isLogged;

  /// Ghost text shown in the reps field when there's no value (e.g., last
  /// session's reps). Disappears on focus.
  final String? repsGhost;

  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<int?> onRepsChanged;

  const SetRow({
    super.key,
    required this.marker,
    required this.weight,
    required this.reps,
    required this.isLogged,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.isWarmup = false,
    this.repsGhost,
  });

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.weight == null ? '' : _formatWeight(widget.weight!),
    );
    _repsCtrl = TextEditingController(
      text: widget.reps?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant SetRow old) {
    super.didUpdateWidget(old);
    final wText = widget.weight == null ? '' : _formatWeight(widget.weight!);
    if (_weightCtrl.text != wText) _weightCtrl.text = wText;
    final rText = widget.reps?.toString() ?? '';
    if (_repsCtrl.text != rText) _repsCtrl.text = rText;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  String _formatWeight(double w) {
    if (w == w.truncate()) return w.toInt().toString();
    return w.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              widget.marker,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isWarmup
                    ? AppTheme.primaryOrange
                    : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NumberField(
              controller: _weightCtrl,
              hint: 'lbs',
              isLogged: widget.isLogged,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (s) {
                if (s.isEmpty) {
                  widget.onWeightChanged(null);
                  return;
                }
                widget.onWeightChanged(double.tryParse(s));
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '×',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _NumberField(
              controller: _repsCtrl,
              hint: widget.repsGhost ?? '',
              isLogged: widget.isLogged,
              keyboard: TextInputType.number,
              onChanged: (s) {
                if (s.isEmpty) {
                  widget.onRepsChanged(null);
                  return;
                }
                widget.onRepsChanged(int.tryParse(s));
              },
            ),
          ),
          SizedBox(
            width: 32,
            child: widget.isLogged
                ? const Icon(
                    Icons.check,
                    color: AppTheme.recoveryGreen,
                    size: 20,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isLogged;
  final TextInputType keyboard;
  final ValueChanged<String> onChanged;

  const _NumberField({
    required this.controller,
    required this.hint,
    required this.isLogged,
    required this.keyboard,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isLogged
            ? AppTheme.cardBackground.withValues(alpha: 0.6)
            : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: keyboard,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        inputFormatters: [
          if (keyboard == TextInputType.number)
            FilteringTextInputFormatter.digitsOnly
          else
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
