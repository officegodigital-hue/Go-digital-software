// lib/web_stub.dart
class _DummyWindow {
  final _DummySessionStorage sessionStorage = _DummySessionStorage();
  final _DummyUnload onBeforeUnload = _DummyUnload();
  void close() {}
}

class _DummySessionStorage {
  final Map<String, String> _map = {};
  operator [](String key) => _map[key];
  operator []=(String key, String value) => _map[key] = value;
  void remove(String key) => _map.remove(key);
}

class _DummyUnload {
  void listen(Function(dynamic) callback) {}
}

class Blob {
  Blob(List<Object> blobParts, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String? href;
  String? download;
  final _DummyStyle style = _DummyStyle();
  AnchorElement({this.href});
  void click() {}
  void remove() {}
}

class _DummyStyle {
  String? display;
}

class _DummyDocument {
  final _DummyBody? body = _DummyBody();
}

class _DummyBody {
  final _DummyChildren children = _DummyChildren();
}

class _DummyChildren {
  void add(dynamic element) {}
}

class FileUploadInputElement {
  String? accept;
  List<dynamic>? files;
  final _DummyEventStream onChange = _DummyEventStream();
  void click() {}
}

class FileReader {
  dynamic result;
  final _DummyEventStream onLoad = _DummyEventStream();
  void readAsArrayBuffer(dynamic file) {}
}

class _DummyEventStream {
  Future<void> get first async {}
}

final _DummyWindow window = _DummyWindow();
final _DummyDocument document = _DummyDocument();