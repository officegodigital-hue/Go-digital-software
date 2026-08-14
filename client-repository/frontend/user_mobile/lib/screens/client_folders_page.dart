import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../services/mobile_service.dart';
import 'deliverables_page.dart';
import 'profile_page.dart';

class ClientFoldersPage extends StatefulWidget {
  final String categoryTitle;
  final String categorySlug;

  const ClientFoldersPage({
    super.key,
    required this.categoryTitle,
    required this.categorySlug,
  });

  @override
  State<ClientFoldersPage> createState() => _ClientFoldersPageState();
}

class _ClientFoldersPageState extends State<ClientFoldersPage> {
  final MobileService mobileService = MobileService();

  late Future<List<dynamic>> clientsFuture;

  @override
  void initState() {
    super.initState();
    clientsFuture = mobileService.getClientsByCategory(widget.categorySlug);
  }

  void goProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfilePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: bottomBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
          child: Column(
            children: [
              pageHeader(),
              const SizedBox(height: 26),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: clientsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }

                    final clients = snapshot.data ?? [];

                    if (clients.isEmpty) {
                      return const Center(
                        child: Text(
                          'No client folders found',
                          style: TextStyle(
                            color: AppColors.greyText,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      itemCount: clients.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 26,
                        crossAxisSpacing: 24,
                        childAspectRatio: 1.05,
                      ),
                      itemBuilder: (context, index) {
                        final client =
                            Map<String, dynamic>.from(clients[index]);

                        return clientFolder(client);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget pageHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
        ),
        Expanded(
          child: Text(
            '${formatTitle(widget.categoryTitle)}\nFolders',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget clientFolder(Map<String, dynamic> client) {
    final clientName = client['client_name']?.toString() ?? 'Client';
    final shortName = client['short_name']?.toString() ?? '';
    final clientId = int.tryParse(client['client_id'].toString()) ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeliverablesPage(
              clientId: clientId,
              clientName: clientName,
              categorySlug: widget.categorySlug,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 76,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                shortName.isNotEmpty ? shortName : initials(clientName),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            clientName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget bottomBar() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: const Color(0xFF9AA4B2),
      elevation: 0,
      backgroundColor: Colors.white,
      onTap: (index) {
        if (index == 0) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }

        if (index == 1) {
          goProfile();
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  String initials(String name) {
    final words = name.trim().split(' ');

    return words
        .where((word) => word.isNotEmpty)
        .map((word) => word[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  String formatTitle(String value) {
    return value
        .toLowerCase()
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}