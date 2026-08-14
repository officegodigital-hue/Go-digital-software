import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';

class LinkDetailsPage extends StatelessWidget {
  final Map<String, dynamic> deliverable;
  final String displayTitle;

  const LinkDetailsPage({
    super.key,
    required this.deliverable,
    required this.displayTitle,
  });

  String value(String key) {
    return deliverable[key]?.toString().trim() ?? '';
  }

  String extractFromDescription(String label) {
    final description = value('description');
    final lines = description.split('\n');

    for (final line in lines) {
      final cleanLine = line.trim().toLowerCase();
      final cleanLabel = label.toLowerCase();

      if (cleanLine.startsWith(cleanLabel)) {
        final parts = line.split(':');

        if (parts.length > 1) {
          return parts.sublist(1).join(':').trim();
        }
      }
    }

    return '';
  }

  bool isSoftwareItem() {
    final type = value('deliverable_type').toLowerCase();
    final title = displayTitle.toLowerCase();

    return type.contains('mobile_application') ||
        type.contains('website_application') ||
        type.contains('web_application') ||
        title.contains('mobile application') ||
        title.contains('website application') ||
        title.contains('web application');
  }

  bool isMobileApplication() {
    final type = value('deliverable_type').toLowerCase();
    final title = displayTitle.toLowerCase();

    return type.contains('mobile') || title.contains('mobile');
  }

  bool isWebsiteApplication() {
    final type = value('deliverable_type').toLowerCase();
    final title = displayTitle.toLowerCase();

    return type.contains('website') ||
        type.contains('web_application') ||
        title.contains('website') ||
        title.contains('web application');
  }

  String finalLink() {
    final fileUrl = value('file_url');
    final link = value('google_drive_link');

    if (fileUrl.isNotEmpty) return fileUrl;
    return link;
  }

  String fileName() {
    final fileName = value('file_name');
    if (fileName.isNotEmpty) return fileName;

    return displayTitle;
  }

  String shareText() {
    final adminUrl = value('admin_panel_url');
    final userEmail = value('user_email');
    final password = value('password_text');

    if (isMobileApplication()) {
      final androidLink = finalLink();
      final iosLink = extractFromDescription('IOS Link');

      return '''
Mobile Application Details

Android URL:
${androidLink.isEmpty ? '-' : androidLink}

iOS URL:
${iosLink.isEmpty ? '-' : iosLink}

Admin Panel URL:
${adminUrl.isEmpty ? '-' : adminUrl}

User Email:
${userEmail.isEmpty ? '-' : userEmail}

Password:
${password.isEmpty ? '-' : password}
''';
    }

    if (isWebsiteApplication()) {
      final websiteUrl = finalLink();

      return '''
Website Application Details

Website Application URL:
${websiteUrl.isEmpty ? '-' : websiteUrl}

Admin Panel URL:
${adminUrl.isEmpty ? '-' : adminUrl}

User Email:
${userEmail.isEmpty ? '-' : userEmail}

Password:
${password.isEmpty ? '-' : password}
''';
    }

    return '''
$displayTitle

File/Link:
${finalLink().isEmpty ? '-' : finalLink()}

File Name:
${fileName()}

Description:
${value('description').isEmpty ? '-' : value('description')}
''';
  }

  @override
  Widget build(BuildContext context) {
    if (isSoftwareItem()) {
      return softwareDetailsPage(context);
    }

    return normalFileDetailsPage(context);
  }

  Widget softwareDetailsPage(BuildContext context) {
    final adminUrl = value('admin_panel_url');
    final userEmail = value('user_email');
    final password = value('password_text');

    final androidLink = finalLink();
    final iosLink = extractFromDescription('IOS Link');

    final websiteUrl = finalLink();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            pageHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  children: [
                    softwareIcon(),
                    const SizedBox(height: 22),
                    Text(
                      isMobileApplication()
                          ? 'Mobile Application'
                          : 'Website Application',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Application Login Details',
                      style: TextStyle(
                        color: AppColors.greyText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 26),

                    if (isMobileApplication()) ...[
                      detailBox(
                        context: context,
                        label: 'ANDROID URL',
                        valueText: androidLink,
                        isLink: true,
                      ),
                      const SizedBox(height: 14),
                      detailBox(
                        context: context,
                        label: 'iOS URL',
                        valueText: iosLink,
                        isLink: true,
                      ),
                    ],

                    if (isWebsiteApplication()) ...[
                      detailBox(
                        context: context,
                        label: 'WEBSITE APPLICATION URL',
                        valueText: websiteUrl,
                        isLink: true,
                      ),
                    ],

                    const SizedBox(height: 14),
                    detailBox(
                      context: context,
                      label: 'ADMIN PANEL URL',
                      valueText: adminUrl,
                      isLink: true,
                    ),
                    const SizedBox(height: 14),
                    detailBox(
                      context: context,
                      label: 'USER EMAIL',
                      valueText: userEmail,
                    ),
                    const SizedBox(height: 14),
                    detailBox(
                      context: context,
                      label: 'PASSWORD',
                      valueText: password,
                    ),
                  ],
                ),
              ),
            ),
            bottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget normalFileDetailsPage(BuildContext context) {
    final link = finalLink();
    final description = value('description');
    final addedOn = value('added_on').isNotEmpty ? value('added_on') : value('updated_on');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            pageHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  children: [
                    filePreview(link),
                    const SizedBox(height: 22),
                    Text(
                      displayTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 22),
                    detailBox(
                      context: context,
                      label: 'FILE / LINK',
                      valueText: link,
                      isLink: true,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      detailBox(
                        context: context,
                        label: 'DESCRIPTION',
                        valueText: description,
                      ),
                    ],
                    if (addedOn.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      detailBox(
                        context: context,
                        label: 'ADDED ON',
                        valueText: addedOn,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            bottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget pageHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          const Expanded(
            child: Text(
              'Link Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget softwareIcon() {
    return CircleAvatar(
      radius: 44,
      backgroundColor: const Color(0xFFEAF1FF),
      child: Icon(
        isMobileApplication() ? Icons.phone_android : Icons.web_asset_outlined,
        color: AppColors.primary,
        size: 42,
      ),
    );
  }

  Widget filePreview(String link) {
    final name = fileName().toLowerCase();

    final isImage = name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif');

    if (isImage && link.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          link,
          width: double.infinity,
          height: 260,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return defaultFileIcon();
          },
        ),
      );
    }

    return defaultFileIcon();
  }

  Widget defaultFileIcon() {
    return CircleAvatar(
      radius: 44,
      backgroundColor: const Color(0xFFEAF1FF),
      child: Container(
        width: 56,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(
          Icons.folder,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget detailBox({
    required BuildContext context,
    required String label,
    required String valueText,
    bool isLink = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isLink && valueText.isNotEmpty
                  ? () => openUrl(valueText)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.greyText,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    valueText.isEmpty ? '-' : valueText,
                    style: TextStyle(
                      color: isLink ? AppColors.primary : AppColors.darkText,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: valueText.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: valueText));

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied'),
                      ),
                    );
                  },
            icon: const Icon(
              Icons.copy,
              size: 17,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget bottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
      child: Row(
        children: [
          Expanded(
            child: actionButton(
              title: 'Share',
              color: AppColors.primary,
              textColor: Colors.white,
              onTap: () {
                Share.share(shareText());
              },
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: actionButton(
              title: 'Copy',
              color: const Color(0xFFE9EEF5),
              textColor: AppColors.darkText,
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(text: shareText()),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied successfully'),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget actionButton({
    required String title,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}