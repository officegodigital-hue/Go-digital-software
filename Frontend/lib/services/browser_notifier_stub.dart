// Not a browser (Android / iOS / desktop): nothing to do.
bool get pageHidden => false;
String get permission => 'unsupported';
Future<String> requestPermission() async => 'unsupported';
void show(String title, String body, {String? tag}) {}
