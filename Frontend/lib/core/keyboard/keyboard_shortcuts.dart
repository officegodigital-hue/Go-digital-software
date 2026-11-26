// lib/core/keyboard/keyboard_shortcuts.dart
//
// App-wide keyboard access for GoDigital Portal.
//
// Why this exists
// ---------------
// Most of the app was mouse-only. This module adds a single, consistent
// keyboard layer that works on every screen:
//
//   • Enter / NumpadEnter  → submit the focused form or dialog (login, add,
//                            edit, confirm …). Wrap a form/dialog body in
//                            [KeyboardSubmit] to opt in.
//   • Ctrl/Cmd + S         → trigger the active screen's Save action.
//   • Ctrl/Cmd + K         → focus the top-bar search field.
//   • F1  or  Ctrl/Cmd + / → open the "Keyboard Shortcuts" help sheet.
//   • Esc                  → close the current dialog / menu (Flutter built-in).
//
// How it is wired
// ---------------
//   1. [AppShortcuts] wraps the whole app (see main.dart `builder:`). It maps
//      the key combos above to intents and runs them through
//      [AppShortcutsController].
//   2. Top bars call [AppShortcutsController.instance.registerSearchFocus] so
//      Ctrl+K knows which search box to focus.
//   3. Screens with a primary Save button call
//      [AppShortcutsController.instance.registerSave] (or use the
//      [KeyboardSaveScope] widget) so Ctrl+S knows what to save.
//   4. Any form / dialog wraps its content in [KeyboardSubmit] to get
//      Enter-to-submit and Esc-to-cancel.
//
// The registries are LIFO ("last registered wins"), so a dialog opened on top
// of a screen captures Enter / Ctrl+S while it is open, and control returns to
// the screen underneath once it closes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Central registry
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the currently-active keyboard handlers for the app. Widgets register
/// their callbacks when they mount and remove them when they are disposed.
class AppShortcutsController {
  AppShortcutsController._();
  static final AppShortcutsController instance = AppShortcutsController._();

  final List<VoidCallback> _searchFocusHandlers = <VoidCallback>[];
  final List<VoidCallback> _saveHandlers = <VoidCallback>[];

  // ── Search focus (Ctrl/Cmd + K) ──
  void registerSearchFocus(VoidCallback handler) {
    _searchFocusHandlers.remove(handler);
    _searchFocusHandlers.add(handler);
  }

  void unregisterSearchFocus(VoidCallback handler) =>
      _searchFocusHandlers.remove(handler);

  bool focusSearch() {
    if (_searchFocusHandlers.isEmpty) return false;
    _searchFocusHandlers.last();
    return true;
  }

  bool get hasSearch => _searchFocusHandlers.isNotEmpty;

  // ── Save (Ctrl/Cmd + S) ──
  void registerSave(VoidCallback handler) {
    _saveHandlers.remove(handler);
    _saveHandlers.add(handler);
  }

  void unregisterSave(VoidCallback handler) => _saveHandlers.remove(handler);

  bool save() {
    if (_saveHandlers.isEmpty) return false;
    _saveHandlers.last();
    return true;
  }

  bool get hasSave => _saveHandlers.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Intents
// ─────────────────────────────────────────────────────────────────────────────

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class SaveShortcutIntent extends Intent {
  const SaveShortcutIntent();
}

class ShowShortcutsHelpIntent extends Intent {
  const ShowShortcutsHelpIntent();
}

// ─────────────────────────────────────────────────────────────────────────────
// App-wide wrapper
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps the application so the global keyboard shortcuts work everywhere.
/// Install it once in `MaterialApp`'s `builder`.
class AppShortcuts extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const AppShortcuts({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Save
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const SaveShortcutIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            const SaveShortcutIntent(),
        // Focus the top-bar search
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const FocusSearchIntent(),
        // Help
        const SingleActivator(LogicalKeyboardKey.f1):
            const ShowShortcutsHelpIntent(),
        const SingleActivator(LogicalKeyboardKey.slash, control: true):
            const ShowShortcutsHelpIntent(),
        const SingleActivator(LogicalKeyboardKey.slash, meta: true):
            const ShowShortcutsHelpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SaveShortcutIntent: CallbackAction<SaveShortcutIntent>(
            onInvoke: (_) {
              AppShortcutsController.instance.save();
              return null;
            },
          ),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (_) {
              AppShortcutsController.instance.focusSearch();
              return null;
            },
          ),
          ShowShortcutsHelpIntent: CallbackAction<ShowShortcutsHelpIntent>(
            onInvoke: (_) {
              final ctx = navigatorKey.currentContext ?? context;
              showKeyboardShortcutsHelp(ctx);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Save scope – register a screen's Save action for Ctrl+S
// ─────────────────────────────────────────────────────────────────────────────

/// Registers [onSave] as the active screen's Save action while this widget is
/// mounted, so Ctrl/Cmd + S triggers it. Wrap a screen (or a section with a
/// Save button) in this widget.
class KeyboardSaveScope extends StatefulWidget {
  final VoidCallback onSave;
  final Widget child;

  const KeyboardSaveScope({
    super.key,
    required this.onSave,
    required this.child,
  });

  @override
  State<KeyboardSaveScope> createState() => _KeyboardSaveScopeState();
}

class _KeyboardSaveScopeState extends State<KeyboardSaveScope> {
  late VoidCallback _handler;

  @override
  void initState() {
    super.initState();
    _handler = () => widget.onSave();
    AppShortcutsController.instance.registerSave(_handler);
  }

  @override
  void dispose() {
    AppShortcutsController.instance.unregisterSave(_handler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────────────────────
// Enter-to-submit / Esc-to-cancel for forms & dialogs
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

class _CancelIntent extends Intent {
  const _CancelIntent();
}

/// Wrap a form or dialog body so that:
///   • Enter / NumpadEnter runs [onSubmit] (e.g. Save / Login / Confirm)
///   • Esc runs [onCancel] (usually `Navigator.pop`)
///   • Ctrl/Cmd + S also runs [onSubmit] while this is focused.
///
/// Note: because Enter is captured here, use it around dialogs/forms whose
/// text inputs are single-line. For a deliberately multi-line field, place it
/// outside this wrapper or pass [intercept] = false.
class KeyboardSubmit extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;

  /// When false, Enter is left alone (useful if the form is multi-line heavy).
  final bool intercept;

  /// Request focus for the subtree on first build so the shortcuts are live
  /// even before the user clicks a field.
  final bool autofocus;

  const KeyboardSubmit({
    super.key,
    required this.child,
    this.onSubmit,
    this.onCancel,
    this.intercept = true,
    this.autofocus = false,
  });

  @override
  State<KeyboardSubmit> createState() => _KeyboardSubmitState();
}

class _KeyboardSubmitState extends State<KeyboardSubmit> {
  VoidCallback? _saveHandler;

  @override
  void initState() {
    super.initState();
    if (widget.onSubmit != null) {
      _saveHandler = () => widget.onSubmit!();
      AppShortcutsController.instance.registerSave(_saveHandler!);
    }
  }

  @override
  void dispose() {
    if (_saveHandler != null) {
      AppShortcutsController.instance.unregisterSave(_saveHandler!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.intercept) return widget.child;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        if (widget.onSubmit != null) ...{
          const SingleActivator(LogicalKeyboardKey.enter): const _SubmitIntent(),
          const SingleActivator(LogicalKeyboardKey.numpadEnter):
              const _SubmitIntent(),
        },
        if (widget.onCancel != null)
          const SingleActivator(LogicalKeyboardKey.escape):
              const _CancelIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SubmitIntent: CallbackAction<_SubmitIntent>(
            onInvoke: (_) {
              // Don't hijack Enter while the user is typing in a multi-line
              // field (description / notes) — let it insert a newline there.
              if (_focusedFieldIsMultiline()) return null;
              widget.onSubmit?.call();
              return null;
            },
          ),
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (_) {
              widget.onCancel?.call();
              return null;
            },
          ),
        },
        child: widget.autofocus
            ? FocusScope(autofocus: true, child: widget.child)
            : widget.child,
      ),
    );
  }
}

/// True when the currently focused editable is a multi-line text field, so
/// Enter should insert a newline instead of submitting the form.
bool _focusedFieldIsMultiline() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  EditableText? editable;
  final w = ctx.widget;
  if (w is EditableText) {
    editable = w;
  } else {
    editable = ctx.findAncestorWidgetOfExactType<EditableText>();
  }
  if (editable == null) return false;
  final int? maxLines = editable.maxLines;
  final int? minLines = editable.minLines;
  return maxLines == null || maxLines > 1 || (minLines != null && minLines > 1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Arrow-key focus group (for sidebars, menus, button rows — NO text fields)
// ─────────────────────────────────────────────────────────────────────────────

/// Makes Up/Down and Left/Right arrow keys move focus between the focusable
/// children (menu items, buttons) in reading order, and keeps Tab traversal
/// contained to this group.
///
/// Use ONLY around regions that have no text inputs (a navigation sidebar, a
/// toolbar, a menu). Do not wrap forms — it would stop arrow keys from moving
/// the text cursor.
class ArrowFocusGroup extends StatelessWidget {
  final Widget child;

  const ArrowFocusGroup({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft): PreviousFocusIntent(),
        },
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable help button
// ─────────────────────────────────────────────────────────────────────────────

/// A help (?) button that opens the keyboard-shortcuts sheet. Drop it in top
/// bars, the home header, etc.
class KeyboardHelpButton extends StatelessWidget {
  final Color? color;
  final double size;
  final EdgeInsetsGeometry padding;

  const KeyboardHelpButton({
    super.key,
    this.color,
    this.size = 20,
    this.padding = const EdgeInsets.all(4),
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Help & keyboard shortcuts  (F1)',
      icon: Icon(Icons.help_outline_rounded, size: size, color: color),
      padding: padding,
      constraints: const BoxConstraints(),
      onPressed: () => showKeyboardShortcutsHelp(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The help sheet
// ─────────────────────────────────────────────────────────────────────────────

class ShortcutRow {
  final List<String> keys;
  final String description;
  const ShortcutRow(this.keys, this.description);
}

class ShortcutGroup {
  final String title;
  final List<ShortcutRow> rows;
  const ShortcutGroup(this.title, this.rows);
}

const List<ShortcutGroup> kKeyboardShortcutGroups = <ShortcutGroup>[
  ShortcutGroup('General', <ShortcutRow>[
    ShortcutRow(['Enter'], 'Submit / confirm the current form or dialog'),
    ShortcutRow(['Ctrl', 'S'], 'Save the current page'),
    ShortcutRow(['Ctrl', 'K'], 'Jump to the top search bar'),
    ShortcutRow(['Esc'], 'Close the open dialog or menu / cancel'),
    ShortcutRow(['F1'], 'Open this keyboard shortcuts help'),
    ShortcutRow(['Ctrl', '/'], 'Open this keyboard shortcuts help'),
  ]),
  ShortcutGroup('Sign in', <ShortcutRow>[
    ShortcutRow(['Enter'], 'Sign in with the typed email & password'),
    ShortcutRow(['Tab'], 'Move from the email field to the password field'),
  ]),
  ShortcutGroup('Forms & dialogs', <ShortcutRow>[
    ShortcutRow(['Tab'], 'Move to the next field'),
    ShortcutRow(['Shift', 'Tab'], 'Move to the previous field'),
    ShortcutRow(['Enter'], 'Press the primary button (Save / Add / Confirm)'),
    ShortcutRow(['Space'], 'Toggle the focused checkbox / press the button'),
    ShortcutRow(['Esc'], 'Cancel and close the dialog'),
  ]),
  ShortcutGroup('Search & lists', <ShortcutRow>[
    ShortcutRow(['Ctrl', 'K'], 'Focus the top search bar'),
    ShortcutRow(['Enter'], 'Run the search / open the first result'),
    ShortcutRow(['Esc'], 'Clear the search box'),
  ]),
];

Future<void> showKeyboardShortcutsHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _KeyboardShortcutsDialog(),
  );
}

class _KeyboardShortcutsDialog extends StatelessWidget {
  const _KeyboardShortcutsDialog();

  static const Color _primary = Color(0xFF0757D5);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double maxW = media.size.width < 560 ? media.size.width - 32 : 560;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: media.size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A3D91), Color(0xFF1D4ED8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.keyboard_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keyboard Shortcuts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Work faster — use the keyboard for everything',
                          style: TextStyle(
                            color: Color(0xFFD6E4FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close  (Esc)',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in kKeyboardShortcutGroups) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Text(
                          group.title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: _primary,
                          ),
                        ),
                      ),
                      ...group.rows.map((r) => _row(r)),
                      const SizedBox(height: 10),
                    ],
                    const Divider(height: 24),
                    Row(
                      children: const [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 16, color: _muted),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: on Mac, use ⌘ (Command) wherever Ctrl is shown.',
                            style: TextStyle(fontSize: 11.5, color: _muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ShortcutRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (int i = 0; i < r.keys.length; i++) ...[
                  _keycap(r.keys[i]),
                  if (i != r.keys.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1),
                      child: Text('+',
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                r.description,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: _ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keycap(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 0,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}
