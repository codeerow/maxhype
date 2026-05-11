import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import 'effective_set_pill.dart';

/// One row in the Effective sets / Warmup table — three pills laid out as
/// `[ SET | REPS | WEIGHT ]`.
///
/// REPS / WEIGHT cells are real `TextField`s styled as pills so the system
/// numeric keyboard works the way the OS expects (focus, selection, IME).
class EffectiveSetRow extends StatefulWidget {
  /// Marker on the SET column. Either a digit ("1", "2") or "W" for warmup.
  final String marker;

  /// Whether this row is the warmup. Reserved for future styling tweaks
  /// (currently styled the same as a numbered set).
  final bool isWarmup;

  final double? weight;
  final int? reps;
  final bool isLogged;

  /// True for the *current* (next-to-log) row. Drives the bright "draft"
  /// pill colour per the design ref — non-current empty rows stay dark even
  /// if values are pre-filled.
  final bool isCurrent;

  /// Pre-fill values shown when no draft has been entered yet (last session
  /// or planned values). Rendered as muted placeholders.
  final double? prefillWeight;
  final int? prefillReps;

  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<int?> onRepsChanged;

  /// Called when the user taps "Done" on the weight field's IME action —
  /// equivalent to pressing the Log Set button. Optional: when null, Done
  /// just dismisses the keyboard.
  final VoidCallback? onSubmitted;

  /// Externally-owned focus node for the REPS field. When supplied, the
  /// caller can `requestFocus()` to bring the keyboard up on this row
  /// (e.g., after logging the previous set we jump to the next row).
  final FocusNode? repsFocusNode;

  /// True if this set holds a personal record. Adds 🔥 emojis on either
  /// side of the row and tints the pills gold-ish to make it stand out.
  final bool isPr;

  const EffectiveSetRow({
    super.key,
    required this.marker,
    required this.weight,
    required this.reps,
    required this.isLogged,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.isCurrent = false,
    this.isWarmup = false,
    this.prefillWeight,
    this.prefillReps,
    this.onSubmitted,
    this.repsFocusNode,
    this.isPr = false,
  });

  @override
  State<EffectiveSetRow> createState() => _EffectiveSetRowState();
}

class _EffectiveSetRowState extends State<EffectiveSetRow> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;
  final FocusNode _weightFocus = FocusNode();
  // Internal fallback when the parent doesn't pass one in.
  FocusNode? _ownedRepsFocus;
  FocusNode get _repsFocus =>
      widget.repsFocusNode ?? (_ownedRepsFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: _formatWeight(widget.weight));
    _repsCtrl = TextEditingController(text: widget.reps?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant EffectiveSetRow old) {
    super.didUpdateWidget(old);
    final w = _formatWeight(widget.weight);
    if (_weightCtrl.text != w && !_weightFocus.hasFocus) {
      _weightCtrl.text = w;
    }
    final r = widget.reps?.toString() ?? '';
    if (_repsCtrl.text != r && !_repsFocus.hasFocus) {
      _repsCtrl.text = r;
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _weightFocus.dispose();
    _ownedRepsFocus?.dispose();
    super.dispose();
  }

  String _formatWeight(double? w) {
    if (w == null) return '';
    if (w == w.truncate()) return w.toInt().toString();
    return w.toStringAsFixed(1);
  }

  PillState get _state {
    // A PR row overrides every other visual state — the row is meant to
    // read instantly as "this beat your record", not as "logged".
    if (widget.isPr) return PillState.pr;
    if (widget.isLogged) return PillState.logged;
    if (widget.isCurrent) return PillState.draft;
    return PillState.empty;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // SET marker pill — narrow. Three render modes:
          //  * PR    → 🔥 emoji (no number, no checkmark)
          //  * logged → green checkmark
          //  * else   → set number / "W"
          EffectiveSetPill(
            width: 50,
            state: state,
            child: widget.isPr
                ? const Text('🔥', style: TextStyle(fontSize: 20))
                : widget.isLogged
                    ? const Icon(
                        Icons.check,
                        color: Color(0xFF062716),
                        size: 22,
                      )
                    : Text(
                        widget.marker,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: pillColorsFor(state).foreground,
                        ),
                      ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PillTextField(
              controller: _repsCtrl,
              focusNode: _repsFocus,
              state: state,
              // Logged sets are still editable — the user can fix typos
              // after the fact. The pill keeps its green colour to signal
              // it's logged, but typing replaces the value in place.
              readOnly: false,
              hint: widget.prefillReps?.toString() ?? '',
              keyboard: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _weightFocus.requestFocus(),
              formatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (s) {
                if (s.isEmpty) {
                  widget.onRepsChanged(null);
                } else {
                  widget.onRepsChanged(int.tryParse(s));
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PillTextField(
              controller: _weightCtrl,
              focusNode: _weightFocus,
              state: state,
              readOnly: false,
              hint: widget.prefillWeight == null
                  ? ''
                  : _formatWeight(widget.prefillWeight),
              keyboard:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                // Done on an already-logged set just dismisses the keyboard;
                // it shouldn't trigger Log Set on some other unrelated row.
                if (widget.isLogged) {
                  _weightFocus.unfocus();
                  return;
                }
                if (widget.onSubmitted != null) {
                  widget.onSubmitted!();
                } else {
                  _weightFocus.unfocus();
                }
              },
              formatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (s) {
                if (s.isEmpty) {
                  widget.onWeightChanged(null);
                } else {
                  widget.onWeightChanged(double.tryParse(s));
                }
              },
            ),
          ),
        ],
      ),
    );

    return row;
  }
}

/// Real TextField styled to look like an [EffectiveSetPill]. Using a real
/// field (instead of an invisible overlay) means the system keyboard,
/// caret, and selection behave correctly out of the box.
class _PillTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final PillState state;
  final bool readOnly;
  final String hint;
  final TextInputType keyboard;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter> formatters;
  final ValueChanged<String> onChanged;

  const _PillTextField({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.readOnly,
    required this.hint,
    required this.keyboard,
    required this.formatters,
    required this.onChanged,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = pillColorsFor(state);
    // For empty pills the static EffectiveSetPill uses a muted foreground
    // (textSecondary). In the editable variant we want the typed value to
    // pop, so override empty to textPrimary while keeping the shared
    // background.
    final fg = state == PillState.empty
        ? AppTheme.textPrimary
        : colors.foreground;
    final bg = colors.background;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        keyboardType: keyboard,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        inputFormatters: formatters,
        textAlign: TextAlign.center,
        cursorColor: fg,
        style: TextStyle(
          color: fg,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: fg.withValues(alpha: 0.45),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
