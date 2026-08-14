import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../services/repository_service.dart';

class ClientAssetViewPage extends StatefulWidget {
  final int clientId;
  final String clientName;

  const ClientAssetViewPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientAssetViewPage> createState() => _ClientAssetViewPageState();
}

class _ClientAssetViewPageState extends State<ClientAssetViewPage> {
  final RepositoryService repositoryService = RepositoryService();

  bool isLoading = true;
  String errorMessage = '';

  Map<String, dynamic> client = {};
  List<Map<String, dynamic>> deliverables = [];

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  Future<void> loadDetails() async {
    try {
      final data = await repositoryService.getClientAssetDetails(widget.clientId);

      if (!mounted) return;

      setState(() {
        client = Map<String, dynamic>.from(data['client'] ?? {});
        deliverables = List<dynamic>.from(data['deliverables'] ?? [])
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString().replaceAll('Exception:', '').trim();
        isLoading = false;
      });
    }
  }

  String getClientName() {
    return client['client_name']?.toString() ?? widget.clientName;
  }

  String getTypeTitle(String type) {
    switch (type) {
      case 'poster_design':
        return 'Poster Design';
      case 'video':
        return 'Video';
      case 'landing_page':
        return 'Landing Page';
      case 'website':
        return 'Website';
      case 'other_link':
        return 'Other Link';
      case 'packages':
        return 'Packages';
      case 'portfolio':
        return 'Portfolio';
      case 'photos':
        return 'Photos';
      case 'mobile_application':
        return 'Mobile Application';
      case 'website_application':
      case 'web_application':
        return 'Website Application';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  IconData getTypeIcon(String type) {
    switch (type) {
      case 'poster_design':
        return Icons.brush_outlined;
      case 'video':
        return Icons.video_library_outlined;
      case 'landing_page':
        return Icons.insert_drive_file_outlined;
      case 'website':
        return Icons.language;
      case 'other_link':
        return Icons.link;
      case 'packages':
        return Icons.inventory_2_outlined;
      case 'portfolio':
        return Icons.work_outline;
      case 'photos':
        return Icons.photo_library_outlined;
      case 'mobile_application':
        return Icons.phone_android;
      case 'website_application':
      case 'web_application':
        return Icons.web_asset_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  String getFileUrl(Map<String, dynamic> item) {
    final fileUrl = item['file_url']?.toString() ?? '';
    final filePath = item['file_path']?.toString() ?? '';
    final link = item['google_drive_link']?.toString() ?? '';

    if (fileUrl.isNotEmpty) return fileUrl;

    if (filePath.isNotEmpty) {
      return 'http://localhost:5000/$filePath';
    }

    return link;
  }

  String getFileName(Map<String, dynamic> item) {
    final fileName = item['file_name']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';

    if (fileName.isNotEmpty) return fileName;
    if (title.isNotEmpty) return title;

    return 'File';
  }

  bool isImageFile(Map<String, dynamic> item) {
    final fileName = getFileName(item).toLowerCase();
    final mimeType = item['mime_type']?.toString().toLowerCase() ?? '';

    return mimeType.startsWith('image/') ||
        fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png') ||
        fileName.endsWith('.webp') ||
        fileName.endsWith('.gif');
  }

  Future<void> openUrl(String url) async {
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);

    if (uri == null) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  void copyText(String text, String label) {
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(44, 28, 68, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topHeader(),
            const SizedBox(height: 22),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : errorMessage.isNotEmpty
                      ? errorView()
                      : content(),
            ),
          ],
        ),
      ),
    );
  }

  Widget topHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getClientName(),
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${deliverables.length} uploaded item(s)',
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: loadDetails,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
          ),
          icon: const Icon(
            Icons.refresh,
            color: Colors.white,
            size: 16,
          ),
          label: const Text(
            'Refresh',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget content() {
    if (deliverables.isEmpty) {
      return emptyView();
    }

    return ListView.separated(
      itemCount: deliverables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        return deliverableCard(deliverables[index]);
      },
    );
  }

  Widget deliverableCard(Map<String, dynamic> item) {
    final type = item['deliverable_type']?.toString() ?? '';
    final typeTitle = getTypeTitle(type);
    final title = item['title']?.toString() ?? typeTitle;
    final link = getFileUrl(item);
    final description = item['description']?.toString() ?? '';
    final fileName = item['file_name']?.toString() ?? '';
    final mimeType = item['mime_type']?.toString() ?? '';
    final addedOn = item['added_on']?.toString() ?? '';
    final updatedOn = item['updated_on']?.toString() ?? '';

    final adminUrl = item['admin_panel_url']?.toString() ?? '';
    final userEmail = item['user_email']?.toString() ?? '';
    final password = item['password_text']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          previewBox(item),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionBadge(typeTitle, getTypeIcon(type)),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),

                if (fileName.isNotEmpty)
                  detailRow('File Name', fileName, canCopy: true),

                if (mimeType.isNotEmpty)
                  detailRow('File Type', mimeType),

                if (link.isNotEmpty)
                  detailRow(
                    'File / Link',
                    link,
                    isLink: true,
                    canCopy: true,
                  ),

                if (description.isNotEmpty)
                  detailRow('Description', description),

                if (adminUrl.isNotEmpty)
                  detailRow(
                    'Admin Panel URL',
                    adminUrl,
                    isLink: true,
                    canCopy: true,
                  ),

                if (userEmail.isNotEmpty)
                  detailRow('User Email', userEmail, canCopy: true),

                if (password.isNotEmpty)
                  detailRow('Password', password, canCopy: true),

                if (addedOn.isNotEmpty) detailRow('Added On', addedOn),

                if (updatedOn.isNotEmpty) detailRow('Updated On', updatedOn),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget previewBox(Map<String, dynamic> item) {
    final link = getFileUrl(item);
    final type = item['deliverable_type']?.toString() ?? '';

    if (isImageFile(item) && link.isNotEmpty) {
      return InkWell(
        onTap: () => openUrl(link),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            link,
            width: 160,
            height: 130,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return fileIconBox(getTypeIcon(type));
            },
          ),
        ),
      );
    }

    return InkWell(
      onTap: link.isEmpty ? null : () => openUrl(link),
      child: fileIconBox(getTypeIcon(type)),
    );
  }

  Widget fileIconBox(IconData icon) {
    return Container(
      width: 160,
      height: 130,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(
        icon,
        color: AppColors.primary,
        size: 48,
      ),
    );
  }

  Widget sectionBadge(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget detailRow(
    String label,
    String value, {
    bool isLink = false,
    bool canCopy = false,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Text(
            ':',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: isLink ? () => openUrl(value) : null,
              child: Text(
                value,
                style: TextStyle(
                  color: isLink ? AppColors.primary : AppColors.textDark,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (canCopy)
            IconButton(
              onPressed: () => copyText(value, label),
              icon: const Icon(
                Icons.copy,
                size: 15,
                color: AppColors.textGrey,
              ),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }

  Widget emptyView() {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              color: AppColors.textGrey,
              size: 42,
            ),
            SizedBox(height: 14),
            Text(
              'No details found',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Uploaded client details will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget errorView() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}