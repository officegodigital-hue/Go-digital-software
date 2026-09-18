import 'permission_model.dart';

class UserModel {
  final String id;
  String name;
  String email;
  String mobile;
  String role;
  bool active;
  PermissionModel permissions;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.role,
    this.active = true,
    required this.permissions,
  });
}
