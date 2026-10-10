import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_config.dart';
import '../../../services/auth_storage.dart';

class LeavePolicyDialog extends StatefulWidget {
  const LeavePolicyDialog({super.key, this.client});
  final http.Client? client;
  @override
  State<LeavePolicyDialog> createState() => _LeavePolicyDialogState();
}

class _LeavePolicyDialogState extends State<LeavePolicyDialog> {
  final names = <String, TextEditingController>{};
  final allowances = <String, TextEditingController>{};
  final abbrs = <String, TextEditingController>{};
  final form = GlobalKey<FormState>();
  List<Map<String, dynamic>> rows = [];
  bool loading = true, saving = false;
  String? error;
  bool flag(dynamic value) => value == true || value == 1;
  String displayMode(Map<String, dynamic> row) =>
      row['display_mode']?.toString() ??
      (flag(row['usage_only']) ? 'USAGE_ONLY' : 'BALANCE_USAGE');
  Future<Map<String, String>> headers() async {
    final token = await AuthStorage.getString('auth_token');
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Content-Type': 'application/json',
    };
  }

  Future<void> load() async {
    try {
      final response = await (widget.client?.get ?? http.get)(
        Uri.parse('${ApiConfig.baseUrl}/attendance/leave/policies'),
        headers: await headers(),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception(
          'Could not load leave settings (HTTP ${response.statusCode}).',
        );
      }
      final body = jsonDecode(response.body);
      rows = (body['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final row in rows) {
        final id = '${row['id']}';
        names[id] = TextEditingController(text: '${row['name']}');
        allowances[id] = TextEditingController(text: '${row['annual_allowance']}');
        abbrs[id] = TextEditingController(text: '${row['abbreviation'] ?? ''}');
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in names.values) c.dispose();
    for (final c in allowances.values) c.dispose();
    for (final c in abbrs.values) c.dispose();
    super.dispose();
  }

  int get visible => rows
      .where((r) => flag(r['show_balance_card']) && flag(r['is_active']))
      .length;

  static const blue = Color(0xFF0055FF);
  static const navy = Color(0xFF101638);
  static const muted = Color(0xFF687798);
  static const line = Color(0xFFDDE5F3);

  bool shown(Map<String, dynamic> r) =>
      flag(r['show_balance_card']) && flag(r['is_active']);

  void reorder(int from, int to) {
    setState(() {
      rows.insert(to, rows.removeAt(from));
      for (var i = 0; i < rows.length; i++) {
        rows[i]['card_order'] = i + 1;
      }
    });
  }

  Widget badge(Map<String, dynamic> r) {
    final show = shown(r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: show ? const Color(0xFFE0F8EE) : const Color(0xFFEDF0F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            show ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 22,
            color: show ? const Color(0xFF008B43) : muted,
          ),
          const SizedBox(width: 8),
          Text(
            show ? 'Visible' : 'Hidden',
            style: TextStyle(
              color: show ? const Color(0xFF008B43) : muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget typeIcon(Map<String, dynamic> r) {
    const colors = [
      blue,
      Color(0xFFEF3939),
      Color(0xFF00A895),
      Color(0xFF7627FF),
    ];
    const icons = [
      Icons.beach_access_outlined,
      Icons.medical_services_outlined,
      Icons.eco_outlined,
      Icons.calendar_today_outlined,
    ];
    final index = ((int.tryParse('${r['id']}') ?? 1) - 1).abs() % colors.length;
    return CircleAvatar(
      radius: 23,
      backgroundColor: colors[index].withValues(alpha: .12),
      child: Icon(icons[index], color: colors[index], size: 26),
    );
  }

  Widget nameField(Map<String, dynamic> r) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextFormField(
        controller: names['${r['id']}'],
        enabled: !saving,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: shown(r) ? navy : muted,
        ),
        decoration: const InputDecoration(
          hintText: 'Leave type',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          isDense: true,
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
      ),
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: TextFormField(
          controller: abbrs['${r['id']}'],
          enabled: !saving,
          maxLength: 10,
          style: const TextStyle(fontSize: 11, color: muted, letterSpacing: 0.8),
          decoration: const InputDecoration(
            hintText: 'Abbr (e.g. EL)',
            hintStyle: TextStyle(fontSize: 11, color: muted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            isDense: true,
            counterText: '',
          ),
        ),
      ),
    ],
  );

  Widget allowanceField(Map<String, dynamic> r) {
    final controller = allowances['${r['id']}']!;
    void step(double delta) {
      final value = ((double.tryParse(controller.text) ?? 0) + delta).clamp(
        0,
        366,
      );
      controller.text = value % 1 == 0
          ? value.toInt().toString()
          : value.toString();
    }

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: TextFormField(
            controller: controller,
            enabled: !saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIconConstraints: const BoxConstraints(maxWidth: 30),
              suffixIcon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: saving ? null : () => step(.5),
                    child: const Icon(
                      Icons.keyboard_arrow_up,
                      size: 20,
                      color: muted,
                    ),
                  ),
                  InkWell(
                    onTap: saving ? null : () => step(-.5),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              return n == null ||
                      !n.isFinite ||
                      n < 0 ||
                      n > 366 ||
                      n * 2 % 1 != 0
                  ? '0–366, half days'
                  : null;
            },
          ),
        ),
        const SizedBox(width: 12),
        const Text('days', style: TextStyle(color: muted)),
      ],
    );
  }

  Widget visibilitySwitch(Map<String, dynamic> r) => Switch(
    value: flag(r['show_balance_card']),
    onChanged: saving ? null : (v) => setState(() => r['show_balance_card'] = v),
    activeTrackColor: blue,
    activeThumbColor: Colors.white,
    inactiveThumbColor: Colors.white,
    inactiveTrackColor: const Color(0xFF9CA4B5),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  );

  Widget lopToggle(Map<String, dynamic> r) {
    final isLop = flag(r['is_lop']);
    return GestureDetector(
      onTap: saving ? null : () => setState(() => r['is_lop'] = !isLop),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLop ? const Color(0xFFFFECEC) : const Color(0xFFE0F8EE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLop ? const Color(0xFFFFB3B3) : const Color(0xFF9FE0C0),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isLop ? Icons.money_off_outlined : Icons.payments_outlined,
            size: 14,
            color: isLop ? const Color(0xFFD32F2F) : const Color(0xFF008B43),
          ),
          const SizedBox(width: 5),
          Text(
            isLop ? 'Unpaid (LOP)' : 'Paid leave',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isLop ? const Color(0xFFD32F2F) : const Color(0xFF008B43),
            ),
          ),
        ]),
      ),
    );
  }

  Widget halfDayToggle(Map<String, dynamic> r) {
    final allowed = flag(r['allow_half_day']);
    return GestureDetector(
      onTap: saving
          ? null
          : () => setState(() => r['allow_half_day'] = !allowed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: allowed ? const Color(0xFFEAF2FF) : const Color(0xFFEDF0F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: allowed ? const Color(0xFFAFC9FF) : const Color(0xFFD7DDE8),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timelapse_outlined, size: 14, color: allowed ? blue : muted),
          const SizedBox(width: 5),
          Text(
            allowed ? 'Half day on' : 'Half day off',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: allowed ? blue : muted,
            ),
          ),
        ]),
      ),
    );
  }

  Widget modeField(Map<String, dynamic> r) => DropdownButtonFormField<String>(
    initialValue: displayMode(r),
    isExpanded: true,
    style: const TextStyle(color: navy, fontSize: 14),
    decoration: const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    icon: const Icon(Icons.keyboard_arrow_down, color: muted),
    items: const [
      DropdownMenuItem(value: 'BALANCE_USAGE', child: Text('Balance & usage')),
      DropdownMenuItem(value: 'USAGE_ONLY', child: Text('Usage only')),
    ],
    onChanged: saving
        ? null
        : (v) => setState(() {
            r['display_mode'] = v;
            r['usage_only'] = v == 'USAGE_ONLY';
          }),
  );

  Widget activeMenu(Map<String, dynamic> r) => PopupMenuButton<bool>(
    tooltip: 'Leave type availability',
    enabled: !saving,
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.more_vert, size: 18, color: muted),
    onSelected: (v) => setState(() => r['is_active'] = v),
    itemBuilder: (_) => [
      CheckedPopupMenuItem(
        value: true,
        checked: flag(r['is_active']),
        child: const Text('Active — available to request'),
      ),
      CheckedPopupMenuItem(
        value: false,
        checked: !flag(r['is_active']),
        child: const Text('Inactive — unavailable to request'),
      ),
    ],
  );

  Widget setting(Map<String, dynamic> r, int index, bool mobile) {
    final handle = ReorderableDragStartListener(
      index: index,
      enabled: !saving,
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(Icons.drag_indicator, color: muted, size: 22),
      ),
    );
    final title = Row(
      children: [
        typeIcon(r),
        const SizedBox(width: 8),
        Expanded(child: nameField(r)),
      ],
    );
    return Container(
      key: ValueKey(r['id']),
      margin: EdgeInsets.only(bottom: mobile ? 12 : 0),
      padding: EdgeInsets.all(mobile ? 14 : 0),
      decoration: BoxDecoration(
        color: shown(r) ? Colors.white : const Color(0xFFF8FAFE),
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(mobile ? 14 : 0),
      ),
      child: mobile
          ? Column(
              children: [
                Row(
                  children: [
                    handle,
                    Expanded(child: title),
                    badge(r),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allowance',
                            style: TextStyle(color: muted),
                          ),
                          const SizedBox(height: 6),
                          allowanceField(r),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        const Text('Show card', style: TextStyle(color: muted)),
                        visibilitySwitch(r),
                      ],
                    ),
                    activeMenu(r),
                  ],
                ),
                const SizedBox(height: 14),
                modeField(r),
                const SizedBox(height: 10),
                Row(
                  children: [
                    lopToggle(r),
                    const SizedBox(width: 8),
                    halfDayToggle(r),
                    const Spacer(),
                    badge(r),
                    const SizedBox(width: 4),
                    activeMenu(r),
                  ],
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 48, child: handle),
                  Expanded(flex: 25, child: title),
                  Expanded(
                    flex: 19,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: allowanceField(r),
                    ),
                  ),
                  Expanded(
                    flex: 15,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: visibilitySwitch(r),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 24,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: modeField(r),
                    ),
                  ),
                  Expanded(
                    flex: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          lopToggle(r),
                          halfDayToggle(r),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Flexible(child: badge(r)),
                          SizedBox(width: 26, child: activeMenu(r)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget summary(bool mobile) {
    Widget item(IconData icon, String title, String subtitle, Color color) =>
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(mobile ? 8 : 16),
            child: Row(
              children: [
                if (!mobile) ...[
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .08),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: muted,
                          fontSize: mobile ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          item(
            Icons.description_outlined,
            '${rows.length} leave types',
            'Total configured leave types',
            muted,
          ),
          item(
            Icons.visibility_outlined,
            '$visible visible cards',
            'Shown on employee dashboard',
            const Color(0xFF008B43),
          ),
          item(
            Icons.visibility_off_outlined,
            '${rows.length - visible} hidden cards',
            'Hidden from employee dashboard',
            muted,
          ),
        ],
      ),
    );
  }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false)) return;
    if (visible < 2 || visible > 4) {
      setState(() => error = 'Choose between 2 and 4 visible active cards.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final auth = await headers();
      final payload = List.generate(rows.length, (i) {
        final row = rows[i];
        final id = '${row['id']}';
        return {
          'id': row['id'],
          'name': names[id]!.text.trim(),
          'annual_allowance': double.parse(allowances[id]!.text),
          'is_active': flag(row['is_active']),
          'show_balance_card': flag(row['show_balance_card']),
          'display_mode': displayMode(row),
          'usage_only': displayMode(row) == 'USAGE_ONLY',
          'abbreviation': abbrs[id]!.text.trim().toUpperCase(),
          'is_lop': flag(row['is_lop']),
          'allow_half_day': flag(row['allow_half_day']),
        };
      });
      final response = await (widget.client?.put ?? http.put)(
        Uri.parse('${ApiConfig.baseUrl}/attendance/leave/policies'),
        headers: auth,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String reason = 'HTTP ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body['message'] != null) reason = body['message'].toString();
        } catch (_) {}
        throw Exception('Could not save leave settings: $reason');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 1050;
    final theme = Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        primary: blue,
        surface: Colors.white,
      ),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: navy, displayColor: navy),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: line),
        ),
      ),
    );
    void close() {
      if (!saving) Navigator.pop(context);
    }

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '$visible of ${rows.length} visible',
        style: const TextStyle(color: blue, fontWeight: FontWeight.w600),
      ),
    );
    return Theme(
      data: theme,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.all(mobile ? 0 : 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mobile ? 0 : 14),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 1240,
          height: mobile
              ? size.height
              : (size.height - 56).clamp(300, 760).toDouble(),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 24, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (mobile)
                          IconButton(
                            onPressed: saving ? null : close,
                            icon: const Icon(Icons.arrow_back),
                          ),
                        const Expanded(
                          child: Text(
                            'Leave Card Settings',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: navy,
                            ),
                          ),
                        ),
                        if (!mobile) pill,
                        if (!mobile) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: saving ? null : close,
                            icon: const Icon(Icons.close, color: muted),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Set leave balances, paid or unpaid status, and whether each type permits half-day leave.',
                      style: TextStyle(color: muted, fontSize: 16),
                    ),
                    if (mobile) ...[const SizedBox(height: 12), pill],
                  ],
                ),
              ),
              const Divider(height: 1, color: line),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : Form(
                        key: form,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(mobile ? 16 : 22),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info, color: blue, size: 28),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        'Visible cards appear on the employee Leave dashboard. Drag rows to change their order.',
                                        style: TextStyle(
                                          color: blue,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (!mobile)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F6FD),
                                    border: Border.all(color: line),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(
                                        width: 48,
                                        child: Icon(
                                          Icons.drag_indicator,
                                          size: 20,
                                          color: muted,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 25,
                                        child: Text(
                                          'Leave type',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 19,
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 12),
                                          child: Text(
                                            'Allowance',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 15,
                                        child: Text(
                                          'Employee card',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 24,
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 12),
                                          child: Text(
                                            'Display mode',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 20,
                                        child: Text(
                                          'Pay / duration',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ReorderableListView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                onReorderItem: reorder,
                                children: [
                                  for (var i = 0; i < rows.length; i++)
                                    setting(rows[i], i, mobile),
                                ],
                              ),
                              const SizedBox(height: 16),
                              summary(mobile),
                            ],
                          ),
                        ),
                      ),
              ),
              const Divider(height: 1, color: line),
              Padding(
                padding: EdgeInsets.all(mobile ? 16 : 22),
                child: Row(
                  children: [
                    if (!mobile) ...[
                      const Icon(Icons.people_outline, color: muted),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Changes apply to all active employees',
                          style: TextStyle(color: muted),
                        ),
                      ),
                    ],
                    Expanded(
                      flex: mobile ? 1 : 0,
                      child: OutlinedButton(
                        onPressed: saving ? null : close,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 18,
                          ),
                          side: const BorderSide(color: Color(0xFF9EB9FF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: mobile ? 1 : 0,
                      child: FilledButton(
                        onPressed: loading || saving || rows.isEmpty
                            ? null
                            : save,
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(saving ? 'Saving…' : 'Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
