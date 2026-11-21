// name=packages.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;

import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';

class PackagesAdminScreen extends StatefulWidget {
  const PackagesAdminScreen({super.key});

  @override
  State<PackagesAdminScreen> createState() => _PackagesAdminScreenState();
}

class _PackagesAdminScreenState extends State<PackagesAdminScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  static const Color _primary = Color(0xFF0052CC);
  static const Color _primaryDark = Color(0xFF003E99);
  static const Color _primarySoft = Color(0xFFEAF2FF);

  static const Color _accent = Color(0xFF4F8CFF);

  static const Color _success = Color(0xFF16A34A);
  static const Color _successSoft = Color(0xFFDCFCE7);

  static const Color _danger = Color(0xFFDC2626);
  static const Color _dangerSoft = Color(0xFFFEE2E2);

  static const Color _warning = Color(0xFFF59E0B);
  static const Color _warningSoft = Color(0xFFFFF7E6);

  static const Color _background = Color(0xFFF5F8FC);
  static const Color _card = Colors.white;

  static const Color _ink = Color(0xFF172033);
  static const Color _text = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);

  static const Color _border = Color(0xFFE2E8F0);
  static const Color _softBorder = Color(0xFFEDF2F7);

  bool _showAllPackages = true;
  List<Map<String, dynamic>> packagesData = [];
  bool _loadingPackages = true;
  String? _packagesError;
  String _searchQuery = '';

  // ── Category master + filter ─────────────────────────────────
  static const String _allCategories = 'All';
  static const String _uncategorized = 'Uncategorized';
  String _selectedCategory = _allCategories;

  /// Category master list from GET /package-categories.
  /// Each row: { id, name, color ("#RRGGBB"), sort_order }.
  List<Map<String, dynamic>> _categories = [];

  /// Colours the admin can pick for a category.
  static const List<Color> _categorySwatches = [
    Color(0xFF0052CC),
    Color(0xFF0E9F6E),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF0891B2),
    Color(0xFFD97706),
    Color(0xFF64748B),
  ];

  static const Map<String, IconData> _categoryIcons = {
    'social media': Icons.groups_rounded,
    'seo': Icons.travel_explore_rounded,
    'website': Icons.language_rounded,
    'web development': Icons.language_rounded,
    'branding': Icons.palette_rounded,
    'performance ads': Icons.campaign_rounded,
    'ads': Icons.campaign_rounded,
    'video production': Icons.videocam_rounded,
    'uncategorized': Icons.category_outlined,
  };

  int? _asInt(dynamic v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  Map<String, dynamic>? _categoryById(int? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (_asInt(c['id']) == id) return c;
    }
    return null;
  }

  Map<String, dynamic>? _categoryByName(String name) {
    final key = name.trim().toLowerCase();
    for (final c in _categories) {
      if ((c['name']?.toString() ?? '').trim().toLowerCase() == key) {
        return c;
      }
    }
    return null;
  }

  /// Category name of a package: master lookup by category_id first,
  /// then any name the API returned, else "Uncategorized".
  String _categoryOf(Map<String, dynamic> pkg) {
    final master = _categoryById(_asInt(pkg['category_id']));
    if (master != null) return master['name']?.toString() ?? _uncategorized;
    final value = (pkg['category_name'] ?? pkg['category'])
            ?.toString()
            .trim() ??
        '';
    return value.isEmpty ? _uncategorized : value;
  }

  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return null;
    final v = int.tryParse(clean, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  String _toHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Color _categoryColor(String category) {
    if (category == _uncategorized) return _muted;
    final fromMaster = _parseHex(_categoryByName(category)?['color']?.toString());
    if (fromMaster != null) return fromMaster;
    final hash = category.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b);
    return _categorySwatches[hash % _categorySwatches.length];
  }

  IconData _categoryIcon(String category) {
    return _categoryIcons[category.trim().toLowerCase()] ??
        Icons.sell_rounded;
  }

  /// Filter chips: every master category (even with 0 packages), then any
  /// names not in the master, then Uncategorized when some exist.
  List<MapEntry<String, int>> _categoryCounts() {
    final Map<String, int> counts = {};
    for (final pkg in packagesData) {
      final c = _categoryOf(pkg);
      counts[c] = (counts[c] ?? 0) + 1;
    }

    final List<MapEntry<String, int>> entries = [];
    final Set<String> seen = {};
    for (final c in _categories) {
      final name = c['name']?.toString() ?? '';
      if (name.isEmpty || !seen.add(name)) continue;
      entries.add(MapEntry(name, counts[name] ?? 0));
    }
    final others = counts.keys
        .where((n) => !seen.contains(n) && n != _uncategorized)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final n in others) {
      entries.add(MapEntry(n, counts[n]!));
    }
    if ((counts[_uncategorized] ?? 0) > 0) {
      entries.add(MapEntry(_uncategorized, counts[_uncategorized]!));
    }
    return entries;
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/package-categories'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = List<Map<String, dynamic>>.from(
          (body['data'] as List?) ?? [],
        );
        list.sort((a, b) {
          final r = (_asInt(a['sort_order']) ?? 0)
              .compareTo(_asInt(b['sort_order']) ?? 0);
          return r != 0
              ? r
              : (a['name']?.toString() ?? '')
                  .toLowerCase()
                  .compareTo((b['name']?.toString() ?? '').toLowerCase());
        });
        if (mounted) {
          setState(() {
            _categories = list;
          });
        }
        return;
      }
    } catch (_) {}
  }

  /// Create (id == null) or update a category. Returns an error or null.
  Future<String?> _saveCategory({
    int? id,
    required String name,
    required String color,
  }) async {
    try {
      final uri = Uri.parse(
        id == null
            ? '$_baseUrl/package-categories'
            : '$_baseUrl/package-categories/$id',
      );
      final payload = jsonEncode({'name': name, 'color': color});
      final headers = {'Content-Type': 'application/json'};
      final response = id == null
          ? await http.post(uri, headers: headers, body: payload)
          : await http.put(uri, headers: headers, body: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchCategories();
        await _fetchPackages();
        return null;
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['message'] as String? ?? 'Failed to save category';
      } catch (_) {
        return 'Failed to save category';
      }
    } catch (_) {
      return 'Cannot connect to server';
    }
  }

  Future<String?> _deleteCategory(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/package-categories/$id'),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _fetchCategories();
        await _fetchPackages();
        return null;
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['message'] as String? ?? 'Failed to delete category';
      } catch (_) {
        return 'Failed to delete category';
      }
    } catch (_) {
      return 'Cannot connect to server';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchPackages();
  }

  Future<void> _fetchPackages() async {
    setState(() {
      _loadingPackages = true;
      _packagesError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/packages'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        setState(() {
          packagesData = List<Map<String, dynamic>>.from(
            body['data'] as List,
          );

          if (_selectedCategory != _allCategories &&
              _categoryByName(_selectedCategory) == null &&
              !packagesData
                  .any((p) => _categoryOf(p) == _selectedCategory)) {
            _selectedCategory = _allCategories;
          }

          _loadingPackages = false;
        });
      } else {
        setState(() {
          _packagesError = 'Server returned ${response.statusCode}';
          _loadingPackages = false;
        });
      }
    } catch (e) {
      setState(() {
        _packagesError = 'Cannot connect to server';
        _loadingPackages = false;
      });
    }
  }

  Future<String?> _createPackage(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/packages'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        await _fetchPackages();
        return null;
      } else {
        final body =
            jsonDecode(response.body) as Map<String, dynamic>;

        return body['message'] as String? ??
            'Failed to create package';
      }
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  Future<String?> _updatePackage(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/packages/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        await _fetchPackages();
        return null;
      } else {
        final body =
            jsonDecode(response.body) as Map<String, dynamic>;

        return body['message'] as String? ??
            'Failed to update package';
      }
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  Future<void> _deletePackage(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/packages/$id'),
      );

      if (response.statusCode == 200) {
        await _fetchPackages();

        if (packagesData.length <= 3) {
          _showAllPackages = false;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: _danger,
              content: Text('Package deleted successfully'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
              content: Text('Failed to delete package'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text('Cannot connect to server'),
          ),
        );
      }
    }
  }

  void _showExtraAddTaskPopup(
    StateSetter setDialogState,
    List<TextEditingController> taskCtrls,
  ) async {
    try {
      final taskMasterResponse = await http.get(
        Uri.parse('$_baseUrl/task-master'),
      );

      if (taskMasterResponse.statusCode != 200) {
        return;
      }

      final taskMasterList =
          List<Map<String, dynamic>>.from(
        jsonDecode(taskMasterResponse.body)['data'] ?? [],
      );

      if (!mounted) {
        return;
      }

      final Map<String, String> roleMapping = {
        'ads_handler_task': 'Ads Handler',
        'page_handler_task': 'Page Handler',
        'graphic_designer_task': 'Designer',
        'videographer_task': 'Videographer',
        'video_editor_task': 'Video Editor',
        'ui_ux_designer_task': 'UI/UX Designer',
        'developer_task': 'Developer',
      };

      List<String> availableRoleKeys = taskMasterList
          .map(
            (t) => t['role_key']?.toString() ?? '',
          )
          .where(
            (k) => k.isNotEmpty,
          )
          .toSet()
          .toList();

      if (availableRoleKeys.isEmpty) {
        return;
      }

      String? selectedRoleKey = availableRoleKeys.first;
      Map<int, int> selectedTaskCounts = {};

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setSubState) {
              final filteredTasks = taskMasterList
                  .where(
                    (t) => t['role_key'] == selectedRoleKey,
                  )
                  .toList();

              return Dialog(
                insetPadding: const EdgeInsets.all(16),
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 600,
                  constraints: const BoxConstraints(
                    maxHeight: 680,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          22,
                          20,
                          16,
                          18,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _border,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _primarySoft,
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                              ),
                              child: const Icon(
                                Icons
                                    .playlist_add_check_rounded,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Package Tasks',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight:
                                          FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Choose role, tasks and required quantity',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Role',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: selectedRoleKey,
                                isExpanded: true,
                                decoration:
                                    _premiumInputDecoration(
                                  hint: 'Select role',
                                ),
                                items: availableRoleKeys
                                    .map((rKey) {
                                  final displayName =
                                      roleMapping[rKey] ??
                                          rKey
                                              .replaceAll(
                                                '_',
                                                ' ',
                                              )
                                              .toUpperCase();

                                  return DropdownMenuItem<
                                      String>(
                                    value: rKey,
                                    child: Text(
                                      displayName,
                                      style:
                                          const TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setSubState(() {
                                    selectedRoleKey = val;
                                    selectedTaskCounts
                                        .clear();
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.task_alt_rounded,
                                    size: 17,
                                    color: _primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Select Tasks & Quantity',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: _primarySoft,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        20,
                                      ),
                                    ),
                                    child: Text(
                                      '${selectedTaskCounts.length} Selected',
                                      style:
                                          const TextStyle(
                                        color: _primary,
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (filteredTasks.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.all(
                                    28,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _background,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      16,
                                    ),
                                    border: Border.all(
                                      color: _border,
                                    ),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(
                                        Icons
                                            .inbox_outlined,
                                        color: _muted,
                                        size: 30,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No tasks found for this role',
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...filteredTasks.map((task) {
                                  final int taskId =
                                      task['id'];
                                  final String taskName =
                                      task['task_name'] ??
                                          '';
                                  final bool isSelected =
                                      selectedTaskCounts
                                          .containsKey(
                                    taskId,
                                  );

                                  return Container(
                                    margin: const EdgeInsets
                                        .only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _primarySoft
                                          : Colors.white,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        14,
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? _accent
                                            : _border,
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      title: Text(
                                        taskName,
                                        style:
                                            const TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                          color: _text,
                                        ),
                                      ),
                                      value: isSelected,
                                      dense: true,
                                      controlAffinity:
                                          ListTileControlAffinity
                                              .leading,
                                      contentPadding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 8,
                                      ),
                                      activeColor: _primary,
                                      onChanged: (checked) {
                                        setSubState(() {
                                          if (checked ==
                                              true) {
                                            selectedTaskCounts[
                                                    taskId] =
                                                1;
                                          } else {
                                            selectedTaskCounts
                                                .remove(
                                              taskId,
                                            );
                                          }
                                        });
                                      },
                                      secondary: isSelected
                                          ? SizedBox(
                                              width: 80,
                                              child:
                                                  TextFormField(
                                                initialValue:
                                                    selectedTaskCounts[
                                                            taskId]
                                                        .toString(),
                                                keyboardType:
                                                    TextInputType
                                                        .number,
                                                textAlign:
                                                    TextAlign
                                                        .center,
                                                style:
                                                    const TextStyle(
                                                  fontSize:
                                                      12,
                                                  fontWeight:
                                                      FontWeight
                                                          .w700,
                                                ),
                                                decoration:
                                                    _premiumInputDecoration(
                                                  hint:
                                                      'Qty',
                                                  dense:
                                                      true,
                                                ),
                                                onChanged:
                                                    (val) {
                                                  final parsed =
                                                      int.tryParse(
                                                    val,
                                                  );
                                                  if (parsed !=
                                                          null &&
                                                      parsed >
                                                          0) {
                                                    selectedTaskCounts[
                                                            taskId] =
                                                        parsed;
                                                  }
                                                },
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: _border,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(context),
                                style: OutlinedButton
                                    .styleFrom(
                                  minimumSize:
                                      const Size(0, 46),
                                  side: const BorderSide(
                                    color: _border,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: _text,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setSubState(() {
                                    for (var entry
                                        in selectedTaskCounts
                                            .entries) {
                                      final taskObj =
                                          taskMasterList
                                              .firstWhere(
                                        (t) =>
                                            t['id'] ==
                                            entry.key,
                                      );
                                      final name =
                                          taskObj['task_name'];
                                      final rKey =
                                          taskObj['role_key'];
                                      final count =
                                          entry.value;

                                      taskCtrls.add(
                                        TextEditingController(
                                          text:
                                              '$name ($count) [$rKey]',
                                        ),
                                      );
                                    }
                                  });
                                  Navigator.pop(context);
                                },
                                icon: const Icon(
                                  Icons.add_task_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                style: ElevatedButton
                                    .styleFrom(
                                  backgroundColor: _primary,
                                  elevation: 0,
                                  minimumSize:
                                      const Size(0, 46),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),
                                ),
                                label: const Text(
                                  'Add Selected Tasks',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error loading task master roles: $e');
    }
  }

  void _showPackageFormDialog(
    BuildContext context, {
    int? editIndex,
  }) {
    final bool isEdit = editIndex != null;
    final Map<String, dynamic>? existing =
        isEdit ? packagesData[editIndex] : null;

    final TextEditingController titleCtrl =
        TextEditingController(
      text: existing?["title"] as String? ?? "",
    );

    final TextEditingController subtitleCtrl =
        TextEditingController(
      text: existing?["subtitle"] as String? ?? "",
    );

    final TextEditingController priceCtrl =
        TextEditingController(
      text: existing?["price"] as String? ?? "",
    );

    final TextEditingController periodCtrl =
        TextEditingController(
      text: existing?["period"] as String? ?? "/Month",
    );

    bool isPopular =
        (existing?["is_popular"] as bool?) ?? false;

    int? selectedCategoryId = _asInt(existing?["category_id"]);

    final List<TextEditingController> featureCtrls =
        existing != null
            ? List<String>.from(
                (existing["features"] as List?) ?? [],
              )
                .map(
                  (String f) => TextEditingController(
                    text: f,
                  ),
                )
                .toList()
            : [
                TextEditingController(),
              ];

    final List<TextEditingController> packageTaskCtrls =
        existing != null &&
                existing["package_tasks"] != null
            ? List<dynamic>.from(
                existing["package_tasks"],
              ).map((t) {
                if (t is Map) {
                  return TextEditingController(
                    text:
                        "${t['task_name']} (${t['count']}) [${t['role_key']}]",
                  );
                }
                return TextEditingController(
                  text: t.toString(),
                );
              }).toList()
            : [];

    String? dialogError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            void addFeatureRow() {
              setDialogState(() {
                featureCtrls.add(
                  TextEditingController(),
                );
              });
            }

            void removeFeatureRow(int idx) {
              setDialogState(() {
                featureCtrls.removeAt(idx);
              });
            }

            void removePackageTaskRow(int idx) {
              setDialogState(() {
                packageTaskCtrls.removeAt(idx);
              });
            }

            Future<void> handleSubmit() async {
              final String title = titleCtrl.text.trim();
              final String subtitle = subtitleCtrl.text.trim();
              final String price = priceCtrl.text.trim();
              final String period = periodCtrl.text.trim();

              final List<String> features = featureCtrls
                  .map((c) => c.text.trim())
                  .where((f) => f.isNotEmpty)
                  .toList();

              final List<Map<String, dynamic>>
                  packageTasksPayload = [];

              for (var ctrl in packageTaskCtrls) {
                final text = ctrl.text.trim();
                if (text.isNotEmpty) {
                  final match = RegExp(
                    r'^(.*?)\s*\((\d+)\)\s*\[(.*?)\]$',
                  ).firstMatch(text);

                  if (match != null) {
                    packageTasksPayload.add({
                      "task_name": match.group(1)?.trim(),
                      "count": int.tryParse(
                            match.group(2) ?? '1',
                          ) ??
                          1,
                      "role_key": match.group(3)?.trim(),
                    });
                  } else {
                    packageTasksPayload.add({
                      "task_name": text,
                      "count": 1,
                      "role_key": "general_task",
                    });
                  }
                }
              }

              if (title.isEmpty ||
                  price.isEmpty ||
                  (features.isEmpty &&
                      packageTasksPayload.isEmpty)) {
                setDialogState(() {
                  dialogError =
                      'Please fill Package Title, Price, and at least one feature or task';
                });
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                dialogError = null;
              });

              final Map<String, dynamic> payload = {
                "title": title,
                "subtitle": subtitle,
                "price": price,
                "period": period.isEmpty ? "/Month" : period,
                "isPopular": isPopular,
                "category_id": selectedCategoryId,
                "features": features,
                "package_tasks": packageTasksPayload,
              };

              final String? error = isEdit
                  ? await _updatePackage(
                      existing!["id"] as int,
                      payload,
                    )
                  : await _createPackage(payload);

              if (error == null) {
                if (context.mounted) {
                  Navigator.pop(context);
                }

                if (mounted) {
                  ScaffoldMessenger.of(this.context)
                      .showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _success,
                      content: Text(
                        isEdit
                            ? 'Package updated successfully'
                            : 'Package created successfully',
                      ),
                    ),
                  );
                }
              } else {
                setDialogState(() {
                  isSubmitting = false;
                  dialogError = error;
                });
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: Container(
                width: 780,
                constraints: const BoxConstraints(
                  maxHeight: 820,
                ),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.20,
                      ),
                      blurRadius: 50,
                      offset: const Offset(0, 25),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        26,
                        22,
                        18,
                        20,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _border,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  _primary,
                                  _accent,
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                            ),
                            child: Icon(
                              isEdit
                                  ? Icons
                                      .edit_note_rounded
                                  : Icons.add_box_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit
                                      ? 'Edit Package'
                                      : 'Create New Package',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.w900,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isEdit
                                      ? 'Update service package information and tasks'
                                      : 'Create a new service plan for your clients',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(
                                      context,
                                    ),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dialogError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          22,
                          18,
                          22,
                          0,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                            14,
                          ),
                          decoration: BoxDecoration(
                            color: _dangerSoft,
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            border: Border.all(
                              color: const Color(
                                0xFFFCA5A5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons
                                    .error_outline_rounded,
                                size: 20,
                                color: _danger,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: _danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: LayoutBuilder(
                          builder: (
                            context,
                            constraints,
                          ) {
                            final isMobile =
                                constraints.maxWidth < 620;

                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _buildDialogSection(
                                  icon: Icons
                                      .inventory_2_rounded,
                                  title:
                                      'Package Information',
                                  subtitle:
                                      'Basic information about your service package',
                                ),
                                const SizedBox(height: 18),
                                _dialogField(
                                  label: "Package Title *",
                                  hint: "e.g. Kickstart Package",
                                  controller: titleCtrl,
                                ),
                                const SizedBox(height: 14),
                                _dialogField(
                                  label: "Subtitle",
                                  hint:
                                      "e.g. SMART LAUNCH FOR GROWING BRANDS",
                                  controller: subtitleCtrl,
                                ),
                                const SizedBox(height: 14),
                                _buildCategoryPicker(
                                  selectedId: selectedCategoryId,
                                  onChanged: (id) => setDialogState(() {
                                    selectedCategoryId = id;
                                  }),
                                  setDialogState: setDialogState,
                                ),
                                const SizedBox(height: 14),
                                if (isMobile)
                                  Column(
                                    children: [
                                      _dialogField(
                                        label: "Price *",
                                        hint: "e.g. ₹8,000",
                                        controller: priceCtrl,
                                      ),
                                      const SizedBox(height: 14),
                                      _dialogField(
                                        label: "Period",
                                        hint: "e.g. /Month",
                                        controller: periodCtrl,
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _dialogField(
                                          label: "Price *",
                                          hint: "e.g. ₹8,000",
                                          controller: priceCtrl,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _dialogField(
                                          label: "Period",
                                          hint: "e.g. /Month",
                                          controller: periodCtrl,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(
                                    14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPopular
                                        ? _primarySoft
                                        : _background,
                                    borderRadius:
                                        BorderRadius.circular(
                                      16,
                                    ),
                                    border: Border.all(
                                      color: isPopular
                                          ? const Color(
                                              0xFFBFD7FF,
                                            )
                                          : _border,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: isPopular,
                                    onChanged: (v) =>
                                        setDialogState(() {
                                      isPopular = v ?? false;
                                    }),
                                    title: const Text(
                                      "Mark as Most Popular",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: _text,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      "Highlight this package as a recommended plan",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _muted,
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity
                                            .leading,
                                    contentPadding:
                                        EdgeInsets.zero,
                                    dense: true,
                                    activeColor: _primary,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                _buildDialogSection(
                                  icon: Icons
                                      .auto_awesome_rounded,
                                  title: 'Package Features',
                                  subtitle:
                                      'Add the features included in this package',
                                  action: TextButton.icon(
                                    onPressed: addFeatureRow,
                                    icon: const Icon(
                                      Icons
                                          .add_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Add Feature',
                                    ),
                                    style: TextButton
                                        .styleFrom(
                                      foregroundColor:
                                          _primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ...featureCtrls
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final int idx = entry.key;
                                  final TextEditingController
                                      ctrl = entry.value;

                                  return Padding(
                                    padding: const EdgeInsets
                                        .only(bottom: 10),
                                    child: _buildFeatureRow(
                                      controller: ctrl,
                                      index: idx,
                                      canRemove:
                                          featureCtrls
                                                  .length >
                                              1,
                                      onRemove: () =>
                                          removeFeatureRow(
                                        idx,
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 30),
                                _buildDialogSection(
                                  icon: Icons
                                      .task_alt_rounded,
                                  title: 'Package Tasks',
                                  subtitle:
                                      'Select tasks from Task Master and assign quantity',
                                  action: TextButton.icon(
                                    onPressed: () =>
                                        _showExtraAddTaskPopup(
                                      setDialogState,
                                      packageTaskCtrls,
                                    ),
                                    icon: const Icon(
                                      Icons
                                          .playlist_add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Add Tasks',
                                    ),
                                    style: TextButton
                                        .styleFrom(
                                      foregroundColor:
                                          _success,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (packageTaskCtrls.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(
                                      24,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _background,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        16,
                                      ),
                                      border: Border.all(
                                        color: _border,
                                      ),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons
                                              .add_task_rounded,
                                          size: 30,
                                          color: _muted,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'No tasks added yet',
                                          style: TextStyle(
                                            color: _muted,
                                            fontWeight:
                                                FontWeight
                                                    .w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Use "Add Tasks" to select tasks from Task Master',
                                          textAlign:
                                              TextAlign
                                                  .center,
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...packageTaskCtrls
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final int idx = entry.key;
                                    final TextEditingController
                                        ctrl = entry.value;

                                    return Padding(
                                      padding: const EdgeInsets
                                          .only(bottom: 10),
                                      child: _buildTaskRow(
                                        controller: ctrl,
                                        index: idx,
                                        onRemove: () =>
                                            removePackageTaskRow(
                                          idx,
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        22,
                        16,
                        22,
                        18,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAFCFF),
                        border: Border(
                          top: BorderSide(
                            color: _border,
                          ),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (
                          context,
                          constraints,
                        ) {
                          final isMobile =
                              constraints.maxWidth < 600;

                          final deleteButton = isEdit
                              ? OutlinedButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () {
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                _buildDeleteConfirmation(
                                              existing!,
                                              context,
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    Icons
                                        .delete_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text("Delete"),
                                  style: OutlinedButton
                                      .styleFrom(
                                    foregroundColor: _danger,
                                    minimumSize:
                                        const Size(0, 48),
                                    side: const BorderSide(
                                      color: Color(
                                        0xFFFCA5A5,
                                      ),
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                    ),
                                  ),
                                )
                              : null;

                          final cancelButton = OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(
                                      context,
                                    ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(
                                color: _border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );

                          final saveButton = ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              elevation: 0,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isEdit
                                            ? Icons
                                                .save_rounded
                                            : Icons
                                                .add_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isEdit
                                            ? "Save Changes"
                                            : "Create Package",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                              FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          );

                          if (isMobile) {
                            return Column(
                              children: [
                                if (deleteButton != null) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: deleteButton,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: cancelButton,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: saveButton,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              ?deleteButton,
                              if (deleteButton != null)
                                const SizedBox(width: 10),
                              const Spacer(),
                              SizedBox(
                                width: 120,
                                child: cancelButton,
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 170,
                                child: saveButton,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _premiumInputDecoration({
    required String hint,
    bool dense = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 12,
      ),
      filled: true,
      fillColor: const Color(0xFFFAFCFF),
      isDense: dense,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: _border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _dialogField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 13,
            color: _ink,
            fontWeight: FontWeight.w600,
          ),
          decoration: _premiumInputDecoration(
            hint: hint,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPicker({
    required int? selectedId,
    required ValueChanged<int?> onChanged,
    required StateSetter setDialogState,
  }) {
    Widget chip({
      required String label,
      required Color color,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 15,
          color: selected ? Colors.white : color,
        ),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : _text,
        ),
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? color : _border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onSelected: (_) => onTap(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await _showCategoryManagerDialog(context);
                setDialogState(() {});
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Category'),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_categories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No categories yet. Tap "New Category" to add one to the master.',
              style: TextStyle(fontSize: 11, color: _text),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                label: 'None',
                color: _muted,
                icon: Icons.block_rounded,
                selected: selectedId == null,
                onTap: () => onChanged(null),
              ),
              ..._categories.map((c) {
                final id = _asInt(c['id']);
                final name = c['name']?.toString() ?? '';
                return chip(
                  label: name,
                  color: _categoryColor(name),
                  icon: _categoryIcon(name),
                  selected: id != null && id == selectedId,
                  onTap: () => onChanged(id),
                );
              }),
            ],
          ),
      ],
    );
  }

  /// "Add Category" master: list, add, edit and delete package categories.
  Future<void> _showCategoryManagerDialog(BuildContext context) async {
    final TextEditingController nameCtrl = TextEditingController();
    Color selectedColor = _categorySwatches.first;
    int? editingId;
    bool busy = false;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void resetForm() {
              editingId = null;
              nameCtrl.clear();
              selectedColor = _categorySwatches.first;
              error = null;
            }

            Future<void> submit() async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                setDialogState(() => error = 'Please enter a category name');
                return;
              }
              final duplicate = _categoryByName(name);
              if (duplicate != null && _asInt(duplicate['id']) != editingId) {
                setDialogState(() => error = '"$name" already exists');
                return;
              }
              setDialogState(() {
                busy = true;
                error = null;
              });
              final err = await _saveCategory(
                id: editingId,
                name: name,
                color: _toHex(selectedColor),
              );
              setDialogState(() {
                busy = false;
                if (err == null) {
                  resetForm();
                } else {
                  error = err;
                }
              });
            }

            Future<void> remove(Map<String, dynamic> c) async {
              final id = _asInt(c['id']);
              if (id == null) return;
              final name = c['name']?.toString() ?? '';
              final count = packagesData
                  .where((p) => _categoryOf(p) == name)
                  .length;
              final ok = await showDialog<bool>(
                context: dialogContext,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Delete category?'),
                  content: Text(
                    count == 0
                        ? 'Delete "$name"?'
                        : 'Delete "$name"? Its $count package${count == 1 ? '' : 's'} will move to Uncategorized.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              setDialogState(() => busy = true);
              final err = await _deleteCategory(id);
              setDialogState(() {
                busy = false;
                if (editingId == id) resetForm();
                error = err;
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: Container(
                width: 520,
                constraints: const BoxConstraints(maxHeight: 680),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 50,
                      offset: const Offset(0, 25),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 14, 18),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_primary, _accent],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.category_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Package Categories',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: _ink,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Add, rename or remove categories used to group packages',
                                  style: TextStyle(fontSize: 10, color: _muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    // Form
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            editingId == null ? 'Add Category' : 'Edit Category',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameCtrl,
                            enabled: !busy,
                            onSubmitted: (_) => submit(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: _ink,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: _premiumInputDecoration(
                              hint: 'e.g. Social Media, SEO, Website',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categorySwatches.map((color) {
                              final bool on = color.toARGB32() ==
                                  selectedColor.toARGB32();
                              return InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: busy
                                    ? null
                                    : () => setDialogState(
                                          () => selectedColor = color,
                                        ),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: on ? _ink : Colors.white,
                                      width: on ? 2.5 : 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.30),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: on
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _dangerSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                error!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              if (editingId != null)
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setDialogState(resetForm),
                                  child: const Text('Cancel edit'),
                                ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: busy ? null : submit,
                                icon: busy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        editingId == null
                                            ? Icons.add_rounded
                                            : Icons.save_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                label: Text(
                                  editingId == null ? 'Add Category' : 'Save Changes',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24, color: _border),
                    // List
                    Flexible(
                      child: _categories.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.fromLTRB(24, 6, 24, 26),
                              child: Text(
                                'No categories yet. Add your first one above.',
                                style: TextStyle(fontSize: 11, color: _muted),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                              itemCount: _categories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final c = _categories[i];
                                final name = c['name']?.toString() ?? '';
                                final color = _categoryColor(name);
                                final count = packagesData
                                    .where((p) => _categoryOf(p) == name)
                                    .length;
                                final bool isEditing =
                                    _asInt(c['id']) == editingId;
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                                  decoration: BoxDecoration(
                                    color: isEditing ? _primarySoft : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isEditing
                                          ? const Color(0xFFBFD7FF)
                                          : _border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          _categoryIcon(name),
                                          size: 18,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: _ink,
                                              ),
                                            ),
                                            Text(
                                              '$count package${count == 1 ? '' : 's'}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: _muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed: busy
                                            ? null
                                            : () => setDialogState(() {
                                                  editingId = _asInt(c['id']);
                                                  nameCtrl.text = name;
                                                  selectedColor = color;
                                                  error = null;
                                                }),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: _primary,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        onPressed: busy ? null : () => remove(c),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: _danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    // nameCtrl is not disposed here: the dialog may still be animating out.
  }


  Widget _buildCategoryFilterBar() {
    final entries = _categoryCounts();
    if (entries.isEmpty) return const SizedBox.shrink();

    Widget chip({
      required String label,
      required int count,
      required IconData icon,
      required Color color,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected ? color : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? color : _border,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? Colors.white : color,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : _text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          chip(
            label: 'All',
            count: packagesData.length,
            icon: Icons.apps_rounded,
            color: _primary,
            selected: _selectedCategory == _allCategories,
            onTap: () => setState(() {
              _selectedCategory = _allCategories;
            }),
          ),
          ...entries.map(
            (e) => chip(
              label: e.key,
              count: e.value,
              icon: _categoryIcon(e.key),
              color: _categoryColor(e.key),
              selected: _selectedCategory == e.key,
              onTap: () => setState(() {
                _selectedCategory = e.key;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogSection({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: _primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }

  Widget _buildFeatureRow({
    required TextEditingController controller,
    required int index,
    required bool canRemove,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _successSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 17,
              color: _success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
              decoration: _premiumInputDecoration(
                hint: 'Feature description',
                dense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: _danger,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow({
    required TextEditingController controller,
    required int index,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD8E8FF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 17,
              color: _primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
              decoration: _premiumInputDecoration(
                hint: 'Task Name (Count) [role_key]',
                dense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: _danger,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteConfirmation(
    Map<String, dynamic> existing,
    BuildContext dialogContext,
  ) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _dangerSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: _danger,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Delete Package',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      content: Text(
        'Remove "${existing["title"]}"? This action cannot be undone.',
        style: const TextStyle(
          fontSize: 12,
          color: _muted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.pop(context);
            _deletePackage(existing["id"] as int);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _danger,
          ),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchQuery.trim().toLowerCase();

    final filteredPackages = packagesData.where((pkg) {
      if (_selectedCategory != _allCategories &&
          _categoryOf(pkg) != _selectedCategory) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final title =
          pkg['title']?.toString().toLowerCase() ?? '';
      final subtitle =
          pkg['subtitle']?.toString().toLowerCase() ?? '';
      final price =
          pkg['price']?.toString().toLowerCase() ?? '';
      final category = _categoryOf(pkg).toLowerCase();

      return title.contains(query) ||
          subtitle.contains(query) ||
          price.contains(query) ||
          category.contains(query);
    }).toList();

    final List<Map<String, dynamic>> visiblePackages =
        _showAllPackages
            ? filteredPackages
            : filteredPackages.take(3).toList();

    final bool hasMorePackages = filteredPackages.length > 3;

    final popularCount = packagesData
        .where((p) => p['is_popular'] == true)
        .length;

    return AdminLayout(
      pageTitle: "Packages Management",
      currentRoute: "/packages",
      onSearch: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 700;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroSection(isMobile: isMobile),
              
              const SizedBox(height: 28),
              _buildPackagesSectionHeader(
                isMobile: isMobile,
                total: filteredPackages.length,
                hasMore: hasMorePackages,
              ),
              if (!_loadingPackages &&
                  _packagesError == null &&
                  (packagesData.isNotEmpty || _categories.isNotEmpty)) ...[
                const SizedBox(height: 14),
                _buildCategoryFilterBar(),
              ],
              const SizedBox(height: 16),
              if (_loadingPackages)
                _buildLoadingState()
              else if (_packagesError != null)
                _buildErrorState()
              else if (filteredPackages.isEmpty)
                _buildEmptyState()
              else
                _buildPackagesGrid(
                  visiblePackages,
                  isMobile: isMobile,
                ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroSection({required bool isMobile}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: const Text(
            'SERVICE MANAGEMENT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Service Packages',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Create, manage and customize your digital service packages.',
          style: TextStyle(
            fontSize: isMobile ? 11 : 12,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );

    final button = ElevatedButton.icon(
      onPressed: () => _showPackageFormDialog(context),
      icon: const Icon(
        Icons.add_rounded,
        color: _primary,
        size: 20,
      ),
      label: const Text(
        'Create Package',
        style: TextStyle(
          color: _primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );

    final categoryButton = OutlinedButton.icon(
      onPressed: () => _showCategoryManagerDialog(context),
      icon: const Icon(
        Icons.category_rounded,
        color: Colors.white,
        size: 19,
      ),
      label: const Text(
        'Add Category',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 22 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primary,
            _primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: categoryButton),
                    const SizedBox(width: 10),
                    Expanded(child: button),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 20),
                categoryButton,
                const SizedBox(width: 10),
                button,
              ],
            ),
    );
  }



  Widget _buildPackagesSectionHeader({
    required bool isMobile,
    required int total,
    required bool hasMore,
  }) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Packages',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _selectedCategory == _allCategories
              ? '$total package${total == 1 ? '' : 's'} available'
              : '$total package${total == 1 ? '' : 's'} in $_selectedCategory',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasMore)
          TextButton.icon(
            onPressed: () => setState(() => _showAllPackages = !_showAllPackages),
            icon: Icon(
              _showAllPackages
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 16,
            ),
            label: Text(_showAllPackages ? 'Less' : 'View All'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        IconButton(
          tooltip: 'Refresh packages',
          onPressed: _fetchPackages,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          color: _primary,
          style: IconButton.styleFrom(
            backgroundColor: _primarySoft,
            minimumSize: const Size(40, 40),
          ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: title),
        actions,
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _primary,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading packages...',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: _dangerSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: _danger,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unable to load packages',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _packagesError ?? 'Something went wrong',
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _fetchPackages,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Try Again',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isSearching = _searchQuery.trim().isNotEmpty ||
        _selectedCategory != _allCategories;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isSearching ? 'No packages found' : 'No packages yet',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isSearching
                ? (_selectedCategory != _allCategories
                    ? 'No packages match in $_selectedCategory. Try another category or keyword.'
                    : 'Try a different search keyword.')
                : 'Create your first service package to get started.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: _muted,
            ),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showPackageFormDialog(context),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Create Package',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPackagesGrid(
    List<Map<String, dynamic>> visiblePackages, {
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: visiblePackages.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildPackageCard(
              pkg: entry.value,
              index: entry.key,
              isMobile: true,
            ),
          );
        }).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth < 900 ? 2 : 3;
        final double ratio = crossAxisCount == 3 ? 0.86 : 1.05;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visiblePackages.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) => _buildPackageCard(
            pkg: visiblePackages[index],
            index: index,
            isMobile: false,
          ),
        );
      },
    );
  }

  Widget _buildPackageCard({
    required Map<String, dynamic> pkg,
    required int index,
    required bool isMobile,
  }) {
    final bool isPopular = pkg['is_popular'] == true;
    final String tierLabel = 'TIER ${(index + 1).toString().padLeft(2, '0')}';
    final List<String> features = List<String>.from((pkg['features'] as List?) ?? []);
    final String category = _categoryOf(pkg);
    final Color categoryColor = _categoryColor(category);
    final int originalIndex = packagesData.indexWhere((p) => p['id'] == pkg['id']);

    void openEdit() {
      if (originalIndex >= 0) {
        _showPackageFormDialog(context, editIndex: originalIndex);
      }
    }

    final contentColor = isPopular ? Colors.white : _ink;
    final mutedColor = isPopular ? Colors.white.withValues(alpha: 0.74) : _muted;
    final maxMobileFeatures = 5;
    final shownFeatures = isMobile && features.length > maxMobileFeatures
        ? features.take(maxMobileFeatures).toList()
        : features;

    final featureList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...shownFeatures.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: isPopular ? Colors.white : _success,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      f,
                      maxLines: isMobile ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: isPopular ? Colors.white.withValues(alpha: 0.88) : _text,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        if (isMobile && features.length > maxMobileFeatures)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '+ ${features.length - maxMobileFeatures} more features',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isPopular ? Colors.white.withValues(alpha: 0.78) : _primary,
              ),
            ),
          ),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isPopular ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 20 : 22),
        // Uniform border (Flutter requires uniform colours with a radius),
        // tinted with the category colour so cards are easy to tell apart.
        border: isPopular
            ? null
            : Border.all(color: categoryColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? _primary.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.045),
            blurRadius: isPopular ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 18 : 22),
        child: Column(
          mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isPopular ? Colors.white : categoryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPopular ? Colors.white.withValues(alpha: 0.15) : _primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tierLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: isPopular ? Colors.white : _primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPopular
                          ? Colors.white
                          : categoryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcon(category),
                          size: 12,
                          color: categoryColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            category.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit Package',
                  onPressed: openEdit,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: isPopular ? Colors.white : _muted,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pkg['title'] as String? ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 20 : 22,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: contentColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pkg['subtitle'] as String? ?? 'Custom digital service package',
              maxLines: isMobile ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    pkg['price'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isMobile ? 26 : 28,
                      fontWeight: FontWeight.w900,
                      color: contentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    pkg['period'] as String? ?? '/Month',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: mutedColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: isPopular ? Colors.white.withValues(alpha: 0.16) : _softBorder,
            ),
            const SizedBox(height: 14),
            Text(
              'WHAT’S INCLUDED',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w900,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 11),
            if (isMobile)
              featureList
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: featureList,
                ),
              ),
            SizedBox(height: isMobile ? 16 : 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: openEdit,
                icon: Icon(
                  Icons.edit_rounded,
                  size: 17,
                  color: isPopular ? _primary : Colors.white,
                ),
                label: Text(
                  'Manage Package',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isPopular ? _primary : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: isPopular ? Colors.white : _primary,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
            if (isPopular) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD166),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 13, color: Color(0xFF6B4500)),
                      SizedBox(width: 4),
                      Text(
                        'POPULAR',
                        style: TextStyle(
                          color: Color(0xFF6B4500),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
