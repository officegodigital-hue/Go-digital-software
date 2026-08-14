import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import 'link_details_page.dart';

class DeliverableFilesPage extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> files;

  const DeliverableFilesPage({
    super.key,
    required this.title,
    required this.files,
  });

  @override
  State<DeliverableFilesPage> createState() => _DeliverableFilesPageState();
}

class _DeliverableFilesPageState extends State<DeliverableFilesPage> {
  bool selectMode = false;
  final Set<int> selectedIndexes = {};

  String getFileName(Map<String, dynamic> file) {
    final fileName = file['file_name']?.toString() ?? '';
    final title = file['title']?.toString() ?? '';

    if (fileName.isNotEmpty) return fileName;
    if (title.isNotEmpty) return title;

    return 'Uploaded File';
  }

  String getFileUrl(Map<String, dynamic> file) {
    final fileUrl = file['file_url']?.toString() ?? '';
    final link = file['google_drive_link']?.toString() ?? '';

    if (fileUrl.isNotEmpty) return fileUrl;
    return link;
  }

  String getMimeType(Map<String, dynamic> file) {
    return file['mime_type']?.toString().toLowerCase() ?? '';
  }

  bool isImageFile(Map<String, dynamic> file) {
    final fileName = getFileName(file).toLowerCase();
    final mimeType = getMimeType(file);

    return mimeType.startsWith('image/') ||
        fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png') ||
        fileName.endsWith('.webp') ||
        fileName.endsWith('.gif');
  }

  IconData getFileIcon(Map<String, dynamic> file) {
    final fileName = getFileName(file).toLowerCase();
    final mimeType = getMimeType(file);

    if (isImageFile(file)) {
      return Icons.image_outlined;
    }

    if (mimeType.contains('pdf') || fileName.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }

    if (fileName.endsWith('.txt')) {
      return Icons.text_snippet_outlined;
    }

    if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) {
      return Icons.description_outlined;
    }

    if (fileName.endsWith('.xls') || fileName.endsWith('.xlsx')) {
      return Icons.table_chart_outlined;
    }

    if (fileName.endsWith('.mp4') ||
        fileName.endsWith('.mov') ||
        fileName.endsWith('.avi')) {
      return Icons.video_file_outlined;
    }

    if (fileName.endsWith('.zip') || fileName.endsWith('.rar')) {
      return Icons.folder_zip_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  void openFile(Map<String, dynamic> file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LinkDetailsPage(
          deliverable: file,
          displayTitle: getFileName(file),
        ),
      ),
    );
  }

  void toggleSelect(int index) {
    setState(() {
      if (selectedIndexes.contains(index)) {
        selectedIndexes.remove(index);
      } else {
        selectedIndexes.add(index);
      }

      if (selectedIndexes.isEmpty) {
        selectMode = false;
      }
    });
  }

  void selectAll() {
    setState(() {
      selectMode = true;
      selectedIndexes.clear();

      for (int i = 0; i < widget.files.length; i++) {
        selectedIndexes.add(i);
      }
    });
  }

  void clearSelection() {
    setState(() {
      selectedIndexes.clear();
      selectMode = false;
    });
  }

  void shareSelected() {
    if (selectedIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedFiles = selectedIndexes.map((index) {
      final file = widget.files[index];
      final name = getFileName(file);
      final url = getFileUrl(file);

      return '$name\n$url';
    }).join('\n\n');

    final shareText = '''
${widget.title}

$selectedFiles
''';

    Share.share(shareText);
  }

  void shareAll() {
    if (widget.files.isEmpty) return;

    final allFiles = widget.files.map((file) {
      final name = getFileName(file);
      final url = getFileUrl(file);

      return '$name\n$url';
    }).join('\n\n');

    final shareText = '''
${widget.title}

$allFiles
''';

    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            pageHeader(),
            actionHeader(),
            Expanded(
              child: widget.files.isEmpty
                  ? emptyView()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: widget.files.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final file = widget.files[index];
                        return fileTile(file, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget pageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          Expanded(
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget actionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Text(
            '${widget.files.length} file(s)',
            style: const TextStyle(
              color: AppColors.greyText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (selectMode)
            TextButton(
              onPressed: clearSelection,
              child: const Text('Cancel'),
            ),
          TextButton(
            onPressed: selectAll,
            child: const Text('Select All'),
          ),
          TextButton(
            onPressed: selectMode ? shareSelected : shareAll,
            child: Text(selectMode ? 'Share Selected' : 'Share All'),
          ),
        ],
      ),
    );
  }

  Widget fileTile(Map<String, dynamic> file, int index) {
    final fileName = getFileName(file);
    final fileUrl = getFileUrl(file);
    final isImage = isImageFile(file);
    final isSelected = selectedIndexes.contains(index);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (selectMode) {
          toggleSelect(index);
        } else {
          openFile(file);
        }
      },
      onLongPress: () {
        setState(() {
          selectMode = true;
          selectedIndexes.add(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF1FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            if (selectMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                onChanged: (_) => toggleSelect(index),
              ),
              const SizedBox(width: 4),
            ],
            filePreview(file, isImage, fileUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    file['mime_type']?.toString().isNotEmpty == true
                        ? file['mime_type'].toString()
                        : 'Uploaded file',
                    style: const TextStyle(
                      color: AppColors.greyText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!selectMode)
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFB8C0CC),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget filePreview(Map<String, dynamic> file, bool isImage, String fileUrl) {
    if (isImage && fileUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          fileUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return iconPreview(getFileIcon(file));
          },
        ),
      );
    }

    return iconPreview(getFileIcon(file));
  }

  Widget iconPreview(IconData icon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }

  Widget emptyView() {
    return const Center(
      child: Text(
        'No files found',
        style: TextStyle(
          color: AppColors.greyText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}