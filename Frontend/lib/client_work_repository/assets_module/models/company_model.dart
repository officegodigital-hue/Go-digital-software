class CompanyModel {
  final String id;

  String name;

  final DateTime createdAt;

  DateTime updatedAt;

  // The single section context this model instance was loaded for.
  final String? section;

  // All sections this company belongs to (e.g. both Digital Marketing
  // and Software Development). Populated from the API response.
  final List<String> allSections;

  // Backend company logo path/URL.
  final String? logoUrl;

  CompanyModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.section,
    this.logoUrl,
    List<String>? allSections,
  }) : allSections = allSections ?? (section != null ? [section] : []);

  CompanyModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? section,
    String? logoUrl,
    List<String>? allSections,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      section: section ?? this.section,
      logoUrl: logoUrl ?? this.logoUrl,
      allSections: allSections ?? this.allSections,
    );
  }
}