class CompanyModel {
  final String id;

  String name;

  final DateTime createdAt;

  DateTime updatedAt;

  // Stores which Asset Manager section this company belongs to.
  //
  // Example:
  // Digital Marketing
  // Software Development
  final String? section;

  // Backend company logo path/URL.
  //
  // Example:
  // /uploads/company-logos/company-logo-123456.png
  final String? logoUrl;

  CompanyModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.section,
    this.logoUrl,
  });

  CompanyModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? section,
    String? logoUrl,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      section: section ?? this.section,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}