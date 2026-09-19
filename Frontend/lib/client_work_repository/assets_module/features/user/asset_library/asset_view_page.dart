import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/asset_model.dart';

class AssetViewPage extends StatelessWidget {
  final AssetModel asset;

  const AssetViewPage({
    super.key,
    required this.asset,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isMobile),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 28,
                  vertical: 10,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 850,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),

                        // ==================================================
                        // ASSET TITLE
                        // ==================================================

                        Text(
                          asset.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 34,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF122B78),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ==================================================
                        // PREVIEW
                        // ==================================================

                        _buildPreview(
                          context,
                          isMobile,
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // FILE INFORMATION
                        // ==================================================

                        _buildFileInformation(
                          isMobile,
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // DOWNLOAD
                        // ==================================================

                        _buildDownloadButton(
                          context,
                          isMobile,
                        ),

                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // HEADER
  // ================================================================

  Widget _buildHeader(
    BuildContext context,
    bool isMobile,
  ) {
    return Container(
      height: isMobile ? 64 : 72,
      width: double.infinity,
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(width: 6),

          IconButton(
            tooltip: 'Back',
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 30,
            ),
          ),

          const Spacer(),

          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none,
              color: AppColors.primary,
              size: 30,
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ================================================================
  // PREVIEW
  // ================================================================

  Widget _buildPreview(
    BuildContext context,
    bool isMobile,
  ) {
    switch (asset.type) {
      case AppConstants.poster:
        return _buildPosterPreview(isMobile);

      case AppConstants.reelVideo:
        return _buildVideoPreview(isMobile);

      case AppConstants.document:
        return _buildDocumentPreview(isMobile);

      case AppConstants.websiteLink:
        return _buildWebsitePreview(isMobile);

      case AppConstants.webApplication:
        return _buildWebApplicationPreview(isMobile);

      case AppConstants.mobileApplication:
        return _buildMobileApplicationPreview(isMobile);

      case AppConstants.others:
        return _buildOthersPreview(isMobile);

      default:
        return _buildGenericPreview(isMobile);
    }
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
      return Container(
        width: double.infinity,
        height: isMobile ? 350 : 520,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE1E8F2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          filePath,
          fit: BoxFit.contain,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return _buildPosterPlaceholder();
          },
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: isMobile ? 350 : 520,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E8F2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildPosterPlaceholder(),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1265F4),
            Color(0xFF0A8BFF),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 20,
            child: _circleDecoration(
              75,
              const Color(0x221ffffff),
            ),
          ),

          Positioned(
            right: 20,
            bottom: 20,
            child: _circleDecoration(
              110,
              const Color(0x221ffffff),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 58,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'POSTER PREVIEW',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  asset.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleDecoration(
    double size,
    Color color,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // ================================================================
  // VIDEO
  // ================================================================

  Widget _buildVideoPreview(bool isMobile) {
    return Container(
      width: double.infinity,
      height: isMobile ? 330 : 470,
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E8F2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 56,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'VIDEO PREVIEW',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 25,
              ),
              child: Text(
                asset.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // DOCUMENT
  // ================================================================

  Widget _buildDocumentPreview(bool isMobile) {
    return Container(
      width: double.infinity,
      height: isMobile ? 330 : 470,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E8F2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 105,
              height: 125,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E9),
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.picture_as_pdf_outlined,
                color: Color(0xFFE53935),
                size: 64,
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'DOCUMENT PREVIEW',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _fileName(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // WEBSITE
  // ================================================================

  Widget _buildWebsitePreview(bool isMobile) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.language_outlined,
      iconBackground:
          const Color(0xFFEAF2FF),
      iconColor: AppColors.primary,
      subtitle: 'Website Link',
    );
  }

  // ================================================================
  // WEB APPLICATION
  // ================================================================

  Widget _buildWebApplicationPreview(
    bool isMobile,
  ) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.desktop_windows_outlined,
      iconBackground:
          const Color(0xFFEAF2FF),
      iconColor: AppColors.primary,
      subtitle: 'Web Application',
    );
  }

  // ================================================================
  // MOBILE APPLICATION
  // ================================================================

  Widget _buildMobileApplicationPreview(
    bool isMobile,
  ) {
    return _buildSimplePreviewCard(
      isMobile: isMobile,
      icon: Icons.phone_android_outlined,
      iconBackground:
          const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF199447),
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
      iconBackground:
          const Color(0xFFEAF2FF),
      iconColor: AppColors.primary,
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
      iconBackground:
          const Color(0xFFEAF2FF),
      iconColor: AppColors.primary,
      subtitle: asset.type,
    );
  }

  // ================================================================
  // SIMPLE PREVIEW
  // ================================================================

  Widget _buildSimplePreviewCard({
    required bool isMobile,
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 40,
        vertical: isMobile ? 35 : 50,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E8F2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 105,
            height: 105,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius:
                  BorderRadius.circular(22),
            ),
            child: Icon(
              icon,
              size: 58,
              color: iconColor,
            ),
          ),

          const SizedBox(height: 22),

          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            asset.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),

          if (_hasLink()) ...[
            const SizedBox(height: 14),

            Text(
              asset.link!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================================================================
  // FILE INFORMATION
  // ================================================================

  Widget _buildFileInformation(
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 22 : 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E8F2),
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            title: 'File Name',
            value: _fileName(),
          ),

          _buildInfoRow(
            title: 'Size',
            value: _fileSize(),
          ),

          _buildInfoRow(
            title: 'Uploaded On',
            value: _formatDate(
              asset.createdAt,
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    bool showDivider = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 16,
      ),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE5EAF1),
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // DOWNLOAD BUTTON
  // ================================================================

  Widget _buildDownloadButton(
    BuildContext context,
    bool isMobile,
  ) {
    return SizedBox(
      width: double.infinity,
      height: isMobile ? 58 : 62,
      child: FilledButton.icon(
        onPressed: () {
          _downloadAsset(context);
        },
        icon: const Icon(
          Icons.download_outlined,
          size: 26,
        ),
        label: const Text(
          'Download',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // DOWNLOAD
  // ================================================================

  Future<void> _downloadAsset(
    BuildContext context,
  ) async {
    final rawLink = asset.link?.trim() ?? '';

    if (rawLink.isEmpty) {
      _showMessage(
        context,
        'Download link is not available yet.',
      );
      return;
    }

    var link = rawLink;

    if (!link.startsWith('http://') &&
        !link.startsWith('https://')) {
      link = 'https://$link';
    }

    final uri = Uri.tryParse(link);

    if (uri == null ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      _showMessage(
        context,
        'The download link is not valid.',
      );
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (!opened) {
        _showMessage(
          context,
          'Unable to open the download link.',
        );
      }
    } catch (_) {
      _showMessage(
        context,
        'Unable to open the download link.',
      );
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

    return path
        .split('/')
        .last
        .split('\\')
        .last;
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
    return asset.link != null &&
        asset.link!.trim().isNotEmpty;
  }

  bool _isImageUrl(String value) {
    if (value.isEmpty) {
      return false;
    }

    final lower = value.toLowerCase();

    return (lower.startsWith('http://') ||
            lower.startsWith('https://')) &&
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

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}