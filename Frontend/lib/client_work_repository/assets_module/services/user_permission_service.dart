import '../models/permission_model.dart';

class UserPermissionService {
  UserPermissionService._();

  static PermissionModel currentPermissions =
      PermissionModel();

  static void setPermissions(
    PermissionModel permissions,
  ) {
    currentPermissions = permissions;
  }

  static void reset() {
    currentPermissions =
        PermissionModel();
  }

  static bool get canView =>
      currentPermissions.canView;

  static bool get canDownload =>
      currentPermissions.canDownload;

  static bool get canShare =>
      currentPermissions.canShare;

  static bool get canAdd =>
      currentPermissions.canAdd;

  static bool get canEdit =>
      currentPermissions.canEdit;

  static bool get canDelete =>
      currentPermissions.canDelete;
}