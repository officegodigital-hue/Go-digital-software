class AssetModel {
  final String id;
  final String companyId;
  final String companyName;
  final String section;
  final String type;
  final String name;
  final String? description;
  final String? link;
  final String? username;
  final String? password;
  final String? filePath;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final String? createdByEmployeeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Transient: carries picked file bytes back to the caller for upload; never stored in DB.
  final List<int>? pendingFileBytes;

  AssetModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.section,
    required this.type,
    required this.name,
    this.description,
    this.link,
    this.username,
    this.password,
    this.filePath,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.createdByEmployeeId,
    required this.createdAt,
    required this.updatedAt,
    this.pendingFileBytes,
  });

  AssetModel copyWith({
    String? id,
    String? companyId,
    String? companyName,
    String? section,
    String? type,
    String? name,
    String? description,
    String? link,
    String? username,
    String? password,
    String? filePath,
    String? fileName,
    String? mimeType,
    int? fileSize,
    String? createdByEmployeeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssetModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      section: section ?? this.section,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      link: link ?? this.link,
      username: username ?? this.username,
      password: password ?? this.password,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      createdByEmployeeId: createdByEmployeeId ?? this.createdByEmployeeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
