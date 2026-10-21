// Conditional export: picks the right saveCalendarFile() for the platform.
//  - Flutter Web           -> calendar_file_save_web.dart  (browser download → Downloads)
//  - Mobile / Desktop (io) -> calendar_file_save_io.dart   (Downloads folder on PC,
//                                                            share/save sheet on phone)
//  - Anything else         -> calendar_file_save_stub.dart
export 'calendar_file_save_stub.dart'
    if (dart.library.io) 'calendar_file_save_io.dart'
    if (dart.library.html) 'calendar_file_save_web.dart';
