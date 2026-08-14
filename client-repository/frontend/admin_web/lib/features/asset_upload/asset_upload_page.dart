import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

import '../../core/constants/app_colors.dart';
import '../../core/layout/admin_layout.dart';
import '../../services/asset_upload_service.dart';

class AssetUploadPage extends StatefulWidget {
  const AssetUploadPage({super.key});

  @override
  State<AssetUploadPage> createState() => _AssetUploadPageState();
}

class _AssetUploadPageState extends State<AssetUploadPage> {
  final AssetUploadService assetUploadService = AssetUploadService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  final TextEditingController posterDesignLinkController =
      TextEditingController();
  final TextEditingController landingPageLinkController =
      TextEditingController();
  final TextEditingController videoLinkController = TextEditingController();
  final TextEditingController websiteLinkController = TextEditingController();
  final TextEditingController otherLinkController = TextEditingController();

  final TextEditingController mobileAndroidLinkController =
      TextEditingController();
  final TextEditingController mobileIosLinkController = TextEditingController();
  final TextEditingController mobileAdminUrlController =
      TextEditingController();
  final TextEditingController mobileUserEmailController =
      TextEditingController();
  final TextEditingController mobilePasswordController =
      TextEditingController();

  final TextEditingController websiteAppUrlController = TextEditingController();
  final TextEditingController websiteAdminUrlController =
      TextEditingController();
  final TextEditingController websiteUserEmailController =
      TextEditingController();
  final TextEditingController websitePasswordController =
      TextEditingController();

  final List<Map<String, dynamic>> packageFiles = [];
  final List<Map<String, dynamic>> portfolioFiles = [];
  final List<Map<String, dynamic>> photosFiles = [];

  final List<DynamicOtherLinkSection> extraOtherLinks = [];
  final List<DynamicMobileApplicationSection> extraMobileApps = [];
  final List<DynamicPhotoSection> extraPhotos = [];

  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();

    nameController.text = 'Go Digital';

    final now = DateTime.now();
    dateController.text =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  void dispose() {
    nameController.dispose();
    dateController.dispose();

    posterDesignLinkController.dispose();
    landingPageLinkController.dispose();
    videoLinkController.dispose();
    websiteLinkController.dispose();
    otherLinkController.dispose();

    mobileAndroidLinkController.dispose();
    mobileIosLinkController.dispose();
    mobileAdminUrlController.dispose();
    mobileUserEmailController.dispose();
    mobilePasswordController.dispose();

    websiteAppUrlController.dispose();
    websiteAdminUrlController.dispose();
    websiteUserEmailController.dispose();
    websitePasswordController.dispose();

    for (final item in extraOtherLinks) {
      item.dispose();
    }

    for (final item in extraMobileApps) {
      item.dispose();
    }

    for (final item in extraPhotos) {
      item.dispose();
    }

    super.dispose();
  }

  Future<void> submitAssets() async {
    final clientName = nameController.text.trim();

    if (clientName.isEmpty) {
      showMessage('Client name is required', Colors.red);
      return;
    }

    final deliverables = buildDeliverables();

    if (deliverables.isEmpty) {
      showMessage('Please add at least one link or file detail', Colors.red);
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await assetUploadService.uploadAssets(
        clientName: clientName,
        shortName: makeShortName(clientName),
        deliverables: deliverables,
      );

      if (!mounted) return;

      showMessage('Assets uploaded successfully', AppColors.primary);
      clearForm();
    } catch (error) {
      showMessage(error.toString(), Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> buildDeliverables() {
    final List<Map<String, dynamic>> items = [];

    void addLinkAsset({
      required String type,
      required String title,
      required TextEditingController linkController,
      String description = '',
    }) {
      final link = linkController.text.trim();

      if (link.isEmpty) return;

      items.add({
        'deliverable_type': type,
        'title': title,
        'google_drive_link': link,
        'description': description,
      });
    }

    void addFileAsset({
      required String type,
      required String title,
      required List<Map<String, dynamic>> files,
    }) {
      if (files.isEmpty) return;

      final fileNames = files
          .map((file) => file['name']?.toString() ?? '')
          .where((name) => name.trim().isNotEmpty)
          .join(', ');

      items.add({
        'deliverable_type': type,
        'title': title,
        'google_drive_link': '',
        'description': 'Selected files: $fileNames',
        'files': files,
      });
    }

    void addMobileAsset({
      required TextEditingController androidController,
      required TextEditingController iosController,
      required TextEditingController adminController,
      required TextEditingController emailController,
      required TextEditingController passwordController,
      String title = 'Mobile Application',
    }) {
      final android = androidController.text.trim();
      final ios = iosController.text.trim();
      final admin = adminController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (android.isEmpty &&
          ios.isEmpty &&
          admin.isEmpty &&
          email.isEmpty &&
          password.isEmpty) {
        return;
      }

      items.add({
        'deliverable_type': 'mobile_application',
        'title': title,
        'google_drive_link': android,
        'description': 'Android Link: $android\nIOS Link: $ios',
        'admin_panel_url': admin,
        'user_email': email,
        'password_text': password,
      });
    }

    addLinkAsset(
      type: 'poster_design',
      title: 'Poster Design',
      linkController: posterDesignLinkController,
    );

    addLinkAsset(
      type: 'landing_page',
      title: 'Landing Page',
      linkController: landingPageLinkController,
    );

    addLinkAsset(
      type: 'video',
      title: 'Video',
      linkController: videoLinkController,
    );

    addLinkAsset(
      type: 'website',
      title: 'Website',
      linkController: websiteLinkController,
    );

    addLinkAsset(
      type: 'other_link',
      title: 'Other Link',
      linkController: otherLinkController,
    );

    for (int i = 0; i < extraOtherLinks.length; i++) {
      final manualTitle = extraOtherLinks[i].titleController.text.trim();

      addLinkAsset(
        type: 'other_link',
        title: manualTitle.isEmpty ? 'Other Link ${i + 2}' : manualTitle,
        linkController: extraOtherLinks[i].linkController,
      );
    }

    addFileAsset(
      type: 'packages',
      title: 'Packages',
      files: packageFiles,
    );

    addFileAsset(
      type: 'portfolio',
      title: 'APK File Upload',
      files: portfolioFiles,
    );

    addFileAsset(
      type: 'photos',
      title: 'Photos',
      files: photosFiles,
    );

    for (int i = 0; i < extraPhotos.length; i++) {
      final manualTitle = extraPhotos[i].titleController.text.trim();

      addFileAsset(
        type: 'photos',
        title: manualTitle.isEmpty ? 'Photos ${i + 2}' : manualTitle,
        files: extraPhotos[i].files,
      );
    }

    addMobileAsset(
      androidController: mobileAndroidLinkController,
      iosController: mobileIosLinkController,
      adminController: mobileAdminUrlController,
      emailController: mobileUserEmailController,
      passwordController: mobilePasswordController,
    );

    for (int i = 0; i < extraMobileApps.length; i++) {
      final manualTitle = extraMobileApps[i].titleController.text.trim();

      addMobileAsset(
        androidController: extraMobileApps[i].androidController,
        iosController: extraMobileApps[i].iosController,
        adminController: extraMobileApps[i].adminController,
        emailController: extraMobileApps[i].emailController,
        passwordController: extraMobileApps[i].passwordController,
        title: manualTitle.isEmpty
            ? 'Mobile Application ${i + 2}'
            : manualTitle,
      );
    }

    final websiteApp = websiteAppUrlController.text.trim();
    final websiteAdmin = websiteAdminUrlController.text.trim();
    final websiteEmail = websiteUserEmailController.text.trim();
    final websitePassword = websitePasswordController.text.trim();

    if (websiteApp.isNotEmpty ||
        websiteAdmin.isNotEmpty ||
        websiteEmail.isNotEmpty ||
        websitePassword.isNotEmpty) {
      items.add({
        'deliverable_type': 'website_application',
        'title': 'Website Application',
        'google_drive_link': websiteApp,
        'description': 'Website application details',
        'admin_panel_url': websiteAdmin,
        'user_email': websiteEmail,
        'password_text': websitePassword,
      });
    }

    return items;
  }

  String makeShortName(String name) {
    final parts = name.trim().split(' ');

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return parts
        .where((part) => part.trim().isNotEmpty)
        .take(3)
        .map((part) => part[0].toUpperCase())
        .join();
  }

  void clearForm() {
    posterDesignLinkController.clear();
    landingPageLinkController.clear();
    videoLinkController.clear();
    websiteLinkController.clear();
    otherLinkController.clear();

    mobileAndroidLinkController.clear();
    mobileIosLinkController.clear();
    mobileAdminUrlController.clear();
    mobileUserEmailController.clear();
    mobilePasswordController.clear();

    websiteAppUrlController.clear();
    websiteAdminUrlController.clear();
    websiteUserEmailController.clear();
    websitePasswordController.clear();

    for (final item in extraOtherLinks) {
      item.dispose();
    }

    for (final item in extraMobileApps) {
      item.dispose();
    }

    for (final item in extraPhotos) {
      item.dispose();
    }

    setState(() {
      packageFiles.clear();
      portfolioFiles.clear();
      photosFiles.clear();

      extraOtherLinks.clear();
      extraMobileApps.clear();
      extraPhotos.clear();
    });
  }

  void addOtherLinkSection() {
    setState(() {
      extraOtherLinks.add(
        DynamicOtherLinkSection(
          title: 'Other Link ${extraOtherLinks.length + 2}',
        ),
      );
    });
  }

  void addMobileApplicationSection() {
    setState(() {
      extraMobileApps.add(
        DynamicMobileApplicationSection(
          title: 'Mobile Application ${extraMobileApps.length + 2}',
        ),
      );
    });
  }

  void addPhotoSection() {
    setState(() {
      extraPhotos.add(
        DynamicPhotoSection(
          title: 'Photos ${extraPhotos.length + 2}',
        ),
      );
    });
  }

  void removeOtherLinkSection(int index) {
    setState(() {
      extraOtherLinks[index].dispose();
      extraOtherLinks.removeAt(index);
    });
  }

  void removeMobileApplicationSection(int index) {
    setState(() {
      extraMobileApps[index].dispose();
      extraMobileApps.removeAt(index);
    });
  }

  void removePhotoSection(int index) {
    setState(() {
      extraPhotos[index].dispose();
      extraPhotos.removeAt(index);
    });
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
  Widget build(BuildContext context) {
    return AdminLayout(
      selectedMenu: 'asset-upload',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 28, 68, 28),
        child: Column(
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
                              linkCard(
                                title: 'Poster Design',
                                icon: Icons.brush_outlined,
                                controller: posterDesignLinkController,
                              ),
                              const SizedBox(height: 18),
                              linkCard(
                                title: 'Video',
                                icon: Icons.videocam_outlined,
                                controller: videoLinkController,
                              ),
                              const SizedBox(height: 18),
                              UploadDropCard(
                                title: 'Packages',
                                icon: Icons.description_outlined,
                                files: packageFiles,
                                onFilesPicked: (files) {
                                  setState(() {
                                    packageFiles.addAll(files);
                                  });
                                },
                                onClear: () {
                                  setState(() {
                                    packageFiles.clear();
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              UploadDropCard(
                                title: 'APK File Upload',
                                icon: Icons.android_outlined,
                                files: portfolioFiles,
                                onFilesPicked: (files) {
                                  setState(() {
                                    portfolioFiles.addAll(files);
                                  });
                                },
                                onClear: () {
                                  setState(() {
                                    portfolioFiles.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            children: [
                              linkCard(
                                title: 'Landing Page',
                                icon: Icons.insert_drive_file_outlined,
                                controller: landingPageLinkController,
                              ),
                              const SizedBox(height: 18),
                              linkCard(
                                title: 'Website',
                                icon: Icons.language,
                                controller: websiteLinkController,
                              ),
                              const SizedBox(height: 18),
                              linkCard(
                                title: 'Other Link',
                                icon: Icons.link,
                                controller: otherLinkController,
                              ),
                              ...extraOtherLinks.asMap().entries.map((entry) {
                                final index = entry.key;
                                final section = entry.value;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: dynamicOtherLinkCard(section, index),
                                );
                              }),
                              const SizedBox(height: 18),
                              mobileApplicationCard(),
                              ...extraMobileApps.asMap().entries.map((entry) {
                                final index = entry.key;
                                final section = entry.value;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: dynamicMobileApplicationCard(
                                    section,
                                    index,
                                  ),
                                );
                              }),
                              const SizedBox(height: 18),
                              websiteApplicationCard(),
                              const SizedBox(height: 18),
                              UploadDropCard(
                                title: 'Photos',
                                icon: Icons.image_outlined,
                                files: photosFiles,
                                onFilesPicked: (files) {
                                  setState(() {
                                    photosFiles.addAll(files);
                                  });
                                },
                                onClear: () {
                                  setState(() {
                                    photosFiles.clear();
                                  });
                                },
                              ),
                              ...extraPhotos.asMap().entries.map((entry) {
                                final index = entry.key;
                                final section = entry.value;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: extraPhotoCard(section, index),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    submitButton(),
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset Upload',
          style: TextStyle(
            color: Color(0xFF202124),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Deploy new digital assets to the repository and link them to active client workflows.',
          style: TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget addSectionButtons() {
    return Row(
      children: [
        addSectionButton(
          title: 'Add Other Link',
          icon: Icons.link,
          onTap: addOtherLinkSection,
        ),
        const SizedBox(width: 12),
        addSectionButton(
          title: 'Add Mobile App',
          icon: Icons.phone_android,
          onTap: addMobileApplicationSection,
        ),
        const SizedBox(width: 12),
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

  Widget basicFields() {
    return Row(
      children: [
        Expanded(
          child: fieldWithLabel(
            label: 'Name',
            controller: nameController,
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: fieldWithLabel(
            label: 'Date',
            controller: dateController,
            readOnly: true,
          ),
        ),
      ],
    );
  }

  Widget linkCard({
    required String title,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 74,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          sectionButton(
            title: title,
            icon: icon,
          ),
          const SizedBox(width: 38),
          Expanded(
            child: fieldWithLabel(
              label: 'Paste Link',
              controller: controller,
            ),
          ),
        ],
      ),
    );
  }

  Widget dynamicOtherLinkCard(DynamicOtherLinkSection section, int index) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 104,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              sectionButton(
                title: 'Other Link ${index + 2}',
                icon: Icons.link,
              ),
              const SizedBox(width: 38),
              Expanded(
                child: fieldWithLabel(
                  label: 'Section Title',
                  controller: section.titleController,
                  hint: 'Example: Brochure Link',
                ),
              ),
              const SizedBox(width: 10),
              removeButton(() => removeOtherLinkSection(index)),
            ],
          ),
          const SizedBox(height: 12),
          fieldWithLabel(
            label: 'Paste Link',
            controller: section.linkController,
          ),
        ],
      ),
    );
  }

  Widget mobileApplicationCard() {
    return mobileCardTemplate(
      title: 'Mobile Application',
      androidController: mobileAndroidLinkController,
      iosController: mobileIosLinkController,
      adminController: mobileAdminUrlController,
      emailController: mobileUserEmailController,
      passwordController: mobilePasswordController,
    );
  }

  Widget dynamicMobileApplicationCard(
    DynamicMobileApplicationSection section,
    int index,
  ) {
    return mobileCardTemplate(
      title: 'Mobile Application ${index + 2}',
      titleController: section.titleController,
      androidController: section.androidController,
      iosController: section.iosController,
      adminController: section.adminController,
      emailController: section.emailController,
      passwordController: section.passwordController,
      onRemove: () => removeMobileApplicationSection(index),
    );
  }

  Widget mobileCardTemplate({
    required String title,
    TextEditingController? titleController,
    required TextEditingController androidController,
    required TextEditingController iosController,
    required TextEditingController adminController,
    required TextEditingController emailController,
    required TextEditingController passwordController,
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
                title: title,
                icon: Icons.phone_android,
              ),
              const Spacer(),
              if (onRemove != null) removeButton(onRemove),
            ],
          ),
          if (titleController != null) ...[
            const SizedBox(height: 16),
            fieldWithLabel(
              label: 'Section Title',
              controller: titleController,
              hint: 'Example: Customer App',
            ),
          ],
          const SizedBox(height: 16),
          fieldWithLabel(
            label: 'Android Link (URL)',
            controller: androidController,
            hint: 'https://play.google.com/...',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          fieldWithLabel(
            label: 'IOS Link (URL)',
            controller: iosController,
            hint: 'https://apps.apple.com/...',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          fieldWithLabel(
            label: 'Admin Panel URL',
            controller: adminController,
            hint: 'https://admin.example.com',
            prefixIcon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: fieldWithLabel(
                  label: 'User Email',
                  controller: emailController,
                  hint: 'admin@example.com',
                  prefixIcon: Icons.email_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: fieldWithLabel(
                  label: 'Password',
                  controller: passwordController,
                  hint: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget websiteApplicationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionButton(
            title: 'Website Application',
            icon: Icons.web_asset_outlined,
          ),
          const SizedBox(height: 16),
          fieldWithLabel(
            label: 'Website Application URL',
            controller: websiteAppUrlController,
            hint: 'https://website.com',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          fieldWithLabel(
            label: 'Admin Panel URL',
            controller: websiteAdminUrlController,
            hint: 'https://admin.website.com',
            prefixIcon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: fieldWithLabel(
                  label: 'User Email',
                  controller: websiteUserEmailController,
                  hint: 'admin@website.com',
                  prefixIcon: Icons.email_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: fieldWithLabel(
                  label: 'Password',
                  controller: websitePasswordController,
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

  Widget extraPhotoCard(DynamicPhotoSection section, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              sectionButton(
                title: 'Photos ${index + 2}',
                icon: Icons.image_outlined,
              ),
              const SizedBox(width: 38),
              Expanded(
                child: fieldWithLabel(
                  label: 'Section Title',
                  controller: section.titleController,
                  hint: 'Example: Event Photos',
                ),
              ),
              const SizedBox(width: 10),
              removeButton(() => removePhotoSection(index)),
            ],
          ),
          const SizedBox(height: 14),
          UploadDropCard(
            title: section.titleController.text.trim().isEmpty
                ? 'Photos ${index + 2}'
                : section.titleController.text.trim(),
            icon: Icons.image_outlined,
            files: section.files,
            onFilesPicked: (files) {
              setState(() {
                section.files.addAll(files);
              });
            },
            onClear: () {
              setState(() {
                section.files.clear();
              });
            },
          ),
        ],
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

  Widget removeButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
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

  Widget submitButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 160,
        height: 42,
        child: ElevatedButton(
          onPressed: isSubmitting ? null : submitAssets,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Upload Assets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

class DynamicOtherLinkSection {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController linkController = TextEditingController();

  DynamicOtherLinkSection({String title = ''}) {
    titleController.text = title;
  }

  void dispose() {
    titleController.dispose();
    linkController.dispose();
  }
}

class DynamicMobileApplicationSection {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController androidController = TextEditingController();
  final TextEditingController iosController = TextEditingController();
  final TextEditingController adminController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  DynamicMobileApplicationSection({String title = ''}) {
    titleController.text = title;
  }

  void dispose() {
    titleController.dispose();
    androidController.dispose();
    iosController.dispose();
    adminController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }
}

class DynamicPhotoSection {
  final TextEditingController titleController = TextEditingController();
  final List<Map<String, dynamic>> files = [];

  DynamicPhotoSection({String title = ''}) {
    titleController.text = title;
  }

  void dispose() {
    titleController.dispose();
  }
}

class UploadDropCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> files;
  final ValueChanged<List<Map<String, dynamic>>> onFilesPicked;
  final VoidCallback onClear;
  final VoidCallback? onRemove;

  const UploadDropCard({
    super.key,
    required this.title,
    required this.icon,
    required this.files,
    required this.onFilesPicked,
    required this.onClear,
    this.onRemove,
  });

  @override
  State<UploadDropCard> createState() => _UploadDropCardState();
}

class _UploadDropCardState extends State<UploadDropCard> {
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
        'name': name,
        'bytes': bytes,
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
        'name': name,
        'bytes': bytes,
      },
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final hasFiles = widget.files.isNotEmpty;

    return Container(
      height: 220,
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
                  clearFilesButton(hasFiles),
                  if (widget.onRemove != null) ...[
                    const SizedBox(width: 8),
                    removeSectionButton(),
                  ],
                ],
              ),
              const Spacer(),
              InkWell(
                onTap: pickFile,
                child: Column(
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
                    Text(
                      hasFiles
                          ? '${widget.files.length} file(s) selected'
                          : 'Drag & drop files here',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF202124),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasFiles
                          ? fileNamesText()
                          : 'Click to browse | Upload multiple files up to 500MB each.',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7A8699),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  String fileNamesText() {
    return widget.files
        .map((file) => file['name']?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .join(', ');
  }

  Widget clearFilesButton(bool hasFiles) {
    return InkWell(
      onTap: hasFiles ? widget.onClear : null,
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
      onTap: widget.onRemove,
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
