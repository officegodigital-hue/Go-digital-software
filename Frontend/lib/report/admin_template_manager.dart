// lib/report/admin_template_manager.dart
// Admin report-template library: upload multiple PPTX templates, see the slide
// page titles extracted from each, activate one, or delete. The active template
// is what new reports are generated from. Opened from the admin dashboard.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'data/full_report_service.dart';
import 'report_preview_screen.dart';

const _navy = Color(0xff082d61);
const _blue = Color(0xff0866e8);
const _electricBlue = Color(0xff2491ff);
const _paleBlue = Color(0xfff3f7ff);
const _muted = Color(0xff5c6f93);

Future<void> showReportTemplateManager(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: const Color(0xff061b3b).withValues(alpha: .48),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: const _TemplateManager(),
        ),
      ),
    );

class _TemplateManager extends StatefulWidget {
  const _TemplateManager();

  @override
  State<_TemplateManager> createState() => _TemplateManagerState();
}

class _TemplateManagerState extends State<_TemplateManager> {
  final _service = const FullReportService();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _templates = const [];
  List<Map<String, dynamic>> _activePages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final templates = await _service.reportTemplates();
      List<Map<String, dynamic>> pages = const [];
      if (templates.any((t) => t['is_active'] == 1)) {
        pages = await _service.templatePages();
      }
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _activePages = pages;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _upload({String? templateName, bool? activate}) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pptx'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file?.bytes == null || file!.bytes!.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.uploadReportTemplate(
        bytes: file.bytes!,
        fileName: file.name,
        name: templateName ??
            file.name.replaceAll(RegExp(r'\.pptx$', caseSensitive: false), ''),
        activate: activate ?? _templates.isEmpty,
      );
      await _load();
      _toast('Template uploaded.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate(int id) async {
    setState(() => _busy = true);
    try {
      await _service.activateReportTemplate(id);
      await _load();
      _toast('Template activated.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate(int id) async {
    setState(() => _busy = true);
    try {
      await _service.deactivateReportTemplate(id);
      await _load();
      _toast('Template deactivated.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(Map<String, dynamic> template) async {
    final id = (template['id'] as num).toInt();
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ReportPreviewScreen(
            title: template['name']?.toString() ?? 'Report template',
            subtitle: 'Version ${template['version'] ?? 1}',
            loadBytes: () => _service.previewReportTemplateBytes(id),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(Map<String, dynamic> template) async {
    final id = (template['id'] as num).toInt();
    final name = template['original_filename']?.toString() ??
        template['name']?.toString() ??
        'report-template.pptx';
    setState(() => _busy = true);
    try {
      await _service.downloadReportTemplate(id: id, fileName: name);
      _toast('Template download started.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replace(Map<String, dynamic> template) async {
    await _upload(
      templateName: template['name']?.toString(),
      activate: template['is_active'] == 1,
    );
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xffffeded),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 28),
        ),
        title: const Text('Delete template?', style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
        content: Text('Remove "$name" from the template library?', textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.45)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: const BorderSide(color: Color(0xffd5e2f5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd92d42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _service.deleteReportTemplate(id);
      await _load();
      _toast('Template deleted.');
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 14, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_navy, _blue, _electricBlue],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: .3)),
                    ),
                    child: const Icon(Icons.slideshow_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Report Templates', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.3)),
                        SizedBox(height: 4),
                        Text('Manage your presentation layouts', style: TextStyle(color: Color(0xffdceaff), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .12)),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(52),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: _blue)),
                          SizedBox(height: 16),
                          Text('Loading templates…', style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(13),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xfffff1f1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xffffd2d2)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xffd92d42)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xffb42332), height: 1.4))),
                                  IconButton(
                                    tooltip: 'Dismiss',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() => _error = null),
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.all(17),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xfff4f8ff), Color(0xffeaf3ff)]),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xffdbe8ff)),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 440;
                                final description = const Text(
                                  'Upload a PowerPoint template (.pptx) used to generate new reports. Set one template as the default.',
                                  style: TextStyle(color: _muted, height: 1.45, fontSize: 13),
                                );
                                final button = FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                    elevation: 0,
                                  ),
                                  onPressed: _busy ? null : _upload,
                                  icon: _busy
                                      ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.cloud_upload_rounded, size: 19),
                                  label: const Text('Upload .pptx', style: TextStyle(fontWeight: FontWeight.w700)),
                                );
                                if (compact) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [description, const SizedBox(height: 14), Align(alignment: Alignment.centerLeft, child: button)],
                                  );
                                }
                                return Row(
                                  children: [Expanded(child: description), const SizedBox(width: 16), button],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 23),
                          Row(
                            children: [
                              const Expanded(child: Text('Template library', style: TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.w800))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: const Color(0xffeaf2ff), borderRadius: BorderRadius.circular(30)),
                                child: Text('${_templates.length} ${_templates.length == 1 ? 'template' : 'templates'}', style: const TextStyle(color: _blue, fontSize: 11.5, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),
                          if (_templates.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                              decoration: BoxDecoration(
                                color: _paleBlue,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xffdce8fa)),
                              ),
                              child: const Column(
                                children: [
                                  CircleAvatar(radius: 29, backgroundColor: Color(0xffe1edff), child: Icon(Icons.upload_file_rounded, color: _blue, size: 28)),
                                  SizedBox(height: 13),
                                  Text('No templates yet', style: TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 15)),
                                  SizedBox(height: 5),
                                  Text('Upload your first PPTX template to get started.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4)),
                                ],
                              ),
                            )
                          else
                            ..._templates.asMap().entries.map((entry) => FadeTransition(
                                  opacity: const AlwaysStoppedAnimation(1),
                                  child: _templateTile(entry.value, entry.key),
                                )),
                          if (_activePages.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(color: const Color(0xffe8f2ff), borderRadius: BorderRadius.circular(11)),
                                  child: const Icon(Icons.view_carousel_rounded, color: _blue, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text('Active template pages', style: const TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.w800))),
                                Text('${_activePages.length}', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            const Text('Page titles included in the currently active template.', style: TextStyle(color: _muted, fontSize: 12.5)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _activePages.map((p) {
                                final required = p['required_static'] == 1;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: required ? const Color(0xffe8f2ff) : const Color(0xfff4f7fc),
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: required ? const Color(0xff9bc3ff) : const Color(0xffdfe7f3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(required ? Icons.verified_rounded : Icons.article_outlined, size: 15, color: required ? _blue : _muted),
                                      const SizedBox(width: 6),
                                      Text('${p['page_title']}', style: TextStyle(color: required ? _navy : _muted, fontSize: 12, fontWeight: FontWeight.w700)),
                                      if (required) ...[
                                        const SizedBox(width: 5),
                                        const Text('Required', style: TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w800)),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: const BoxDecoration(
                color: Color(0xfff8faff),
                border: Border(top: BorderSide(color: Color(0xffe6edf8))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: _muted, size: 17),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Only the active template is used for new reports.', style: TextStyle(color: _muted, fontSize: 11.5))),
                  TextButton(
                    onPressed: _loading || _busy ? null : _load,
                    style: TextButton.styleFrom(foregroundColor: _blue),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _templateTile(Map<String, dynamic> t, int index) {
    final id = (t['id'] as num).toInt();
    final active =
        t['is_active'] == true || int.tryParse(t['is_active']?.toString() ?? '') == 1;
    final name = t['name']?.toString() ?? t['original_filename']?.toString() ?? 'Template';
    final pages = (t['page_count'] as num?)?.toInt() ?? 0;
    final version = (t['version'] as num?)?.toInt() ?? 1;
    final uploadedAt = DateTime.tryParse(t['created_at']?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: active ? const Color(0xfff1f7ff) : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: active ? const Color(0xff6da7ff) : const Color(0xffe2eaf6), width: active ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: (active ? _blue : _navy).withValues(alpha: active ? .09 : .035),
              blurRadius: active ? 16 : 9,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;
              final icon = Container(
                width: 47,
                height: 51,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: active ? const [_navy, _blue, _electricBlue] : const [Color(0xffedf4ff), Color(0xffdfeaff)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.slideshow_rounded, color: active ? Colors.white : _blue, size: 25),
              );
              final details = Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _navy, fontSize: 13.5)),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.layers_outlined, size: 14, color: _muted),
                          Text('$pages page(s)', style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                          Text('v$version', style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          if (uploadedAt != null)
                            Text(
                              'Uploaded ${uploadedAt.toLocal().toString().split(' ').first}',
                              style: const TextStyle(color: _muted, fontSize: 11.5),
                            ),
                          if (t['original_filename'] != null && t['original_filename'].toString() != name)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 230),
                              child: Text(t['original_filename'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xff8191ae), fontSize: 10.5)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
              final actions = Wrap(
                spacing: 5,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xffe6f5ee)
                          : const Color(0xfff0f3f8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: active
                            ? const Color(0xff16794b)
                            : const Color(0xff667085),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (active)
                    TextButton(
                      onPressed: _busy ? null : () => _deactivate(id),
                      style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        backgroundColor: const Color(0xffeaf2ff),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Deactivate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    )
                  else
                    TextButton(
                      onPressed: _busy ? null : () => _activate(id),
                      style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        backgroundColor: const Color(0xffeaf2ff),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Activate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  IconButton(
                    tooltip: 'Preview template',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : () => _preview(t),
                    icon: const Icon(Icons.visibility_outlined, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Download template',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : () => _download(t),
                    icon: const Icon(Icons.download_rounded, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Upload a new version',
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : () => _replace(t),
                    icon: const Icon(Icons.upload_file_rounded, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Delete template',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xffd92d42),
                      backgroundColor: const Color(0xfffff0f1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    onPressed: _busy ? null : () => _delete(id, name),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Row(children: [icon, details]), const SizedBox(height: 10), Align(alignment: Alignment.centerRight, child: actions)],
                );
              }
              return Row(children: [icon, details, actions]);
            },
          ),
        ),
      ),
    );
  }
}
