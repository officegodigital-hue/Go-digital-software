// Conditional export: picks the web (iframe) or non-web (PdfPreview)
// implementation of buildPdfInlineView at compile time.
export 'pdf_inline_view_stub.dart'
    if (dart.library.html) 'pdf_inline_view_web.dart';
