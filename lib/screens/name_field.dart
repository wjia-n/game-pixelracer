import 'package:flutter/material.dart';
import '../theme/pixel_themes.dart';

/// A driver-name field that satisfies the hard persistence rule:
/// - saves on EVERY keystroke (never waits for keyboard-done),
/// - commits the final text when focus is lost,
/// - never uses setStringList (the caller's [onName] writes ONE JSON string).
class DriverNameField extends StatefulWidget {
  final PixelTheme theme;
  final int index;
  final String initial;
  final String label;
  final void Function(String) onName;

  const DriverNameField({
    super.key,
    required this.theme,
    required this.index,
    required this.initial,
    required this.label,
    required this.onName,
  });

  @override
  State<DriverNameField> createState() => _DriverNameFieldState();
}

class _DriverNameFieldState extends State<DriverNameField> {
  late final TextEditingController _c;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    _focus = FocusNode();
    // Commit on focus loss: whatever is in the box when the user taps away
    // is persisted (covers "back" / tap-away without keyboard-done).
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onName(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant DriverNameField old) {
    super.didUpdateWidget(old);
    // Keep the box in sync if the persisted name changed elsewhere
    // (e.g. a Pro reset); never clobber in-progress typing.
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      maxLength: 14,
      style: PixelUi.body(15, theme: widget.theme),
      decoration: InputDecoration(
        counterText: '',
        labelText: widget.label,
        labelStyle: PixelUi.label(12, theme: widget.theme),
        isDense: true,
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: widget.theme.muted)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: widget.theme.accent)),
      ),
      // Save on EVERY keystroke.
      onChanged: widget.onName,
      onSubmitted: (v) {
        widget.onName(v);
        _focus.unfocus();
      },
    );
  }
}
