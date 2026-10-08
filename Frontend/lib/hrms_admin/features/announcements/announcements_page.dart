import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/hrms_announcements_api.dart';
import '../../shared/widgets/admin_top_nav.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});
  static Widget builder(BuildContext context) => const AnnouncementsPage();
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<dynamic> items = [];
  bool loading = true;
  String typeFilter = 'all';
  String query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      items = await HrmsAnnouncementsApi.list(context.read<AuthService>());
    } catch (e) {
      if (mounted) notice(e.toString().replaceFirst('Exception: ', ''), true);
    }
    if (mounted) setState(() => loading = false);
  }

  void notice(String text, [bool error = false]) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : const Color(0xff0b9f6a),
        ),
      );
  int number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  Color tint(String type) => switch (type) {
    'festival' => const Color(0xffe97914),
    'important' => const Color(0xffdb263a),
    'meeting' => const Color(0xff1769e8),
    _ => const Color(0xff7148d8),
  };
  IconData icon(String type) => switch (type) {
    'festival' => Icons.celebration_outlined,
    'important' => Icons.priority_high_rounded,
    'meeting' => Icons.groups_outlined,
    'payroll' => Icons.account_balance_wallet_outlined,
    _ => Icons.campaign_outlined,
  };
  InputDecoration field(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  Future<void> createDialog() async {
    final title = TextEditingController();
    final message = TextEditingController();
    final employees = await HrmsAnnouncementsApi.employees(
      context.read<AuthService>(),
    );
    final chosen = <int>{};
    String type = 'general';
    String priority = 'normal';
    String audience = 'all';
    String? department;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, redraw) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create announcement',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff10265b),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Send a visible update to your team.'),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: field('Notification type'),
                            items:
                                const [
                                      'general',
                                      'festival',
                                      'important',
                                      'meeting',
                                      'payroll',
                                      'policy',
                                    ]
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(
                                          v[0].toUpperCase() + v.substring(1),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) => redraw(() => type = value!),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: title,
                            onChanged: (_) => redraw(() {}),
                            decoration: field('Title'),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: message,
                            onChanged: (_) => redraw(() {}),
                            minLines: 4,
                            maxLines: 6,
                            decoration: field('Message'),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Audience',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final value in [
                                'all',
                                'department',
                                'selected',
                              ])
                                ChoiceChip(
                                  label: Text(
                                    value == 'all'
                                        ? 'All employees'
                                        : value == 'department'
                                        ? 'Department'
                                        : 'Selected employees',
                                  ),
                                  selected: audience == value,
                                  onSelected: (_) =>
                                      redraw(() => audience = value),
                                ),
                            ],
                          ),
                          if (audience == 'department') ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: department,
                              decoration: field('Choose department'),
                              items: employees
                                  .map((e) => '${e['role'] ?? 'General'}')
                                  .toSet()
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  redraw(() => department = value),
                            ),
                          ],
                          if (audience == 'selected') ...[
                            const SizedBox(height: 10),
                            Container(
                              height: 130,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xffdce3f1),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListView(
                                children: employees.map((e) {
                                  final id = number(e['id']);
                                  return CheckboxListTile(
                                    dense: true,
                                    value: chosen.contains(id),
                                    title: Text(
                                      '${e['full_name'] ?? 'Employee'}',
                                    ),
                                    subtitle: Text('${e['role'] ?? ''}'),
                                    onChanged: (checked) => redraw(
                                      () => checked == true
                                          ? chosen.add(id)
                                          : chosen.remove(id),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          const Text(
                            'Priority',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final value in ['normal', 'important'])
                                ChoiceChip(
                                  label: Text(
                                    value[0].toUpperCase() + value.substring(1),
                                  ),
                                  selected: priority == value,
                                  onSelected: (_) =>
                                      redraw(() => priority = value),
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: () async {
                                  if (title.text.trim().isEmpty ||
                                      message.text.trim().isEmpty) {
                                    notice('Enter a title and message', true);
                                    return;
                                  }
                                  if (audience == 'department' &&
                                      department == null) {
                                    notice('Choose a department', true);
                                    return;
                                  }
                                  if (audience == 'selected' &&
                                      chosen.isEmpty) {
                                    notice(
                                      'Choose at least one employee',
                                      true,
                                    );
                                    return;
                                  }
                                  try {
                                    await HrmsAnnouncementsApi.create(
                                      context.read<AuthService>(),
                                      {
                                        'title': title.text.trim(),
                                        'message': message.text.trim(),
                                        'category': type,
                                        'audience': audience,
                                        'department': department,
                                        'employeeIds': chosen.toList(),
                                        'priority': priority,
                                      },
                                    );
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    await load();
                                    notice('Announcement sent');
                                  } catch (e) {
                                    notice(
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                      true,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send_outlined),
                                label: const Text('Send announcement'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                  SizedBox(
                    width: 330,
                    child: preview(title.text, message.text, type),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget preview(String title, String message, String type) {
    final color = tint(type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live preview',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: color.withValues(alpha: .12),
                      child: Icon(icon(type), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Announcement title' : title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Chip(label: Text(type[0].toUpperCase() + type.substring(1))),
                const SizedBox(height: 8),
                Text(
                  message.isEmpty
                      ? 'Your employee announcement will appear here.'
                      : message,
                  style: const TextStyle(height: 1.5),
                ),
                const Divider(height: 28),
                const Text(
                  'From Admin  •  Just now',
                  style: TextStyle(color: Color(0xff66738f), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> receipts(dynamic item) async {
    List<dynamic> rows = [];
    try {
      rows = await HrmsAnnouncementsApi.recipients(
        context.read<AuthService>(),
        item['id'],
      );
    } catch (e) {
      if (mounted) notice('Unable to load recipients', true);
      return;
    }
    if (!mounted) return;
    final read = rows.where((e) => e['read_at'] != null).length;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item['title']} — recipients'),
        content: SizedBox(
          width: 700,
          height: 430,
          child: Column(
            children: [
              Row(
                children: [
                  receiptCard(
                    'Recipients',
                    rows.length,
                    const Color(0xff1769e8),
                  ),
                  const SizedBox(width: 12),
                  receiptCard('Read', read, const Color(0xff0b9f6a)),
                  const SizedBox(width: 12),
                  receiptCard(
                    'Unread',
                    rows.length - read,
                    const Color(0xffdb263a),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = rows[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${e['full_name'] ?? '?'}'.substring(0, 1)),
                      ),
                      title: Text('${e['full_name'] ?? 'Employee'}'),
                      subtitle: Text(
                        '${e['staff_id'] ?? ''}  ${e['role'] ?? ''}',
                      ),
                      trailing: Text(
                        e['read_at'] == null ? 'Unread' : 'Read',
                        style: TextStyle(
                          color: e['read_at'] == null
                              ? const Color(0xffdb263a)
                              : const Color(0xff0b9f6a),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget receiptCard(String label, int value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label),
        ],
      ),
    ),
  );
  Widget stat(IconData iconData, String label, int value, Color color) =>
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(iconData, color: color),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label),
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final shown = items
        .where(
          (x) =>
              (typeFilter == 'all' ||
                  x['category'] == typeFilter ||
                  (typeFilter == 'important' &&
                      x['priority'] == 'important')) &&
              '${x['title']} ${x['message']}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final unread = items.fold<int>(
      0,
      (value, x) =>
          value + number(x['recipient_count']) - number(x['read_count']),
    );
    final important = items.where((x) => x['priority'] == 'important').length;
    return Scaffold(
      body: Column(
        children: [
          const AdminTopNav(activeRoute: '/admin/announcements'),
          Expanded(
            child: Container(
              color: const Color(0xfff5f7fc),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Announcements',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff10265b),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text('Create, send and track employee updates'),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: createDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create announcement'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        stat(
                          Icons.send_outlined,
                          'Sent',
                          items.length,
                          const Color(0xff1769e8),
                        ),
                        const SizedBox(width: 14),
                        stat(
                          Icons.mark_email_unread_outlined,
                          'Unread',
                          unread,
                          const Color(0xffdb263a),
                        ),
                        const SizedBox(width: 14),
                        stat(
                          Icons.priority_high_rounded,
                          'Important',
                          important,
                          const Color(0xffe97914),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        SizedBox(
                          width: 230,
                          child: DropdownButtonFormField<String>(
                            initialValue: typeFilter,
                            decoration: field('Announcement type'),
                            items:
                                const [
                                      ('all', 'All types'),
                                      ('festival', 'Festival'),
                                      ('important', 'Important'),
                                      ('general', 'General'),
                                      ('meeting', 'Meeting'),
                                      ('payroll', 'Payroll'),
                                    ]
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v.$1,
                                        child: Text(v.$2),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) =>
                                setState(() => typeFilter = value!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            onChanged: (value) => setState(() => query = value),
                            decoration: field(
                              'Search announcements',
                            ).copyWith(prefixIcon: const Icon(Icons.search)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : shown.isEmpty
                          ? emptyState()
                          : Card(
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: const WidgetStatePropertyAll(
                                    Color(0xffeef4ff),
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Title')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(label: Text('Audience')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Read rate')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: shown.map((x) {
                                    final total = number(x['recipient_count']);
                                    final read = number(x['read_count']);
                                    final rate = total == 0
                                        ? 0
                                        : (read * 100 / total).round();
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 250,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${x['title']}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  '${x['message']}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Chip(
                                            label: Text('${x['category']}'),
                                            backgroundColor: tint(
                                              '${x['category']}',
                                            ).withValues(alpha: .12),
                                          ),
                                        ),
                                        DataCell(
                                          Text('${x['audience'] ?? 'all'}'),
                                        ),
                                        const DataCell(
                                          Chip(
                                            label: Text('Sent'),
                                            backgroundColor: Color(0xffdff6ea),
                                          ),
                                        ),
                                        DataCell(
                                          Text('$rate%  ($read/$total)'),
                                        ),
                                        DataCell(
                                          OutlinedButton(
                                            onPressed: () => receipts(x),
                                            child: const Text('View'),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget emptyState() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.campaign_outlined,
                size: 46,
                color: Color(0xff1769e8),
              ),
              const SizedBox(height: 12),
              const Text(
                'No announcements yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('Create the first employee update from here.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: createDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create announcement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
