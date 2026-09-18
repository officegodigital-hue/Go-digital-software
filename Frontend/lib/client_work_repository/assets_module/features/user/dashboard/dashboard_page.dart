import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mock_data.dart';

class UserDashboardPage extends StatefulWidget {
  final void Function(String section)? onOpenSection;

  const UserDashboardPage({
    super.key,
    this.onOpenSection,
  });

  @override
  State<UserDashboardPage> createState() =>
      _UserDashboardPageState();
}

class _UserDashboardPageState
    extends State<UserDashboardPage> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchText =
            _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _digitalMarketingAssets {
    return MockData.assets.where((asset) {
      return asset.section ==
          AppConstants.digitalMarketing;
    }).length;
  }

  int get _softwareDevelopmentAssets {
    return MockData.assets.where((asset) {
      return asset.section ==
          AppConstants.softwareDevelopment;
    }).length;
  }

  int get _digitalMarketingCompanies {
    return MockData.companies.where((company) {
      return company.section ==
          AppConstants.digitalMarketing;
    }).length;
  }

  int get _softwareDevelopmentCompanies {
    return MockData.companies.where((company) {
      return company.section ==
          AppConstants.softwareDevelopment;
    }).length;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 18 : 32,
            isMobile ? 20 : 28,
            isMobile ? 18 : 32,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1100,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(
                    isMobile,
                  ),

                  SizedBox(
                    height: isMobile ? 20 : 24,
                  ),

                  _buildSearchBar(
                    isMobile,
                  ),

                  SizedBox(
                    height: isMobile ? 20 : 28,
                  ),

                  _buildSectionCards(
                    isMobile,
                  ),

                  if (_searchText.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSearchInfo(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // WELCOME SECTION
  // ============================================================

  Widget _buildWelcomeSection(
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: isMobile ? 30 : 36,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 620,
          ),
          child: Text(
            'Access all your marketing and software assets in one place.',
            style: TextStyle(
              fontSize: isMobile ? 15 : 17,
              height: 1.45,
              color:
                  AppColors.textSecondary,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar(
    bool isMobile,
  ) {
    return Container(
      height: isMobile ? 52 : 56,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: TextField(
        controller:
            _searchController,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration:
            const InputDecoration(
          border: InputBorder.none,
          enabledBorder:
              InputBorder.none,
          focusedBorder:
              InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 28,
            color: AppColors.primary,
          ),
          hintText:
              'Search assets, companies...',
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION CARDS
  // ============================================================

  Widget _buildSectionCards(
    bool isMobile,
  ) {
    if (!isMobile) {
      return Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildDigitalMarketingCard(),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: _buildSoftwareDevelopmentCard(),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildDigitalMarketingCard(),

        const SizedBox(height: 16),

        _buildSoftwareDevelopmentCard(),
      ],
    );
  }

  // ============================================================
  // DIGITAL MARKETING CARD
  // ============================================================

  Widget _buildDigitalMarketingCard() {
    final assets =
        _digitalMarketingAssets;

    final companies =
        _digitalMarketingCompanies;

    return _buildSectionCard(
      title:
          AppConstants.digitalMarketing,
      description:
          'Posters, reels, documents, website links and more.',
      assetCount: assets,
      companyCount: companies,
      icon: Icons.campaign_outlined,
      backgroundColor:
          const Color(0xFFF2D8FF),
      iconBackgroundColor:
          const Color(0xFFEED0FF),
      iconColor:
          const Color(0xFF8A00E8),
      onTap: () {
        widget.onOpenSection?.call(
          AppConstants.digitalMarketing,
        );
      },
    );
  }

  // ============================================================
  // SOFTWARE DEVELOPMENT CARD
  // ============================================================

  Widget _buildSoftwareDevelopmentCard() {
    final assets =
        _softwareDevelopmentAssets;

    final companies =
        _softwareDevelopmentCompanies;

    return _buildSectionCard(
      title:
          AppConstants.softwareDevelopment,
      description:
          'Web applications, mobile applications and other software assets.',
      assetCount: assets,
      companyCount: companies,
      icon: Icons.code_outlined,
      backgroundColor:
          const Color(0xFFD7F8EA),
      iconBackgroundColor:
          const Color(0xFFC8F4E1),
      iconColor:
          const Color(0xFF008C63),
      onTap: () {
        widget.onOpenSection?.call(
          AppConstants.softwareDevelopment,
        );
      },
    );
  }

  // ============================================================
  // COMMON SECTION CARD
  // ============================================================

  Widget _buildSectionCard({
    required String title,
    required String description,
    required int assetCount,
    required int companyCount,
    required IconData icon,
    required Color backgroundColor,
    required Color iconBackgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints:
              const BoxConstraints(
            minHeight: 260,
          ),
          padding:
              const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment:
                    Alignment.center,
                decoration: BoxDecoration(
                  color:
                      iconBackgroundColor,
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 35,
                  color: iconColor,
                ),
              ),

              const SizedBox(height: 18),

              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 25,
                  height: 1.15,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                description,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight:
                      FontWeight.w500,
                  color:
                      AppColors.textSecondary,
                ),
              ),

              const Spacer(),

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment:
                          WrapCrossAlignment
                              .center,
                      spacing: 10,
                      runSpacing: 5,
                      children: [
                        Text(
                          '$assetCount Assets',
                          style:
                              const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w800,
                            color: AppColors
                                .textPrimary,
                          ),
                        ),

                        const Text(
                          '•',
                          style:
                              TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w800,
                            color: AppColors
                                .textPrimary,
                          ),
                        ),

                        Text(
                          '$companyCount Companies',
                          style:
                              const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w800,
                            color: AppColors
                                .textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Container(
                    width: 50,
                    height: 50,
                    alignment:
                        Alignment.center,
                    decoration:
                        const BoxDecoration(
                      color:
                          Color(0xFFDCEBFF),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons.arrow_forward,
                      size: 27,
                      color:
                          AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH INFO
  // ============================================================

  Widget _buildSearchInfo() {
    final query =
        _searchController.text.trim();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: AppColors.primary,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Search for "$query" from the asset and company library.',
              style:
                  const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w600,
                color:
                    AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}