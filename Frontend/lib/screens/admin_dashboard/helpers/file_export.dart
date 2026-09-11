// Conditional export: picks the right implementation of saveAndShareFile()
// depending on the platform this app is compiled for.
//
// - Flutter Web            -> file_export_web.dart   (browser download, saves
//                              straight to the PC's Downloads folder)
// - Mobile / Desktop (io)  -> file_export_io.dart     (writes a temp file and
//                              opens the native share/save sheet)
// - Anything else          -> file_export_stub.dart   (safety fallback)
// export 'file_export_stub.dart'
//     if (dart.library.io) 'file_export_io.dart'
//     if (dart.library.html) 'file_export_web.dart';
