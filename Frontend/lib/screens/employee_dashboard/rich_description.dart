// lib/screens/employee_dashboard/rich_description.dart
//
// Word-style description box for Website Designer content.
//   • RichDescription.edit(...)  – editor dialog with toolbar (bold, italic,
//     underline, size, colour, highlight, lists, alignment, undo/redo …).
//     Returns (deltaJson, plainText) or null when cancelled.
//   • RichDescription.view(...)  – read-only, scrollable viewer dialog.
//   • RichDescription.preview(...) – small inline plain-text preview.
//
// Stored as a Quill Delta JSON string (column description_rich); the plain
// text is saved alongside so exports and old screens still show something.
//
// Requires in pubspec.yaml:   flutter_quill: ^11.6.0
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

class RichDescription {
  RichDescription._();

  static Document _document(String? deltaJson, String fallbackPlain) {
    final raw = (deltaJson ?? '').trim();
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) return Document.fromJson(decoded);
      } catch (_) {}
    }
    final doc = Document();
    final text = fallbackPlain.trim();
    if (text.isNotEmpty) doc.insert(0, text);
    return doc;
  }

  /// Plain-text version of a stored description (for previews / search).
  static String plainText(String? deltaJson, String fallbackPlain) =>
      _document(deltaJson, fallbackPlain).toPlainText().trim();

  // flutter_quill needs its localizations; wrap locally so the app's
  // MaterialApp does not have to change.
  static Widget _withQuillLocalizations(BuildContext context, Widget child) {
    return Localizations.override(
      context: context,
      delegates: const [FlutterQuillLocalizations.delegate],
      child: child,
    );
  }

  static Future<(String, String)?> edit(
    BuildContext context, {
    required String title,
    String? deltaJson,
    String fallbackPlain = '',
  }) {
    return showDialog<(String, String)>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _withQuillLocalizations(
        dialogContext,
        _RichEditorDialog(
          title: title,
          document: _document(deltaJson, fallbackPlain),
        ),
      ),
    );
  }

  static Future<void> view(
    BuildContext context, {
    required String title,
    String? deltaJson,
    String fallbackPlain = '',
  }) {
    final controller = QuillController(
      document: _document(deltaJson, fallbackPlain),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _withQuillLocalizations(
        dialogContext,
        AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 720,
            height: 480,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: QuillEditor.basic(
                controller: controller,
                config: const QuillEditorConfig(
                  showCursor: false,
                  scrollable: true,
                  expands: true,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final plain = controller.document.toPlainText();
                Navigator.pop(dialogContext);
                // Copy everything as plain text for quick reuse.
                Clipboard.setData(ClipboardData(text: plain.trim()));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Description copied')),
                );
              },
              child: const Text('Copy text'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  /// Compact inline preview with an "Open" action.
  static Widget preview({
    required String? deltaJson,
    required String fallbackPlain,
    required VoidCallback onOpen,
    String emptyLabel = 'Add description…',
    bool editable = false,
    double width = 240,
  }) {
    final text = plainText(deltaJson, fallbackPlain);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.article_outlined, size: 15, color: Color(0xFF004AAD)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text.isEmpty ? emptyLabel : text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: text.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                editable ? Icons.edit_rounded : Icons.open_in_full_rounded,
                size: 13,
                color: const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RichEditorDialog extends StatefulWidget {
  final String title;
  final Document document;

  const _RichEditorDialog({required this.title, required this.document});

  @override
  State<_RichEditorDialog> createState() => _RichEditorDialogState();
}

class _RichEditorDialogState extends State<_RichEditorDialog> {
  late final QuillController _controller = QuillController(
    document: widget.document,
    selection: const TextSelection.collapsed(offset: 0),
  );
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      title: Text(widget.title),
      content: SizedBox(
        width: 860,
        height: 560,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: QuillSimpleToolbar(
                controller: _controller,
                config: const QuillSimpleToolbarConfig(
                  multiRowsDisplay: true,
                  showFontFamily: true,
                  showFontSize: true,
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: true,
                  showColorButton: true,
                  showBackgroundColorButton: true,
                  showClearFormat: true,
                  showHeaderStyle: true,
                  showListNumbers: true,
                  showListBullets: true,
                  showListCheck: true,
                  showAlignmentButtons: true,
                  showIndent: true,
                  showLink: true,
                  showUndo: true,
                  showRedo: true,
                  showCodeBlock: false,
                  showInlineCode: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showSearchButton: false,
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: QuillEditor(
                  controller: _controller,
                  focusNode: _focus,
                  scrollController: _scroll,
                  config: const QuillEditorConfig(
                    placeholder: 'Type the website content here…',
                    expands: true,
                    scrollable: true,
                    autoFocus: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final json = jsonEncode(_controller.document.toDelta().toJson());
            final plain = _controller.document.toPlainText().trim();
            Navigator.pop(context, (json, plain));
          },
          icon: const Icon(Icons.save_rounded, size: 16),
          label: const Text('Save'),
        ),
      ],
    );
  }
}
