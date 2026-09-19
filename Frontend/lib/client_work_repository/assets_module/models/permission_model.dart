class PermissionModel {
  bool canView;
  bool canDownload;
  bool canShare;
  bool canAdd;
  bool canEdit;
  bool canDelete;

  PermissionModel({
    this.canView = true,
    this.canDownload = true,
    this.canShare = true,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  PermissionModel copyWith({
    bool? canView,
    bool? canDownload,
    bool? canShare,
    bool? canAdd,
    bool? canEdit,
    bool? canDelete,
  }) {
    return PermissionModel(
      canView: canView ?? this.canView,
      canDownload: canDownload ?? this.canDownload,
      canShare: canShare ?? this.canShare,
      canAdd: canAdd ?? this.canAdd,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
    );
  }
}