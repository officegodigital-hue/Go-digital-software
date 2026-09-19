class AssetModel {
  final String id;
  final String companyId;
  final String companyName;
  final String section;
  final String type;
  final String name;
  final String? link;
  final String? username;
  final String? password;
  final DateTime createdAt;
  DateTime updatedAt;
  final String? filePath;

  AssetModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.section,
    required this.type,
    required this.name,
    this.link,
    this.username,
    this.password,
    required this.createdAt,
    required this.updatedAt,
    this.filePath,
  });

  AssetModel copyWith({
    String? id,
    String? companyId,
    String? companyName,
    String? section,
    String? type,
    String? name,
    String? link,
    String? username,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? filePath,
  }) {
    return AssetModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName:
          companyName ?? this.companyName,
      section: section ?? this.section,
      type: type ?? this.type,
      name: name ?? this.name,
      link: link ?? this.link,
      username:
          username ?? this.username,
      password:
          password ?? this.password,
      createdAt:
          createdAt ?? this.createdAt,
      updatedAt:
          updatedAt ?? this.updatedAt,
      filePath:
          filePath ?? this.filePath,
    );
  }
}