import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/layout/admin_layout.dart';
import '../../services/repository_service.dart';
import 'client_asset_edit_page.dart';
import 'client_asset_view_page.dart';

class RepositoryPage extends StatefulWidget {
  const RepositoryPage({super.key});

  @override
  State<RepositoryPage> createState() => _RepositoryPageState();
}

class _RepositoryPageState extends State<RepositoryPage> {
  final RepositoryService repositoryService = RepositoryService();
  final TextEditingController searchController = TextEditingController();

  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> clients = [];

  @override
  void initState() {
    super.initState();
    loadRepository();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadRepository() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final data = await repositoryService.getRepository();

      if (!mounted) return;

      setState(() {
        clients = data.map((item) => Map<String, dynamic>.from(item)).toList();
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString().replaceAll('Exception:', '').trim();
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> filteredClients() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) return clients;

    return clients.where((client) {
      final name = getClientName(client).toLowerCase();
      final shortName = getShortName(client).toLowerCase();

      return name.contains(query) || shortName.contains(query);
    }).toList();
  }

  int getClientId(Map<String, dynamic> client) {
    return int.tryParse(
          (client['client_id'] ?? client['id'] ?? '0').toString(),
        ) ??
        0;
  }

  String getClientName(Map<String, dynamic> client) {
    return client['client_name']?.toString() ??
        client['name']?.toString() ??
        'Client';
  }

  String getShortName(Map<String, dynamic> client) {
    final shortName = client['short_name']?.toString() ?? '';

    if (shortName.isNotEmpty) return shortName;

    final name = getClientName(client);
    return makeInitials(name);
  }

  String getLastModified(Map<String, dynamic> client) {
    return client['last_modified']?.toString() ??
        client['updated_on']?.toString() ??
        client['updated_at']?.toString() ??
        '-';
  }

  String getDeliverableCount(Map<String, dynamic> client) {
    return client['deliverable_count']?.toString() ?? '0';
  }

  String makeInitials(String name) {
    final words = name.trim().split(' ');

    final initials = words
        .where((word) => word.trim().isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .take(2)
        .join();

    return initials.isEmpty ? 'C' : initials;
  }

  void openView(Map<String, dynamic> client) {
  final clientId = getClientId(client);
  final clientName = getClientName(client);

  if (clientId == 0) {
    showMessage('Client ID not found', Colors.red);
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ClientAssetViewPage(
        clientId: clientId,
        clientName: clientName,
      ),
    ),
  ).then((_) {
    loadRepository();
  });
}
  void openEdit(Map<String, dynamic> client) {
    final clientId = getClientId(client);
    final clientName = getClientName(client);

    if (clientId == 0) {
      showMessage('Client ID not found', Colors.red);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientAssetEditPage(
          clientId: clientId,
          clientName: clientName,
        ),
      ),
    ).then((_) {
      loadRepository();
    });
  }

  Future<void> confirmDelete(Map<String, dynamic> client) async {
    final clientId = getClientId(client);
    final clientName = getClientName(client);

    if (clientId == 0) {
      showMessage('Client ID not found', Colors.red);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Client?'),
          content: Text(
            'Are you sure you want to delete "$clientName"?\n\nThis will delete all uploaded links, files, credentials, and mobile app view details for this client.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                elevation: 0,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await deleteClient(clientId);
  }

  Future<void> deleteClient(int clientId) async {
    setState(() {
      isLoading = true;
    });

    try {
      await repositoryService.deleteClientAssetDetails(clientId);

      if (!mounted) return;

      showMessage('Client deleted successfully', AppColors.primary);
      await loadRepository();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(
        error.toString().replaceAll('Exception:', '').trim(),
        Colors.red,
      );
    }
  }

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      selectedMenu: 'repository',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 28, 68, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topHeader(),
            const SizedBox(height: 22),
            toolbar(),
            const SizedBox(height: 14),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : errorMessage.isNotEmpty
                      ? errorView()
                      : repositoryTable(),
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
          'Repository',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Personal Cloud Storage',
          style: TextStyle(
            color: AppColors.textGrey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget toolbar() {
    return Row(
      children: [
        SizedBox(
          width: 340,
          height: 36,
          child: TextField(
            controller: searchController,
            onChanged: (_) {
              setState(() {});
            },
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Search clients...',
              hintStyle: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 17,
                color: AppColors.textGrey,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: loadRepository,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(96, 36),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          icon: const Icon(
            Icons.refresh,
            color: Colors.white,
            size: 15,
          ),
          label: const Text(
            'Refresh',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget repositoryTable() {
    final rows = filteredClients();

    if (rows.isEmpty) {
      return emptyView();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          tableHeader(),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (context, index) {
                return const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border,
                );
              },
              itemBuilder: (context, index) {
                return tableRow(rows[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget tableHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 52),
          Expanded(
            flex: 3,
            child: Text(
              'Client Name',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Files / Links',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Last Modified',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              'Actions',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tableRow(Map<String, dynamic> client) {
    final clientName = getClientName(client);
    final shortName = getShortName(client);
    final deliverableCount = getDeliverableCount(client);
    final lastModified = getLastModified(client);

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFEAF1FF),
              child: Text(
                shortName.length > 2 ? shortName.substring(0, 2) : shortName,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              clientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$deliverableCount item(s)',
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              lastModified,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                actionIcon(
                  icon: Icons.remove_red_eye_outlined,
                  color: AppColors.textGrey,
                  tooltip: 'View',
                  onTap: () => openView(client),
                ),
                const SizedBox(width: 8),
                actionIcon(
                  icon: Icons.edit_outlined,
                  color: AppColors.textGrey,
                  tooltip: 'Edit',
                  onTap: () => openEdit(client),
                ),
                const SizedBox(width: 8),
                actionIcon(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  tooltip: 'Delete',
                  onTap: () => confirmDelete(client),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget actionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget emptyView() {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              color: AppColors.textGrey,
              size: 42,
            ),
            SizedBox(height: 14),
            Text(
              'No clients found',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Uploaded client assets will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget errorView() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadRepository,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}