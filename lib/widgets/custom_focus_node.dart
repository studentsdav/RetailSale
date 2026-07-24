import 'package:flutter/material.dart';

/// A custom FocusNode that allows suppressing the software keyboard
/// based on a callback. This is useful when using physical keyboards/scanners
/// or preventing programmatic focus requests from opening the keyboard.
class KeyboardControlFocusNode extends FocusNode {
  final bool Function() shouldPreventKeyboard;

  KeyboardControlFocusNode({
    required this.shouldPreventKeyboard,
    super.debugLabel,
    super.skipTraversal,
    super.canRequestFocus,
    super.descendantsAreFocusable,
    super.descendantsAreTraversable,
  });

  @override
  bool consumeKeyboardToken() {
    if (shouldPreventKeyboard()) {
      return false;
    }
    return super.consumeKeyboardToken();
  }
}
