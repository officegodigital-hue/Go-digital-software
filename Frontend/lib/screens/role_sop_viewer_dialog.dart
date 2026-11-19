import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import '../services/api_config.dart';
import 'widgets/pdf_inline_view.dart';

class RoleSopViewerDialog extends StatefulWidget {
  const RoleSopViewerDialog({super.key, required this.documents});

  final List<Map<String, dynamic>> documents;

  @override
  State<RoleSopViewerDialog> createState() => _RoleSopViewerDialogState();
}

class _RoleSopViewerDialogState extends State<RoleSopViewerDialog> {
  Map<String, dynamic>? _selected;
  Uint8List? _pdfBytes;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.documents.length == 1) {
      _loadDocument(widget.documents.first);
    }
  }

  Future<void> _loadDocument(Map<String, dynamic> document) async {
    final id = int.tryParse('${document['id'] ?? ''}');
    if (id == null) {
      setState(() => _error = 'This SOP has an invalid document ID.');
      return;
    }
    setState(() {
      _selected = document;
      _pdfBytes = null;
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/role-sops/$id/file'),
        headers: const {'Accept': 'application/pdf'},
      );
      if (response.statusCode != 200) {
        var message = 'Server returned ${response.statusCode}.';
        try {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
      if (mounted) setState(() => _pdfBytes = response.bodyBytes);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to open SOP: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final size = MediaQuery.sizeOf(context);
    // Near full-page, view-only PDF popup with a blue + white theme.
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width - 32,
        height: size.height - 32,
        child: Column(
          children: [
            // Blue header band.
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF0A5BFF), Color(0xFF0742B8)],
                ),
              ),
              child: Row(
                children: [
                  if (selected != null && widget.documents.length > 1)
                    IconButton(
                      tooltip: 'Back to SOP list',
                      color: Colors.white,
                      onPressed: () => setState(() {
                        _selected = null;
                        _pdfBytes = null;
                        _error = null;
                      }),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected == null
                          ? 'Role-Based SOPs'
                          : '${selected['title'] ?? selected['role_name'] ?? 'SOP'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  // Close button in the top-right corner.
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF4F8FF),
                child: _content(selected),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(Map<String, dynamic>? selected) {
    if (selected == null) {
      if (widget.documents.isEmpty) {
        return const Center(child: Text('No SOP is available for your roles.'));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: widget.documents.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final document = widget.documents[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFD8E7FF)),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF2FF),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFF0A5BFF),
                ),
              ),
              title: Text(
                '${document['title'] ?? document['role_name'] ?? 'SOP'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Role: ${document['role_name'] ?? 'Assigned role'}',
              ),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _loadDocument(document),
            ),
          );
        },
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _loadDocument(selected),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final bytes = _pdfBytes;
    if (bytes == null) return const Center(child: Text('PDF is unavailable.'));
    // On web this embeds the browser's native PDF viewer (thumbnails, zoom,
    // page navigation) in an iframe; on desktop/mobile it falls back to a
    // rendered preview. Both avoid SfPdfViewer, which renders blank on web.
    return buildPdfInlineView(bytes);
  }
}
