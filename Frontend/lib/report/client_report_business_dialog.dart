import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/auth/auth_session.dart';

/// Starts a client report with a simple company label. A report can be made
/// for a prospect that is not yet present in the company directory, so this
/// deliberately has no business-search autocomplete or address requirement.
Future<Map<String, dynamic>?> showClientReportBusinessDialog(
  BuildContext context,
) async {
  final name = TextEditingController();
  final savedCompanies = await _savedClientCompanies();
  XFile? logo;
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: const Text('Clients Full Report'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Create a client profile', style: TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          Autocomplete<String>(
            optionsBuilder: (value) => value.text.trim().isEmpty ? const Iterable<String>.empty() : savedCompanies.where((company) => company.toLowerCase().contains(value.text.toLowerCase())),
            onSelected: (company) async { name.text = company; Navigator.pop(dialogContext, await _clientReportSelection(company)); },
            fieldViewBuilder: (_, controller, focusNode, __) { controller.text = name.text; controller.selection = TextSelection.collapsed(offset: controller.text.length); return TextField(controller: controller, focusNode: focusNode, autofocus: true, textCapitalization: TextCapitalization.words, onChanged: (value) => name.text = value, decoration: const InputDecoration(labelText: 'Client business name', hintText: 'Type to find or create company', border: OutlineInputBorder())); },
          ),
          const SizedBox(height: 12),
          Row(children: [
            const CircleAvatar(radius: 22, child: Icon(Icons.business_outlined)),
            const SizedBox(width: 12),
            Expanded(child: Text(logo == null ? 'Optional company logo' : 'Company logo selected')),
            TextButton.icon(onPressed: () async { final selected = await ImagePicker().pickImage(source: ImageSource.gallery); if (selected != null) setDialogState(() => logo = selected); }, icon: const Icon(Icons.upload_outlined), label: Text(logo == null ? 'Add logo' : 'Change')),
          ]),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final companyName = name.text.trim();
            if (companyName.isNotEmpty) {
              final selection = await _clientReportSelection(companyName);
              if (logo != null) {
                selection['companyLogoBase64'] = base64Encode(await logo!.readAsBytes());
                selection['companyLogoMimeType'] = logo!.mimeType ?? 'image/png';
                final savedLogo = await _saveClientLogo(companyName, selection['companyLogoBase64']!, selection['companyLogoMimeType']!);
                if (!savedLogo && context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save the company logo.'))); return; }
              }
              Navigator.pop(dialogContext, selection);
            }
          },
          child: const Text('Continue'),
        ),
      ],
    )),
  );
  name.dispose();
  return result;
}

Future<bool> _saveClientLogo(String companyName, String logoBase64, String mimeType) async {
  const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  try {
    final response = await http.put(Uri.parse('$base/api/report-export/client-profile'), headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}', 'Content-Type': 'application/json'}, body: jsonEncode({'companyName': companyName, 'logoBase64': logoBase64, 'logoMimeType': mimeType}));
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) { return false; }
}

Future<List<String>> _savedClientCompanies() async {
  const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  try {
    final response = await http.get(Uri.parse('$base/api/report-export/client-companies'), headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'});
    final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    return body['companies'] is List ? (body['companies'] as List).map((item) => item.toString()).toList() : <String>[];
  } catch (_) { return <String>[]; }
}


Future<Map<String, dynamic>> _clientReportSelection(String companyName) async {
  final now = DateTime.now();
  final base = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  try {
    final uri = Uri.parse('$base/api/report-export/client-history').replace(queryParameters: {'companyName': companyName});
    final response = await http.get(uri, headers: {'Authorization': 'Bearer ${AuthSession.requireToken()}'});
    final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'name': companyName,
      'reportMonth': now.month,
      'reportYear': now.year,
      'existingReports': body['reports'] is List ? body['reports'] : <dynamic>[],
      if (body['companyLogoBase64'] != null) 'companyLogoBase64': body['companyLogoBase64'],
      if (body['companyLogoMimeType'] != null) 'companyLogoMimeType': body['companyLogoMimeType'],
    };
  } catch (_) {
    return {'name': companyName, 'reportMonth': now.month, 'reportYear': now.year, 'existingReports': <dynamic>[]};
  }
}
