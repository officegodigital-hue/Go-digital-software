// lib/report/report_preview_screen.dart
//
// A view-only, on-screen report preview. Renders the report PDF inline using
// the shared cross-platform `buildPdfInlineView` helper (iframe on web,
// PdfPreview on desktop/mobile). Nothing is downloaded or saved — this is a
// pure "look at the report" surface.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../screens/widgets/pdf_inline_view.dart';
import 'report_brand.dart';

const _navy = Color(0xFF142F61);
const _muted = Color(0xFF64748B);
const _bg = Color(0xFFF4F7FC);

class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({
    super.key,
    required this.title,
    required this.loadBytes,
    this.subtitle,
    this.embedded = false,
  });

  /// Shown as the app-bar title (usually the client name).
  final String title;

  /// Optional second line (usually the report month / period).
  final String? subtitle;

  /// Lazily loads the PDF bytes to display. Called on open and on retry.
  final Future<Uint8List> Function() loadBytes;

  /// True when opened inside the report shell (top bar + back provided there),
  /// so this screen omits its own AppBar and shows a slim in-body title.
  final bool embedded;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadBytes();
  }

  void _retry() {
    final nextPreview = widget.loadBytes();
    setState(() => _future = nextPreview);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: widget.embedded
          ? null
          : AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0.5,
        titleSpacing: 8,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoDigitalLogo(size: 32, radius: 9, padding: 5),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  if ((widget.subtitle ?? '').isNotEmpty)
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: widget.embedded
          ? Column(
              children: [
                _embeddedTitleStrip(),
                Expanded(child: _viewer()),
              ],
            )
          : _viewer(),
    );
  }

  // Slim in-body title shown when the shell supplies the top bar + back.
  Widget _embeddedTitleStrip() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 18, color: _navy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [widget.title, if ((widget.subtitle ?? '').isNotEmpty) widget.subtitle!]
                  .join('  •  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewer() {
    return FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: _muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return const Center(child: Text('Report preview is unavailable.'));
          }
          // Cross-platform inline PDF view (no download / print / share).
          return buildPdfInlineView(bytes);
        },
      );
  }
}
