import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MyTreesScreen extends StatefulWidget {
  const MyTreesScreen({super.key});

  @override
  State<MyTreesScreen> createState() => _MyTreesScreenState();
}

class _MyTreesScreenState extends State<MyTreesScreen> {
  Map<String, dynamic> filters = {};

  /// 🔥 Selected Chip Filter
  String selectedFilter = "All";

  /// 🌳 TREE DATA
  final List<Map<String, dynamic>> trees = [
    {"id": "JF-001", "status": "Healthy", "color": Colors.green},
    {"id": "JF-002", "status": "Need Attention", "color": Colors.orange},
    {"id": "JF-003", "status": "Write Pending", "color": Colors.amber},
    {"id": "JF-004", "status": "Healthy", "color": Colors.green},
  ];

  @override
  Widget build(BuildContext context) {
    /// 🔍 FILTER LOGIC
    List<Map<String, dynamic>> filteredTrees = trees.where((tree) {
      if (selectedFilter == "All") return true;
      return tree["status"] == selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[200],

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            context.go('/farmer/home');
          },
        ),

        title: const Text(
          "My Trees (24)",
          style: TextStyle(color: Colors.black),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: () async {
              final result = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const FilterBottomSheet(),
              );

              if (result != null) {
                setState(() {
                  filters = result;
                });
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            /// 🔍 SEARCH
            TextField(
              decoration: InputDecoration(
                hintText: "Search by Tree ID, Species...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: const Icon(Icons.close),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            /// 🔘 FILTER CHIPS
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildChip("All", "All Trees (24)"),
                _buildChip("Healthy", "Healthy (18)"),
                _buildChip("Need Attention", "Need Attention (4)", warning: true),
                _buildChip("Write Pending", "Write Pending (2)", warning: true),
              ],
            ),

            const SizedBox(height: 15),

            /// 📋 TREE LIST
            Expanded(
              child: ListView.builder(
                itemCount: filteredTrees.length,
                itemBuilder: (context, index) {
                  final tree = filteredTrees[index];

                  return _TreeCard(
                    id: tree["id"],
                    status: tree["status"],
                    color: tree["color"],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔘 CHIP BUILDER
  Widget _buildChip(String value, String label, {bool warning = false}) {
    final isActive = selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: warning ? Colors.orange : Colors.green,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

//
// 🔥 FILTER BOTTOM SHEET (UNCHANGED)
//
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String age = '';
  String month = '';
  String scan = '';

  final ageOptions = ["0-1", "1-5", "5-10", "10-20", "20+"];
  final months = [
    "Jan","Feb","Mar","Apr","May","Jun",
    "Jul","Aug","Sep","Oct","Nov","Dec"
  ];
  final scanOptions = ["All", "Scanned", "Not Scanned"];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filters",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          const Text("Tree Age"),
          Wrap(
            spacing: 8,
            children: ageOptions.map((e) {
              return ChoiceChip(
                label: Text(e),
                selected: age == e,
                onSelected: (_) {
                  setState(() => age = e);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          const Text("Harvest Month"),
          DropdownButton<String>(
            value: month.isEmpty ? null : month,
            hint: const Text("Select Month"),
            isExpanded: true,
            items: months.map((m) {
              return DropdownMenuItem(value: m, child: Text(m));
            }).toList(),
            onChanged: (val) {
              setState(() => month = val!);
            },
          ),

          const SizedBox(height: 20),

          const Text("Scan Status"),
          Wrap(
            spacing: 8,
            children: scanOptions.map((s) {
              return ChoiceChip(
                label: Text(s),
                selected: scan == s,
                onSelected: (_) {
                  setState(() => scan = s);
                },
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

//
// 🌳 TREE CARD (UNCHANGED)
//
class _TreeCard extends StatelessWidget {
  final String id;
  final String status;
  final Color color;

  const _TreeCard({
    required this.id,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.park, size: 40),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tree ID: $id",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text("Species: Artocarpus heterophyllus"),
                const Text("Location: Plot A, Row 3"),
              ],
            ),
          ),

          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }
}