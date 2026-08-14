import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../../core/constants/app_colors.dart';
import '../../core/layout/admin_layout.dart';
import '../../services/repository_service.dart';

class ClientAssetEditPage extends StatefulWidget {
  final int clientId;
  final String clientName;

  const ClientAssetEditPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientAssetEditPage> createState() => _ClientAssetEditPageState();
}

class _ClientAssetEditPageState extends State<ClientAssetEditPage> {
  final RepositoryService repositoryService = RepositoryService();

  bool isLoading = true;
  bool isSaving = false;

  final TextEditingController clientNameController = TextEditingController();
  final TextEditingController shortNameController = TextEditingController();

  final List<int> deletedDeliverableIds = [];

  late Map<String, AssetEditSection> sections;

  final List<AssetEditSection> extraOtherLinkSections = [];
  final List<AssetEditSection> extraMobileApplicationSections = [];
  final List<AssetEditSection> extraPortfolioSections = [];
  final List<AssetEditSection> extraPhotoSections = [];

  @override
  void initState() {
    super.initState();
    initSections();
    loadEditData();
  }

  void initSections() {
    sections = {
      'poster_design': AssetEditSection(
        type: 'poster_design',
        title: 'Poster Design',
        icon: Icons.brush_outlined,
      ),
      'video': AssetEditSection(
        type: 'video',
        title: 'Video',
        icon: Icons.videocam_outlined,
      ),
      'packages': AssetEditSection(
        type: 'packages',
        title: 'Packages',
        icon: Icons.description_outlined,
        isFileSection: true,
      ),
      'portfolio': AssetEditSection(
        type: 'portfolio',
        title: 'APK File Upload',
        icon: Icons.android_outlined,
        isFileSection: true,
      ),
      'landing_page': AssetEditSection(
        type: 'landing_page',
        title: 'Landing Page',
        icon: Icons.insert_drive_file_outlined,
      ),
      'website': AssetEditSection(
        type: 'website',
        title: 'Website',
        icon: Icons.language,
      ),
      'other_link': AssetEditSection(
        type: 'other_link',
        title: 'Other Link',
        icon: Icons.link,
      ),
      'mobile_application': AssetEditSection(
        type: 'mobile_application',
        title: 'Mobile Application',
        icon: Icons.phone_android,
        isMobileApplication: true,
      ),
      'website_application': AssetEditSection(
        type: 'website_application',
        title: 'Website Application',
        icon: Icons.web_asset_outlined,
        isWebsiteApplication: true,
      ),
      'photos': AssetEditSection(
        type: 'photos',
        title: 'Photos',
        icon: Icons.image_outlined,
        isFileSection: true,
      ),
    };
  }

  Future<void> loadEditData() async {
    try {
      final details = await repositoryService.getClientDetails(widget.clientId);

      final Map<String, dynamic> client =
          Map<String, dynamic>.from(details['client'] ?? {});

      final List<Map<String, dynamic>> deliverables =
          List<dynamic>.from(details['deliverables'] ?? [])
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

      deliverables.sort((a, b) {
        final aId = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        final bId = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
        return aId.compareTo(bId);
      });

      clientNameController.text = client['client_name']?.toString() ?? '';
      shortNameController.text = client['short_name']?.toString() ?? '';

      for (final asset in deliverables) {
        final type = normalizeType(asset['deliverable_type']?.toString() ?? '');
        final section = sections[type];

        if (section == null) continue;

        if (section.isFileSection) {
          loadFileAsset(type, asset);
          continue;
        }

        if (type == 'other_link' && section.hasLoadedData()) {
          final extra = createOtherLinkSection();
          fillSection(extra, asset);
          extraOtherLinkSections.add(extra);
          continue;
        }

        if (type == 'mobile_application' && section.hasLoadedData()) {
          final extra = createMobileApplicationSection();
          fillSection(extra, asset);
          extraMobileApplicationSections.add(extra);
          continue;
        }

        fillSection(section, asset);
      }

      refreshExtraTitles();

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(error.toString(), Colors.red);
    }
  }

  String normalizeType(String type) {
    final value = type.trim().toLowerCase();

    switch (value) {
      case 'poster-design':
      case 'poster design':
        return 'poster_design';

      case 'landing-page':
      case 'landing page':
        return 'landing_page';

      case 'other-link':
      case 'other link':
        return 'other_link';

      case 'mobile-application':
      case 'mobile application':
      case 'mobile_app':
      case 'mobile-app':
      case 'mobile app':
        return 'mobile_application';

      case 'website-application':
      case 'website application':
      case 'web_application':
      case 'web-application':
      case 'web application':
      case 'web_app':
      case 'web-app':
      case 'web app':
        return 'website_application';

      default:
        return value.replaceAll('-', '_').replaceAll(' ', '_');
    }
  }

  String getFileGroupTitle(String type, Map<String, dynamic> asset) {
    final rawTitle = asset['title']?.toString().trim() ?? '';

    if (rawTitle.isEmpty) {
      return defaultTitleForType(type);
    }

    if (rawTitle.contains(' - ')) {
      return rawTitle.split(' - ').first.trim();
    }

    return rawTitle;
  }

  String defaultTitleForType(String type) {
    switch (type) {
      case 'packages':
        return 'Packages';
      case 'portfolio':
        return 'APK File Upload';
      case 'photos':
        return 'Photos';
      default:
        return 'Files';
    }
  }

  void loadFileAsset(String type, Map<String, dynamic> asset) {
    final groupTitle = getFileGroupTitle(type, asset);
    final baseTitle = defaultTitleForType(type);

    if (type == 'portfolio' && groupTitle != baseTitle) {
      final extra = findOrCreateExtraFileSection(
        list: extraPortfolioSections,
        type: 'portfolio',
        groupTitle: groupTitle,
        icon: Icons.android_outlined,
      );

      fillFileIntoSection(extra, asset);
      return;
    }

    if (type == 'photos' && groupTitle != baseTitle) {
      final extra = findOrCreateExtraFileSection(
        list: extraPhotoSections,
        type: 'photos',
        groupTitle: groupTitle,
        icon: Icons.image_outlined,
      );

      fillFileIntoSection(extra, asset);
      return;
    }

    fillFileIntoSection(sections[type]!, asset);
  }

  AssetEditSection findOrCreateExtraFileSection({
    required List<AssetEditSection> list,
    required String type,
    required String groupTitle,
    required IconData icon,
  }) {
    for (final section in list) {
      if (section.displayTitle == groupTitle || section.title == groupTitle) {
        return section;
      }
    }

    final section = AssetEditSection(
      type: type,
      title: groupTitle,
      icon: icon,
      isFileSection: true,
    );

    section.displayTitle = groupTitle;
    list.add(section);

    return section;
  }

  AssetEditSection createOtherLinkSection() {
    return AssetEditSection(
      type: 'other_link',
      title: 'Other Link ${extraOtherLinkSections.length + 2}',
      icon: Icons.link,
    );
  }

  AssetEditSection createMobileApplicationSection() {
    return AssetEditSection(
      type: 'mobile_application',
      title: 'Mobile Application ${extraMobileApplicationSections.length + 2}',
      icon: Icons.phone_android,
      isMobileApplication: true,
    );
  }

  AssetEditSection createPortfolioSection() {
    return AssetEditSection(
      type: 'portfolio',
      title: 'APK File Upload ${extraPortfolioSections.length + 2}',
      icon: Icons.android_outlined,
      isFileSection: true,
    );
  }

  AssetEditSection createPhotoSection() {
    return AssetEditSection(
      type: 'photos',
      title: 'Photos ${extraPhotoSections.length + 2}',
      icon: Icons.image_outlined,
      isFileSection: true,
    );
  }

  void fillFileIntoSection(AssetEditSection section, Map<String, dynamic> asset) {
    final id = int.tryParse(asset['id']?.toString() ?? '0') ?? 0;
    final fileName = asset['file_name']?.toString() ?? '';

    String finalName = fileName;

    if (finalName.isEmpty) {
      finalName = extractFileName(asset['description']?.toString() ?? '');
    }

    if (finalName.isEmpty) {
      finalName = asset['title']?.toString() ?? section.title;
    }

    section.files.add({
      'id': id,
      'name': finalName,
      'bytes': null,
      'existing': true,
    });
  }

  void fillSection(AssetEditSection section, Map<String, dynamic> asset) {
    final id = int.tryParse(asset['id']?.toString() ?? '0') ?? 0;

    section.id = id > 0 ? id : null;
    section.titleController.text = asset['title']?.toString() ?? section.title;

    section.linkController.text = asset['google_drive_link']?.toString() ?? '';
    section.descriptionController.text = asset['description']?.toString() ?? '';

    section.adminUrlController.text =
        asset['admin_panel_url']?.toString() ?? '';
    section.userEmailController.text = asset['user_email']?.toString() ?? '';
    section.passwordController.text = asset['password_text']?.toString() ?? '';

    if (section.isMobileApplication) {
      section.androidLinkController.text =
          asset['google_drive_link']?.toString() ?? '';
      section.iosLinkController.text = extractIosLink(
        asset['description']?.toString() ?? '',
      );
    }

    if (section.isWebsiteApplication) {
      section.websiteAppController.text =
          asset['google_drive_link']?.toString() ?? '';
    }
  }

  String extractFileName(String description) {
    if (description.contains('Selected file:')) {
      return description.replaceAll('Selected file:', '').trim();
    }

    if (description.contains('Selected files:')) {
      return description.replaceAll('Selected files:', '').trim();
    }

    return description.trim();
  }

  String extractIosLink(String description) {
    final lines = description.split('\n');

    for (final line in lines) {
      if (line.toLowerCase().contains('ios link:')) {
        return line.split(':').skip(1).join(':').trim();
      }
    }

    return '';
  }

  void addOtherLinkSection() {
    setState(() {
      extraOtherLinkSections.add(createOtherLinkSection());
    });
  }

  void addMobileApplicationSection() {
    setState(() {
      extraMobileApplicationSections.add(createMobileApplicationSection());
    });
  }

  void addPortfolioSection() {
    setState(() {
      extraPortfolioSections.add(createPortfolioSection());
    });
  }

  void addPhotoSection() {
    setState(() {
      extraPhotoSections.add(createPhotoSection());
    });
  }

  Future<void> saveChanges() async {
    if (clientNameController.text.trim().isEmpty) {
      showMessage('Client name is required', Colors.red);
      return;
    }

    final deliverables = buildDeliverables();

    if (deliverables.isEmpty && deletedDeliverableIds.isEmpty) {
      showMessage('Please add at least one asset detail', Colors.red);
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await repositoryService.updateClientDetails(
        clientId: widget.clientId,
        clientName: clientNameController.text.trim(),
        shortName: shortNameController.text.trim(),
        deliverables: deliverables,
        deletedDeliverableIds: deletedDeliverableIds,
      );

      if (!mounted) return;

      showMessage('Asset details updated successfully', AppColors.primary);

      Navigator.pop(context, true);
    } catch (error) {
      showMessage(error.toString(), Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> buildDeliverables() {
    final List<Map<String, dynamic>> items = [];

    for (final section in sections.values) {
      addSectionToList(items, section);
    }

    for (final section in extraOtherLinkSections) {
      addSectionToList(items, section);
    }

    for (final section in extraMobileApplicationSections) {
      addSectionToList(items, section);
    }

    for (final section in extraPortfolioSections) {
      addSectionToList(items, section);
    }

    for (final section in extraPhotoSections) {
      addSectionToList(items, section);
    }

    return items;
  }

  void addSectionToList(
    List<Map<String, dynamic>> items,
    AssetEditSection section,
  ) {
    if (!section.hasData()) return;

    if (section.isFileSection) {
      for (final file in section.files) {
        final fileId = int.tryParse(file['id']?.toString() ?? '0') ?? 0;
        final fileName = file['name']?.toString() ?? '';
        final fileBytes = file['bytes'];

        if (fileName.trim().isEmpty) continue;

        final Map<String, dynamic> item = {
          'id': fileId,
          'deliverable_type': section.type,
          'title': section.title,
          'google_drive_link': '',
          'description': 'Selected file: $fileName',
        };

        if (fileBytes != null) {
          item['file'] = {
            'name': fileName,
            'bytes': fileBytes,
          };
        }

        items.add(item);
      }

      return;
    }

    if (section.isMobileApplication) {
      final android = section.androidLinkController.text.trim();
      final ios = section.iosLinkController.text.trim();

      items.add({
        'id': section.id ?? 0,
        'deliverable_type': section.type,
        'title': section.title,
        'google_drive_link': android,
        'description': 'Android Link: $android\nIOS Link: $ios',
        'admin_panel_url': section.adminUrlController.text.trim(),
        'user_email': section.userEmailController.text.trim(),
        'password_text': section.passwordController.text.trim(),
      });

      return;
    }

    if (section.isWebsiteApplication) {
      items.add({
        'id': section.id ?? 0,
        'deliverable_type': section.type,
        'title': section.title,
        'google_drive_link': section.websiteAppController.text.trim(),
        'description': 'Website application details',
        'admin_panel_url': section.adminUrlController.text.trim(),
        'user_email': section.userEmailController.text.trim(),
        'password_text': section.passwordController.text.trim(),
      });

      return;
    }

    items.add({
      'id': section.id ?? 0,
      'deliverable_type': section.type,
      'title': section.title,
      'google_drive_link': section.linkController.text.trim(),
      'description': section.descriptionController.text.trim(),
    });
  }

  void removeSection(AssetEditSection section) {
    if (section.isFileSection) {
      for (final file in section.files) {
        final id = int.tryParse(file['id']?.toString() ?? '0') ?? 0;

        if (id > 0) {
          deletedDeliverableIds.add(id);
        }
      }
    } else if (section.id != null && section.id! > 0) {
      deletedDeliverableIds.add(section.id!);
    }

    setState(() {
      section.clear();
    });
  }

  void removeFileFromSection(AssetEditSection section, int index) {
    final file = section.files[index];
    final id = int.tryParse(file['id']?.toString() ?? '0') ?? 0;

    if (id > 0) {
      deletedDeliverableIds.add(id);
    }

    setState(() {
      section.files.removeAt(index);
    });
  }

  void removeExtraSection(List<AssetEditSection> list, int index) {
    final section = list[index];

    if (section.isFileSection) {
      for (final file in section.files) {
        final id = int.tryParse(file['id']?.toString() ?? '0') ?? 0;

        if (id > 0) {
          deletedDeliverableIds.add(id);
        }
      }
    } else if (section.id != null && section.id! > 0) {
      deletedDeliverableIds.add(section.id!);
    }

    setState(() {
      section.dispose();
      list.removeAt(index);
      refreshExtraTitles();
    });
  }

  void refreshExtraTitles() {
    for (int i = 0; i < extraOtherLinkSections.length; i++) {
      extraOtherLinkSections[i].displayTitle = 'Other Link ${i + 2}';
    }

    for (int i = 0; i < extraMobileApplicationSections.length; i++) {
      extraMobileApplicationSections[i].displayTitle =
          'Mobile Application ${i + 2}';
    }

    for (int i = 0; i < extraPortfolioSections.length; i++) {
      extraPortfolioSections[i].displayTitle = 'APK File Upload ${i + 2}';
    }

    for (int i = 0; i < extraPhotoSections.length; i++) {
      extraPhotoSections[i].displayTitle = 'Photos ${i + 2}';
    }
  }

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception:', '').trim()),
        backgroundColor: color,
      ),
    );
  }

  @override
  void dispose() {
    clientNameController.dispose();
    shortNameController.dispose();

    for (final section in sections.values) {
      section.dispose();
    }

    for (final section in extraOtherLinkSections) {
      section.dispose();
    }

    for (final section in extraMobileApplicationSections) {
      section.dispose();
    }

    for (final section in extraPortfolioSections) {
      section.dispose();
    }

    for (final section in extraPhotoSections) {
      section.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      selectedMenu: 'repository',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 28, 68, 28),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  topHeader(),
                  const SizedBox(height: 10),
                  basicFields(),
                  const SizedBox(height: 14),
                  addSectionButtons(),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    linkCard(sections['poster_design']!),
                                    const SizedBox(height: 18),
                                    linkCard(sections['video']!),
                                    const SizedBox(height: 18),
                                    fileCard(sections['packages']!),
                                    const SizedBox(height: 18),
                                    fileCard(sections['portfolio']!),
                                    extraPortfolioWidgets(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: Column(
                                  children: [
                                    linkCard(sections['landing_page']!),
                                    const SizedBox(height: 18),
                                    linkCard(sections['website']!),
                                    const SizedBox(height: 18),
                                    linkCard(sections['other_link']!),
                                    extraOtherLinkWidgets(),
                                    const SizedBox(height: 18),
                                    mobileApplicationCard(
                                      sections['mobile_application']!,
                                    ),
                                    extraMobileApplicationWidgets(),
                                    const SizedBox(height: 18),
                                    websiteApplicationCard(
                                      sections['website_application']!,
                                    ),
                                    const SizedBox(height: 18),
                                    fileCard(sections['photos']!),
                                    extraPhotoWidgets(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          bottomButtons(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget topHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            Navigator.pop(context, false);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 6),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Asset Upload',
              style: TextStyle(
                color: Color(0xFF202124),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Edit existing digital assets and update repository details.',
              style: TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget addSectionButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        addSectionButton(
          title: 'Add Other Link',
          icon: Icons.link,
          onTap: addOtherLinkSection,
        ),
        addSectionButton(
          title: 'Add Mobile App',
          icon: Icons.phone_android,
          onTap: addMobileApplicationSection,
        ),
        addSectionButton(
          title: 'Add APK File',
          icon: Icons.android_outlined,
          onTap: addPortfolioSection,
        ),
        addSectionButton(
          title: 'Add Photos',
          icon: Icons.image_outlined,
          onTap: addPhotoSection,
        ),
      ],
    );
  }

  Widget addSectionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 34,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        icon: Icon(
          icon,
          color: Colors.white,
          size: 15,
        ),
        label: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget extraOtherLinkWidgets() {
    if (extraOtherLinkSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: extraOtherLinkSections.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: linkCard(
            entry.value,
            onRemove: () {
              removeExtraSection(extraOtherLinkSections, entry.key);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget extraMobileApplicationWidgets() {
    if (extraMobileApplicationSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: extraMobileApplicationSections.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: mobileApplicationCard(
            entry.value,
            onRemove: () {
              removeExtraSection(extraMobileApplicationSections, entry.key);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget extraPortfolioWidgets() {
    if (extraPortfolioSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: extraPortfolioSections.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: fileCard(
            entry.value,
            onRemove: () {
              removeExtraSection(extraPortfolioSections, entry.key);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget extraPhotoWidgets() {
    if (extraPhotoSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: extraPhotoSections.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: fileCard(
            entry.value,
            onRemove: () {
              removeExtraSection(extraPhotoSections, entry.key);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget basicFields() {
    return Row(
      children: [
        Expanded(
          child: fieldWithLabel(
            label: 'Name',
            controller: clientNameController,
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: fieldWithLabel(
            label: 'Short Name',
            controller: shortNameController,
          ),
        ),
      ],
    );
  }

  Widget linkCard(
    AssetEditSection section, {
    VoidCallback? onRemove,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          sectionButton(
            title: section.displayTitle,
            icon: section.icon,
          ),
          const SizedBox(width: 38),
          Expanded(
            child: fieldWithLabel(
              label: 'Paste Link',
              controller: section.linkController,
            ),
          ),
          const SizedBox(width: 8),
          onRemove == null ? removeButton(section) : removeIcon(onRemove),
        ],
      ),
    );
  }

  Widget mobileApplicationCard(
    AssetEditSection section, {
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              sectionButton(
                title: section.displayTitle,
                icon: section.icon,
              ),
              const Spacer(),
              onRemove == null ? removeButton(section) : removeIcon(onRemove),
            ],
          ),
          const SizedBox(height: 16),
          fieldWithLabel(
            label: 'Android Link (URL)',
            controller: section.androidLinkController,
            hint: 'https://play.google.com/...',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          fieldWithLabel(
            label: 'IOS Link (URL)',
            controller: section.iosLinkController,
            hint: 'https://apps.apple.com/...',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          fieldWithLabel(
            label: 'Admin Panel URL',
            controller: section.adminUrlController,
            hint: 'https://admin.example.com',
            prefixIcon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: fieldWithLabel(
                  label: 'User Email',
                  controller: section.userEmailController,
                  hint: 'admin@example.com',
                  prefixIcon: Icons.email_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: fieldWithLabel(
                  label: 'Password',
                  controller: section.passwordController,
                  hint: 'Password',
                  prefixIcon: Icons.lock_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget websiteApplicationCard(AssetEditSection section) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              sectionButton(
                title: section.displayTitle,
                icon: section.icon,
              ),
              const Spacer(),
              removeButton(section),
            ],
          ),
          const SizedBox(height: 16),
          fieldWithLabel(
            label: 'Website Application URL',
            controller: section.websiteAppController,
            hint: 'https://website.com',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          fieldWithLabel(
            label: 'Admin Panel URL',
            controller: section.adminUrlController,
            hint: 'https://admin.website.com',
            prefixIcon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: fieldWithLabel(
                  label: 'User Email',
                  controller: section.userEmailController,
                  hint: 'admin@website.com',
                  prefixIcon: Icons.email_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: fieldWithLabel(
                  label: 'Password',
                  controller: section.passwordController,
                  hint: 'Password',
                  prefixIcon: Icons.lock_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget fileCard(
    AssetEditSection section, {
    VoidCallback? onRemove,
  }) {
    return UploadEditDropCard(
      title: section.displayTitle,
      icon: section.icon,
      files: section.files,
      onFilesPicked: (files) {
        setState(() {
          section.files.addAll(files);
        });
      },
      onRemoveFile: (index) {
        removeFileFromSection(section, index);
      },
      onClearAll: () {
        removeSection(section);
      },
      onRemoveSection: onRemove,
    );
  }

  Widget removeButton(AssetEditSection section) {
    final hasData = section.hasData();

    return Tooltip(
      message: hasData ? 'Remove this asset' : 'Clear',
      child: InkWell(
        onTap: hasData ? () => removeSection(section) : null,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: hasData ? Colors.red.withValues(alpha: 0.08) : Colors.white,
            border: Border.all(
              color: hasData ? Colors.red : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.delete_outline,
            size: 15,
            color: hasData ? Colors.red : const Color(0xFFB2B8C4),
          ),
        ),
      ),
    );
  }

  Widget removeIcon(VoidCallback onTap) {
    return Tooltip(
      message: 'Remove this section',
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            border: Border.all(color: Colors.red),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.delete_outline,
            size: 15,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  Widget fieldWithLabel({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    bool readOnly = false,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 22,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            obscureText: obscureText,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF9AA4B2),
                fontSize: 11,
              ),
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(
                      prefixIcon,
                      size: 13,
                      color: const Color(0xFF9AA4B2),
                    ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 26,
                minHeight: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget sectionButton({
    required String title,
    required IconData icon,
  }) {
    return Container(
      width: 164,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            icon,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(3),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget bottomButtons() {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 42,
            width: 120,
            child: OutlinedButton(
              onPressed: isSaving
                  ? null
                  : () {
                      Navigator.pop(context, false);
                    },
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 42,
            width: 170,
            child: ElevatedButton(
              onPressed: isSaving ? null : saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Update Assets',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssetEditSection {
  int? id;
  final String type;
  final String title;
  String displayTitle;
  final IconData icon;
  final bool isFileSection;
  final bool isMobileApplication;
  final bool isWebsiteApplication;

  final List<Map<String, dynamic>> files = [];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController linkController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final TextEditingController androidLinkController = TextEditingController();
  final TextEditingController iosLinkController = TextEditingController();
  final TextEditingController websiteAppController = TextEditingController();

  final TextEditingController adminUrlController = TextEditingController();
  final TextEditingController userEmailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  AssetEditSection({
    required this.type,
    required this.title,
    required this.icon,
    this.isFileSection = false,
    this.isMobileApplication = false,
    this.isWebsiteApplication = false,
  }) : displayTitle = title {
    titleController.text = title;
  }

  bool hasLoadedData() {
    return id != null || hasData();
  }

  bool hasData() {
    if (isFileSection) {
      return files.isNotEmpty;
    }

    if (isMobileApplication) {
      return androidLinkController.text.trim().isNotEmpty ||
          iosLinkController.text.trim().isNotEmpty ||
          adminUrlController.text.trim().isNotEmpty ||
          userEmailController.text.trim().isNotEmpty ||
          passwordController.text.trim().isNotEmpty;
    }

    if (isWebsiteApplication) {
      return websiteAppController.text.trim().isNotEmpty ||
          adminUrlController.text.trim().isNotEmpty ||
          userEmailController.text.trim().isNotEmpty ||
          passwordController.text.trim().isNotEmpty;
    }

    return linkController.text.trim().isNotEmpty ||
        descriptionController.text.trim().isNotEmpty;
  }

  void clear() {
    id = null;
    files.clear();

    titleController.text = title;
    linkController.clear();
    descriptionController.clear();
    androidLinkController.clear();
    iosLinkController.clear();
    websiteAppController.clear();
    adminUrlController.clear();
    userEmailController.clear();
    passwordController.clear();
  }

  void dispose() {
    titleController.dispose();
    linkController.dispose();
    descriptionController.dispose();
    androidLinkController.dispose();
    iosLinkController.dispose();
    websiteAppController.dispose();
    adminUrlController.dispose();
    userEmailController.dispose();
    passwordController.dispose();
  }
}

class UploadEditDropCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> files;
  final ValueChanged<List<Map<String, dynamic>>> onFilesPicked;
  final ValueChanged<int> onRemoveFile;
  final VoidCallback onClearAll;
  final VoidCallback? onRemoveSection;

  const UploadEditDropCard({
    super.key,
    required this.title,
    required this.icon,
    required this.files,
    required this.onFilesPicked,
    required this.onRemoveFile,
    required this.onClearAll,
    this.onRemoveSection,
  });

  @override
  State<UploadEditDropCard> createState() => _UploadEditDropCardState();
}

class _UploadEditDropCardState extends State<UploadEditDropCard> {
  DropzoneViewController? controller;
  bool isHighlighted = false;

  Future<void> pickFile() async {
    if (controller == null) return;

    final files = await controller!.pickFiles(
      multiple: true,
      mime: [
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
        'video/mp4',
      ],
    );

    if (files.isEmpty) return;

    final pickedFiles = <Map<String, dynamic>>[];

    for (final file in files) {
      final name = await controller!.getFilename(file);
      final bytes = await controller!.getFileData(file);

      pickedFiles.add({
        'id': 0,
        'name': name,
        'bytes': bytes,
        'existing': false,
      });
    }

    widget.onFilesPicked(pickedFiles);
  }

  Future<void> handleDrop(dynamic event) async {
    if (controller == null) return;

    final name = await controller!.getFilename(event);
    final size = await controller!.getFileSize(event);

    const maxSize = 500 * 1024 * 1024;

    if (size > maxSize) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File size should be below 500MB'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bytes = await controller!.getFileData(event);

    widget.onFilesPicked([
      {
        'id': 0,
        'name': name,
        'bytes': bytes,
        'existing': false,
      },
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final hasFiles = widget.files.isNotEmpty;

    return Container(
      height: hasFiles ? 250 : 196,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          DropzoneView(
            onCreated: (ctrl) {
              controller = ctrl;
            },
            onHover: () {
              setState(() {
                isHighlighted = true;
              });
            },
            onLeave: () {
              setState(() {
                isHighlighted = false;
              });
            },
            onDropFile: (event) async {
              setState(() {
                isHighlighted = false;
              });

              await handleDrop(event);
            },
          ),
          Column(
            children: [
              Row(
                children: [
                  _blueTitleButton(),
                  const Spacer(),
                  clearAllButton(hasFiles),
                  if (widget.onRemoveSection != null) ...[
                    const SizedBox(width: 8),
                    removeSectionButton(),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: hasFiles ? filesList() : uploadEmptyView(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget uploadEmptyView() {
    return InkWell(
      onTap: pickFile,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFEAF1FF),
              child: Icon(
                Icons.upload,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Drag & drop files here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF202124),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click to browse | Select multiple files up to 500MB each.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7A8699),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget filesList() {
    return Column(
      children: [
        InkWell(
          onTap: pickFile,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_outline,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Add more files (${widget.files.length} selected)',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: widget.files.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final file = widget.files[index];
              final fileName = file['name']?.toString() ?? 'Uploaded file';
              final isExisting = file['existing'] == true;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExisting
                          ? Icons.insert_drive_file_outlined
                          : Icons.upload_file_outlined,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF202124),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => widget.onRemoveFile(index),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 14,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget clearAllButton(bool hasFiles) {
    return InkWell(
      onTap: hasFiles ? widget.onClearAll : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: hasFiles ? Colors.red.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: hasFiles ? Colors.red : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.delete_outline,
          size: 15,
          color: hasFiles ? Colors.red : const Color(0xFFB2B8C4),
        ),
      ),
    );
  }

  Widget removeSectionButton() {
    return InkWell(
      onTap: widget.onRemoveSection,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.close,
          size: 15,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget _blueTitleButton() {
    return Container(
      width: 164,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            widget.icon,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
