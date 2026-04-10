import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kaushalyanxt_rfid/features/farmer/tree_details/tree_controller.dart';

class MyTreesScreen extends ConsumerStatefulWidget {
  const MyTreesScreen({super.key});

  @override
  ConsumerState<MyTreesScreen> createState() => _MyTreesScreenState();
}

class _MyTreesScreenState extends ConsumerState<MyTreesScreen> {
  String search = "";
  String selectedFilter = "All";

  String selectedAge = '';
  String selectedMonth = '';
  String selectedScan = '';

  final TextEditingController _searchController = TextEditingController();
  String _routeTreeId = '';
  bool _autoOpenedFromRoute = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final uri = GoRouterState.of(context).uri;
    final filter = uri.queryParameters['filter'];
    final treeId = (uri.queryParameters['treeId'] ?? '').trim();

    if (filter != null) {
      if (filter == "healthy") {
        selectedFilter = "Healthy";
      } else if (filter == "attention") {
        selectedFilter = "NeedsAttention";
      } else {
        selectedFilter = "All";
      }
    }

    if (treeId.isNotEmpty && treeId != _routeTreeId) {
      _routeTreeId = treeId;
      _autoOpenedFromRoute = false;
      search = treeId.toLowerCase();
      _searchController.text = treeId;
      _searchController.selection =
          TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final treesAsync = ref.watch(treesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: const Text("My Trees"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _openFilterSheet(context),
          ),
        ],
      ),

      body: Column(
        children: [

          /// SEARCH + CHIPS
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
              ],
            ),
            child: Column(
              children: [

                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search by Tree ID, Location...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => search = val.toLowerCase());
                  },
                ),

                const SizedBox(height: 12),

                treesAsync.when(
                  data: (snapshot) {

                    final all = snapshot.docs.length;

                    final healthy = snapshot.docs.where((d) =>
                        _statusLabel((d.data() as Map)['healthStatus']) == "Healthy").length;

                    final need = snapshot.docs.where((d) =>
                        _statusLabel((d.data() as Map)['healthStatus']) == "NeedsAttention").length;

                    final risk = snapshot.docs.where((d) =>
                        _statusLabel((d.data() as Map)['healthStatus']) == "AtRisk").length;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _chip("All", "All ($all)", Colors.green),
                        _chip("Healthy", "Healthy ($healthy)", Colors.green),
                        _chip("NeedsAttention", "Need Attention ($need)", Colors.orange),
                        _chip("AtRisk", "At Risk ($risk)", Colors.red),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),

          /// TREE LIST
          Expanded(
            child: treesAsync.when(
              data: (snapshot) {

                final docs = snapshot.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final id = (data['treeId'] ?? "").toString().toLowerCase();
                  final loc = (data['location'] ?? "").toString().toLowerCase();
                  final health = _statusLabel(data['healthStatus']);

                  final matchSearch =
                      id.contains(search) || loc.contains(search);

                  final matchFilter =
                      selectedFilter == "All" || health == selectedFilter;

                  /// AGE FILTER
                  bool matchAge = true;
                  if (selectedAge.isNotEmpty) {
                    final age = (data['treeAge'] ?? 0);

                    switch (selectedAge) {
                      case "0-1":
                        matchAge = age >= 0 && age <= 1;
                        break;
                      case "1-5":
                        matchAge = age > 1 && age <= 5;
                        break;
                      case "5-10":
                        matchAge = age > 5 && age <= 10;
                        break;
                      case "10-20":
                        matchAge = age > 10 && age <= 20;
                        break;
                      case "20+":
                        matchAge = age > 20;
                        break;
                    }
                  }

                  /// MONTH
                  bool matchMonth = true;
                  if (selectedMonth.isNotEmpty) {
                    matchMonth = (data['harvestMonth'] ?? "") == selectedMonth;
                  }

                  /// SCAN
                  bool matchScan = true;
                  if (selectedScan.isNotEmpty && selectedScan != "All") {
                    final isScanned = data['isScanned'] ?? false;

                    matchScan = selectedScan == "Scanned"
                        ? isScanned == true
                        : isScanned == false;
                  }

                  return matchSearch &&
                      matchFilter &&
                      matchAge &&
                      matchMonth &&
                      matchScan;

                }).toList();

                // If navigated here with ?treeId=..., auto-open that tree once found.
                if (_routeTreeId.isNotEmpty && !_autoOpenedFromRoute) {
                  final wanted = _routeTreeId.toLowerCase();
                  QueryDocumentSnapshot? matchDoc;
                  for (final d in snapshot.docs) {
                    final data = d.data() as Map<String, dynamic>;
                    final id = (data['treeId'] ?? "").toString().toLowerCase();
                    if (id == wanted) {
                      matchDoc = d;
                      break;
                    }
                  }
                  if (matchDoc != null) {
                    _autoOpenedFromRoute = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      context.pushNamed(
                        'treeDetails',
                        extra: matchDoc!.id,
                        queryParameters: const {'source': 'rfid'},
                      );
                    });
                  }
                }

                if (docs.isEmpty) {
                  return const Center(child: Text("No Trees Found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {

                    final data = docs[i].data() as Map<String, dynamic>;

                    final id = data['treeId'] ?? '';
                    final loc = data['location'] ?? '';
                    final species = data['species'] ?? '';
                    final health = _statusLabel(data['healthStatus']);
                    final date = _formatDate(data['lastinspectiondate']);

                    return GestureDetector(
                      onTap: () {
                        context.pushNamed(
                          'treeDetails',
                          extra: docs[i].id,
                          queryParameters: const {'source': 'myTrees'},
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.park, color: _healthColor(health)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text("ID: $id | $species"),
                                  Text("Plot: $loc"),
                                  Text("Last Inspection: $date"),
                                ],
                              ),
                            ),
                            Text(health,
                                style: TextStyle(color: _healthColor(health)))
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text("Error")),
            ),
          )
        ],
      ),
    );
  }

  Widget _chip(String val, String label, Color color) {
    final active = selectedFilter == val;

    return GestureDetector(
      onTap: () => setState(() => selectedFilter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(label,
            style: TextStyle(color: active ? Colors.white : color)),
      ),
    );
  }

  void _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FilterBottomSheet(
        age: selectedAge,
        month: selectedMonth,
        scan: selectedScan,
      ),
    );

    if (result != null) {
      setState(() {
        selectedAge = result["age"];
        selectedMonth = result["month"];
        selectedScan = result["scan"];
      });
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case "0":
        return "Healthy";
      case "1":
        return "NeedsAttention";
      case "2":
        return "AtRisk";
      default:
        return "Healthy";
    }
  }

  Color _healthColor(String s) {
    switch (s) {
      case "Healthy":
        return Colors.green;
      case "AtRisk":
        return Colors.orange;
      case "NeedsAttention":
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      }
    } catch (_) {}
    return "-";
  }
}

/// 🔥 FILTER SHEET WITH LABELS
class FilterBottomSheet extends StatefulWidget {
  final String age, month, scan;

  const FilterBottomSheet({
    super.key,
    required this.age,
    required this.month,
    required this.scan,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String age;
  late String month;
  late String scan;

  final ageOptions = ["0-1", "1-5", "5-10", "10-20", "20+"];
  final months = [
    "Jan","Feb","Mar","Apr","May","Jun",
    "Jul","Aug","Sep","Oct","Nov","Dec"
  ];
  final scanOptions = ["All", "Scanned", "Not Scanned"];

  @override
  void initState() {
    super.initState();
    age = widget.age;
    month = widget.month;
    scan = widget.scan;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text("Filters",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

          const SizedBox(height: 20),

          const Text("Tree Age", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            children: ageOptions.map((e) {
              return ChoiceChip(
                label: Text(e),
                selected: age == e,
                onSelected: (_) => setState(() => age = e),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          const Text("Harvest Month", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            value: month.isEmpty ? null : month,
            hint: const Text("Select Month"),
            isExpanded: true,
            items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (val) => setState(() => month = val!),
          ),

          const SizedBox(height: 20),

          const Text("Scan Status", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            children: scanOptions.map((s) {
              return ChoiceChip(
                label: Text(s),
                selected: scan == s,
                onSelected: (_) => setState(() => scan = s),
              );
            }).toList(),
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      age = '';
                      month = '';
                      scan = '';
                    });
                  },
                  child: const Text("Reset"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      "age": age,
                      "month": month,
                      "scan": scan,
                    });
                  },
                  child: const Text("Apply"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}