import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SaveIntent extends Intent {
  const SaveIntent();
}

class NewIntent extends Intent {
  const NewIntent();
}

class ClearLineIntent extends Intent {
  const ClearLineIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

/// Common keyboard shortcuts for data-entry screens.
///
/// - Ctrl+S: Save
/// - Ctrl+N: New / Clear
/// - Ctrl+L: Clear current line/item
/// - Ctrl+F: Focus search
class EntryShortcuts extends StatelessWidget {
  const EntryShortcuts({
    super.key,
    required this.child,
    this.onSave,
    this.onNew,
    this.onClearLine,
    this.onFocusSearch,
  });

  final Widget child;
  final FutureOr<void> Function()? onSave;
  final FutureOr<void> Function()? onNew;
  final FutureOr<void> Function()? onClearLine;
  final FutureOr<void> Function()? onFocusSearch;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyS, control: true):
          const SaveIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const NewIntent(),
      const SingleActivator(LogicalKeyboardKey.keyL, control: true):
          const ClearLineIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          const FocusSearchIntent(),
    };

    final actions = <Type, Action<Intent>>{
      SaveIntent: CallbackAction<SaveIntent>(
        onInvoke: (_) {
          onSave?.call();
          return null;
        },
      ),
      NewIntent: CallbackAction<NewIntent>(
        onInvoke: (_) {
          onNew?.call();
          return null;
        },
      ),
      ClearLineIntent: CallbackAction<ClearLineIntent>(
        onInvoke: (_) {
          onClearLine?.call();
          return null;
        },
      ),
      FocusSearchIntent: CallbackAction<FocusSearchIntent>(
        onInvoke: (_) {
          onFocusSearch?.call();
          return null;
        },
      ),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: actions,
        child: Focus(child: child),
      ),
    );
  }
}
