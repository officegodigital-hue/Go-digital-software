import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../models/asset_model.dart';

class AssetViewPage extends StatelessWidget {
  final AssetModel asset;

  const AssetViewPage({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;
    // Keep the preview inside the viewport on laptop screens.
    final previewHeight = isMobile
        ? 300.0
        : (size.height - 250).clamp(300.0, 520.0);

    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: SafeArea(
        child: PremiumPage(
          maxWidth: 1200,
          builder: (context, bp) => [
            Reveal(child: _buildHeader(context, isMobile)),
            SizedBox(height: bp.gap),
            LayoutBuilder(
              builder: (context, box) {
                final preview = Reveal(
                  delay: const Duration(milliseconds: 120),
                  child: _buildPreview(context, isMobile, previewHeight),
                );
                final details = Reveal(
                  delay: const Duration(milliseconds: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFileInformation(isMobile),
                      const SizedBox(height: 12),
                      _buildDownloadButton(context, isMobile),
                    ],
                  ),
                );
                if (box.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      preview,
                      SizedBox(height: bp.gap),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: preview),
                    SizedBox(width: bp.gap),
                    Expanded(flex: 2, child: details),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // HEADER
  // ================================================================

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PremiumIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'Assets',
              style: TextStyle(fontSize: 13, color: PremiumColors.muted),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: PremiumColors.faint,
              ),
            ),
            Expanded(
              child: Text(
                asset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PremiumColors.ink,
                ),
              ),
            ),
            PremiumIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        PremiumHero(
          compact: isMobile,
          eyebrow: _typeLabel(),
          eyebrowIcon: _typeIcon(),
          title: asset.name,
          subtitle: [
            if (asset.companyName.isNotEmpty) asset.companyName,
            if (asset.section.isNotEmpty) asset.section,
            'Uploaded ${_formatDate(asset.createdAt)}',
          ].join('  ·  '),
        ),
      ],
    );
  }

  String _typeLabel() => switch (asset.type) {
    AppConstants.poster => 'Poster',
    AppConstants.reelVideo => 'Reel video',
    AppConstants.document => 'Document',
    AppConstants.websiteLink => 'Website link',
    AppConstants.webApplication => 'Web application',
    AppConstants.mobileApplication => 'Mobile application',
    AppConstants.others => 'Other asset',
    _ => asset.type,
  };

  IconData _typeIcon() => switch (asset.type) {
    AppConstants.poster => Icons.image_outlined,
    AppConstants.reelVideo => Icons.play_circle_outline_rounded,
    AppConstants.document => Icons.description_outlined,
    AppConstants.websiteLink => Icons.language_outlined,
    AppConstants.webApplication => Icons.desktop_windows_outlined,
    AppConstants.mobileApplication => Icons.phone_android_outlined,
    _ => Icons.folder_outlined,
  };

  // ================================================================
  // PREVIEW
  // ================================================================

  Widget _buildPreview(BuildContext context, bool isMobile, double height) {
    final Widget child;
    switch (asset.type) {
      case AppConstants.poster:
        child = _buildPosterPreview(isMobile);

      case AppConstants.reelVideo:
        child = _buildVideoPreview(isMobile);

      case AppConstants.document:
        child = _buildDocumentPreview(isMobile);

      case AppConstants.websiteLink:
        child = _buildWebsitePreview(isMobile);

      case AppConstants.webApplication:
        child = _buildWebApplicationPreview(isMobile);

      case AppConstants.mobileApplication:
        child = _buildMobileApplicationPreview(isMobile);

      case AppConstants.others:
        child = _buildOthersPreview(isMobile);

      default:
        child = _buildGenericPreview(isMobile);
    }
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PremiumColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1E40AF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  // ================================================================
  // POSTER
  // ================================================================

  Widget _buildPosterPreview(bool isMobile) {
    final filePath = asset.filePath?.trim() ?? '';

    /*
     * If later filePath contains a real public image URL,
     * the actual poster will automatically appear here.
     */

    if (_isImageUrl(filePath)) {
      return ColoredBox(
        color: PremiumColors.surface,
        child: Image.network(
          filePath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildPosterPlaceholder();
          },
        ),
      );
    }

    return _buildPosterPlaceholder();
  }

  Widget _buildPosterPlaceholder() {
    return _gradientPreview(
      icon: Icons.image_outlined,
      label: 'POSTER PREVIEW',
      detail: asset.name,
    );
  }

  /// Blue gradient stage with a floating icon, shared by the media previews.
  Widget _gradientPreview({
    required IconData icon,
    required String label,
    required String detail,
    bool round = false,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: PremiumColors.heroGradient),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -30,
            child: _circleDecoration(140, const Color(0x1AFFFFFF)),
          ),
          Positioned(
            right: -40,
            bottom: -50,
            child: _circleDecoration(200, const Color(0x2238BDF8)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumFloat(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: round ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: round ? null : BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000F3D),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 44, color: PremiumColors.blue),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xD9FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleDecoration(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ================================================================
  // VIDEO
  // ================================================================

  Widget _buildVideoPreview(bool isMobile) {
    return _gradientPreview(
      icon: Icons.play_arrow_rounded,
      label: 'VIDEO PREVIEW',
      detail: asset.name,
      round: true,
    );
  }

  // ================================================================
  // DOCUMENT
  // ================================================================

  Widget _buildDocumentPreview(bool isMobile) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.picture_as_pdf_outlined,
      accent: PremiumAccent.violet,
      subtitle: 'Document',
      detail: _fileName(),
    );
  }

  // ================================================================
  // WEBSITE
  // ================================================================

  Widget _buildWebsitePreview(bool isMobile) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.language_outlined,
      accent: PremiumAccent.blue,
      subtitle: 'Website Link',
    );
  }

  // ================================================================
  // WEB APPLICATION
  // ================================================================

  Widget _buildWebApplicationPreview(bool isMobile) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.desktop_windows_outlined,
      accent: PremiumAccent.cyan,
      subtitle: 'Web Application',
    );
  }

  // ================================================================
  // MOBILE APPLICATION
  // ================================================================

  Widget _buildMobileApplicationPreview(bool isMobile) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.phone_android_outlined,
      accent: PremiumAccent.green,
      subtitle: 'Mobile Application',
    );
  }

  // ================================================================
  // OTHERS
  // ================================================================

  Widget _buildOthersPreview(bool isMobile) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.folder_outlined,
      accent: PremiumAccent.amber,
      subtitle: 'Other Asset',
    );
  }

  // ================================================================
  // GENERIC
  // ================================================================

  Widget _buildGenericPreview(bool isMobile) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.insert_drive_file_outlined,
      accent: PremiumAccent.blue,
      subtitle: asset.type,
    );
  }

  // ================================================================
  // SIMPLE PREVIEW
  // ================================================================

  Widget _buildSimplePreviewCard({
    required bool isMobile,
    required IconData icon,
    required PremiumAccent accent,
    required String subtitle,
    String? detail,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.soft, Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 36,
            vertical: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumFloat(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: accent.gradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: accent.start.withAlpha(70),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: PremiumColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                detail ?? asset.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: PremiumColors.muted,
                ),
              ),
              if (_hasLink()) ...[
                const SizedBox(height: 12),
                PremiumBadge(
                  label: asset.link!,
                  icon: Icons.link_rounded,
                  accent: accent,
                  maxWidth: 420,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // FILE INFORMATION
  // ================================================================

  Widget _buildFileInformation(bool isMobile) {
    return PremiumPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'File details',
            icon: Icons.info_outline_rounded,
            compact: true,
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            icon: Icons.insert_drive_file_outlined,
            title: 'File Name',
            value: _fileName(),
          ),
          _buildInfoRow(
            icon: Icons.sd_storage_outlined,
            title: 'Size',
            value: _fileSize(),
          ),
          _buildInfoRow(
            icon: Icons.event_outlined,
            title: 'Uploaded On',
            value: _formatDate(asset.createdAt),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    bool showDivider = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: PremiumColors.rowLine)),
            )
          : null,
      child: Row(
        children: [
          PremiumIconTile(icon: icon, accent: PremiumAccent.blue, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: PremiumColors.tableHeaderStyle,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PremiumColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // DOWNLOAD BUTTON
  // ================================================================

  Widget _buildDownloadButton(BuildContext context, bool isMobile) {
    return SizedBox(
      height: 48,
      child: PremiumButton(
        label: 'Download',
        icon: Icons.download_rounded,
        iconLeading: true,
        expand: true,
        onPressed: () {
          _downloadAsset(context);
        },
      ),
    );
  }

  // ================================================================
  // DOWNLOAD
  // ================================================================

  Future<void> _downloadAsset(BuildContext context) async {
    final rawLink = asset.link?.trim() ?? '';

    if (rawLink.isEmpty) {
      _showMessage(context, 'Download link is not available yet.');
      return;
    }

    var link = rawLink;

    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      link = 'https://$link';
    }

    final uri = Uri.tryParse(link);

    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showMessage(context, 'The download link is not valid.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);

      if (!opened) {
        _showMessage(context, 'Unable to open the download link.');
      }
    } catch (_) {
      _showMessage(context, 'Unable to open the download link.');
    }
  }

  // ================================================================
  // HELPERS
  // ================================================================

  String _fileName() {
    final path = asset.filePath?.trim() ?? '';

    if (path.isEmpty) {
      return '${asset.name}.file';
    }

    return path.split('/').last.split('\\').last;
  }

  String _fileSize() {
    /*
     * The current AssetModel does not yet store
     * the actual file size.
     *
     * When Google Drive/backend storage is connected,
     * this will be replaced by the actual size.
     */
    return 'File size available after upload';
  }

  bool _hasLink() {
    return asset.link != null && asset.link!.trim().isNotEmpty;
  }

  bool _isImageUrl(String value) {
    if (value.isEmpty) {
      return false;
    }

    final lower = value.toLowerCase();

    return (lower.startsWith('http://') || lower.startsWith('https://')) &&
        (lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp'));
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}
