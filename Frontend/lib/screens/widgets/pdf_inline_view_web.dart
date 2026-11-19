import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// Web implementation: embeds the PDF bytes in a native browser PDF viewer
/// (page thumbnails, zoom, page navigation, download, print) via an iframe
/// pointing at an in-memory blob URL.
Widget buildPdfInlineView(Uint8List bytes) {
  return _PdfIframeView(bytes: bytes);
}

class _PdfIframeView extends StatefulWidget {
  const _PdfIframeView({required this.bytes});

  final Uint8List bytes;

  @override
  State<_PdfIframeView> createState() => _PdfIframeViewState();
}

class _PdfIframeViewState extends State<_PdfIframeView> {
  late final String _viewType;
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'sop-pdf-${DateTime.now().microsecondsSinceEpoch}';

    final blob = html.Blob(<dynamic>[widget.bytes], 'application/pdf');
    _objectUrl = html.Url.createObjectUrlFromBlob(blob);

    final iframe = html.IFrameElement()
      ..src = _objectUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#F4F8FF';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => iframe);
  }

  @override
  void dispose() {
    if (_objectUrl != null) {
      html.Url.revokeObjectUrl(_objectUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
