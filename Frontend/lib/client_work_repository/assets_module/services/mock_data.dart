import '../core/constants/app_constants.dart';
import '../models/asset_model.dart';
import '../models/company_model.dart';
import '../models/permission_model.dart';
import '../models/user_model.dart';

class MockData {
  MockData._();

  static final companies = <CompanyModel>[
    CompanyModel(id: 'c1', name: 'ABC Company', createdAt: DateTime(2026, 9, 1), updatedAt: DateTime(2026, 9, 7)),
    CompanyModel(id: 'c2', name: 'Tasty Bites', createdAt: DateTime(2026, 8, 28), updatedAt: DateTime(2026, 9, 5)),
    CompanyModel(id: 'c3', name: 'GoDigital', createdAt: DateTime(2026, 8, 20), updatedAt: DateTime(2026, 9, 3)),
    CompanyModel(id: 'c4', name: 'ShopDemo', createdAt: DateTime(2026, 8, 15), updatedAt: DateTime(2026, 9, 1)),
    CompanyModel(id: 'c5', name: 'Portfolio', createdAt: DateTime(2026, 8, 10), updatedAt: DateTime(2026, 9, 4)),
    CompanyModel(id: 'c6', name: 'Client App', createdAt: DateTime(2026, 8, 5), updatedAt: DateTime(2026, 9, 2)),
    CompanyModel(id: 'c7', name: 'Demo Projects', createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 31)),
  ];

  static final assets = <AssetModel>[
    _a('a1','c1','ABC Company',AppConstants.digitalMarketing,AppConstants.poster,'ABC Festival Poster','https://example.com/poster'),
    _a('a2','c1','ABC Company',AppConstants.digitalMarketing,AppConstants.reelVideo,'ABC Promotional Reel','https://example.com/reel'),
    _a('a3','c1','ABC Company',AppConstants.digitalMarketing,AppConstants.document,'ABC Marketing Report','https://example.com/report'),
    _a('a4','c1','ABC Company',AppConstants.digitalMarketing,AppConstants.websiteLink,'ABC Website','https://example.com'),
    _a('a5','c2','Tasty Bites',AppConstants.digitalMarketing,AppConstants.poster,'Food Promotion Poster'),
    _a('a6','c2','Tasty Bites',AppConstants.digitalMarketing,AppConstants.reelVideo,'Food Promotion Reel'),
    _a('a7','c2','Tasty Bites',AppConstants.digitalMarketing,AppConstants.document,'Menu Document'),
    _a('a8','c2','Tasty Bites',AppConstants.digitalMarketing,AppConstants.others,'Festival Content'),
    _a('a9','c3','GoDigital',AppConstants.digitalMarketing,AppConstants.poster,'Social Media Poster'),
    _a('a10','c3','GoDigital',AppConstants.digitalMarketing,AppConstants.websiteLink,'GoDigital Website','https://example.com'),
    _a('a11','c4','ShopDemo',AppConstants.digitalMarketing,AppConstants.poster,'Offer Poster'),
    _a('a12','c5','Portfolio',AppConstants.softwareDevelopment,AppConstants.webApplication,'Portfolio Web Application','https://example.com/portfolio','portfolio_admin','password123'),
    _a('a13','c1','ABC Company',AppConstants.softwareDevelopment,AppConstants.webApplication,'ABC Web Application','https://example.com/abc','abc_admin','password123'),
    _a('a14','c6','Client App',AppConstants.softwareDevelopment,AppConstants.mobileApplication,'Client Mobile App','https://play.google.com/','client_admin','password123'),
    _a('a15','c7','Demo Projects',AppConstants.softwareDevelopment,AppConstants.others,'Demo Software Project'),
  ];

  static final users = <UserModel>[
    UserModel(
      id: 'u1',
      name: 'Admin User',
      email: 'admin@test.com',
      mobile: '9876543210',
      role: 'Admin',
      permissions: PermissionModel(canAdd: true, canEdit: true, canDelete: true),
    ),
    UserModel(
      id: 'u2',
      name: 'Client User',
      email: 'user@test.com',
      mobile: '9876500000',
      role: 'User',
      permissions: PermissionModel(),
    ),
  ];

  static AssetModel _a(
    String id,
    String companyId,
    String company,
    String section,
    String type,
    String name, [
    String? link,
    String? username,
    String? password,
  ]) {
    final day = 1 + int.parse(id.substring(1));
    final date = DateTime(2026, 9, day.clamp(1, 28));
    return AssetModel(
      id: id,
      companyId: companyId,
      companyName: company,
      section: section,
      type: type,
      name: name,
      link: link,
      username: username,
      password: password,
      createdAt: date,
      updatedAt: date,
    );
  }
}
