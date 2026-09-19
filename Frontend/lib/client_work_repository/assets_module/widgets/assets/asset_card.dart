import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/asset_model.dart';

class AssetCard extends StatelessWidget {
  final AssetModel asset;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AssetCard({
    super.key,
    required this.asset,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.digitalMarketingLight,
          child: Icon(_icon(asset.type), color: AppColors.digitalMarketing),
        ),
        title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${asset.type}  •  ${asset.companyName}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit?.call();
            if (value == 'delete') onDelete?.call();
          },
          itemBuilder: (_) => [
            if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  IconData _icon(String type) {
    if (type.contains('Poster')) return Icons.image_outlined;
    if (type.contains('Reel')) return Icons.video_library_outlined;
    if (type.contains('Document')) return Icons.description_outlined;
    if (type.contains('Website')) return Icons.language_outlined;
    if (type.contains('Application')) return Icons.code;
    return Icons.folder_outlined;
  }
}
