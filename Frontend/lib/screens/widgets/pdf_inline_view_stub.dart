import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Desktop / mobile PDF viewer.
///
/// Uses Syncfusion's PDF viewer, which bundles its own rendering engine and so
/// opens PDFs that the platform's native renderer (Android's `PdfRenderer`,
/// used by the `printing` package's `PdfPreview`) silently fails to rasterize —
/// that was why some SOP files showed blank on the phone. Web keeps its own
/// iframe viewer (see `pdf_inline_view_web.dart`), so Syncfusion's weaker web
/// rendering is never used here.
Widget buildPdfInlineView(Uint8List bytes) {
  return SfPdfViewer.memory(
    bytes,
    canShowScrollHead: true,
    canShowScrollStatus: true,
    onDocumentLoadFailed: (details) {
      debugPrint('SOP PDF load failed: ${details.error} — ${details.description}');
    },
  );
}
