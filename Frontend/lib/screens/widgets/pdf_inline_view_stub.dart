import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Desktop / mobile fallback: renders the PDF with the `printing` package.
Widget buildPdfInlineView(Uint8List bytes) {
  return PdfPreview(
    build: (_) => bytes,
    useActions: false,
    allowPrinting: false,
    allowSharing: false,
    canChangePageFormat: false,
    canChangeOrientation: false,
    canDebug: false,
    padding: EdgeInsets.zero,
    scrollViewDecoration: const BoxDecoration(color: Color(0xFFF4F8FF)),
    loadingWidget: const Center(child: CircularProgressIndicator()),
  );
}
