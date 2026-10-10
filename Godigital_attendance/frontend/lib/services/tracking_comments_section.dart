import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'auth_storage.dart';
import 'tracking_comments_api.dart';

class TrackingCommentsSection extends StatefulWidget {
  const TrackingCommentsSection({super.key});

  @override
  State<TrackingCommentsSection> createState() =>
      _TrackingCommentsSectionState();
}

class _TrackingCommentsSectionState extends State<TrackingCommentsSection> {
  final controller = TextEditingController();
  bool saving = false;

  Future<void> _save() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final token = await AuthStorage.getString('auth_token');
    if (token == null || token.isEmpty) return;
    setState(() => saving = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('Turn on location before submitting a comment.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required for comments.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await TrackingCommentsApi.addComment(
        token,
        text,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFFBFF),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFD9E2F2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Comments',
              style: TextStyle(
                color: Color(0xFF061457),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Write a comment',
                labelStyle: const TextStyle(color: Color(0xFF64748B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: const BorderSide(color: Color(0xFFD9E2F2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: const BorderSide(
                    color: Color(0xFF075EF7),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF075EF7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(saving ? 'Saving…' : 'Submit Comment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrackingCommentsHistoryButton extends StatelessWidget {
  const TrackingCommentsHistoryButton({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => const _TrackingCommentsHistoryDialog(),
    ),
    icon: const Icon(Icons.history_rounded, size: 18),
    label: const Text('Comment Section History'),
  );
}

class _TrackingCommentsHistoryDialog extends StatefulWidget {
  const _TrackingCommentsHistoryDialog();
  @override
  State<_TrackingCommentsHistoryDialog> createState() => _TrackingCommentsHistoryDialogState();
}

class _TrackingCommentsHistoryDialogState extends State<_TrackingCommentsHistoryDialog> {
  late Future<List<Map<String, dynamic>>> _history;
  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }
  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final token = await AuthStorage.getString('auth_token');
    if (token == null || token.isEmpty) return const [];
    return TrackingCommentsApi.myComments(token);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Comment Section History'),
    content: SizedBox(
      width: 480,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final comments = snapshot.data ?? const [];
          if (comments.isEmpty) return const Center(child: Text('No comments yet.'));
          return ListView.separated(
            shrinkWrap: true,
            itemCount: comments.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, index) {
              final item = comments[index];
              return ListTile(
                dense: true,
                title: Text('${item['comment'] ?? ''}'),
                subtitle: Text('${item['createdAt'] ?? ''}\n${item['address'] ?? ((item['latitude'] != null && item['longitude'] != null) ? 'GPS: ${item['latitude']}, ${item['longitude']}' : 'Location not recorded')}'),
              );
            },
          );
        },
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
  );
}
