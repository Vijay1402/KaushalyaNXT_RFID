import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../compare/models/compare_model.dart' as compare;
import '../compare/presentation/select_trees_screen.dart';
import '../farm_manager_data.dart';

class ManagedTreeListScreen extends StatefulWidget {
  const ManagedTreeListScreen({super.key});

  @override
  State<ManagedTreeListScreen> createState() => _ManagedTreeListScreenState();
}

class _ManagedTreeListScreenState extends State<ManagedTreeListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTrees = <String>{};
  List<Map<String, dynamic>> _currentScopedTrees =
      const <Map<String, dynamic>>[];
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openTreeDetails(Map<String, dynamic> tree) {
    final treeDocId = (tree['_docId'] ?? '').toString().trim();
    if (treeDocId.isEmpty) {
      _showMessage('This tree record is missing a document id.');
      return;
    }

    context.pushNamed(
      'treeDetails',
      extra: treeDocId,
      queryParameters: const {'source': 'myTrees'},
    );
  }

  String _treeKey(Map<String, dynamic> tree) {
    final docId = (tree['_docId'] ?? '').toString().trim();
    if (docId.isNotEmpty) {
      return docId;
    }
    return _treeLabel(tree);
  }

  String _treeLabel(Map<String, dynamic> tree) {
    return firstNonEmptyString(
      [
        tree['treeId'],
        tree['_docId'],
      ],
      fallback: 'Unknown',
    );
  }

  void _toggleSelected(Map<String, dynamic> tree) {
    final key = _treeKey(tree);
    setState(() {
      if (_selectedTrees.contains(key)) {
        _selectedTrees.remove(key);
      } else {
        _selectedTrees.add(key);
      }
    });
  }

  compare.Tree _toCompareTree(Map<String, dynamic> tree) {
    final yieldValue = firstNonEmptyString(
      [
        tree['lastYieldKg'],
        tree['yieldKg'],
        tree['yield'],
      ],
      fallback: 'Unknown',
    );

    return compare.Tree(
      id: _treeKey(tree),
      name: _treeLabel(tree),
      yield: yieldValue == 'Unknown' ? yieldValue : '$yieldValue kg',
      health: healthLabel(tree['healthStatus']),
      sync: tree['isScanned'] == true ? 'Scanned' : 'Not Scanned',
    );
  }

  void _openCompareFlow() {
    if (_currentScopedTrees.length < 2) {
      _showMessage('At least two trees are needed to compare.');
      return;
    }

    final compareTrees =
        _currentScopedTrees.map(_toCompareTree).toList(growable: false);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SelectTreesScreen(
          trees: compareTrees,
          initiallySelectedTreeIds: _selectedTrees,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FarmManagerScope>(
      future: loadFarmManagerScope(),
      builder: (context, scopeSnapshot) {
        if (scopeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final scope = scopeSnapshot.data ??
            const FarmManagerScope(
              managerUid: '',
              managerEmail: '',
              managerCode: '',
              linkedFarmerIds: <String>{},
              linkedFarmerEmails: <String>{},
            );

        return Scaffold(
          backgroundColor: Colors.grey[200],
          appBar: AppBar(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            title: const Text('All Trees View'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _search = value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: const Icon(Icons.mic),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showMessage('Advanced filters can be added next.');
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text('Advanced Filters'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openCompareFlow,
                        icon: const Icon(Icons.compare_arrows),
                        label: Text(
                          'Compare${_selectedTrees.isNotEmpty ? ' (${_selectedTrees.length})' : ''}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedTrees.isEmpty
                            ? 'Tap Compare to choose trees, or long-press a tree to preselect it here.'
                            : 'Long-press or tap selected cards to adjust your compare list.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_selectedTrees.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedTrees.clear();
                          });
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore.collection('trees').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      _currentScopedTrees = const <Map<String, dynamic>>[];
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      _currentScopedTrees = const <Map<String, dynamic>>[];
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final treeDocs = snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final scopedTrees = buildScopedTrees(treeDocs, scope);
                    _currentScopedTrees = scopedTrees;
                    final visibleTrees = scopedTrees.where((tree) {
                      if (_search.isEmpty) {
                        return true;
                      }

                      final values = <String>[
                        _treeLabel(tree),
                        firstNonEmptyString([tree['location']]),
                        firstNonEmptyString([tree['species']]),
                        farmNameFromTree(tree),
                        farmerNameFromTree(tree),
                      ];

                      return values.any(
                        (value) => value.toLowerCase().contains(_search),
                      );
                    }).toList(growable: false);

                    if (visibleTrees.isEmpty) {
                      final message = scopedTrees.isEmpty
                          ? 'No trees found'
                          : 'No trees match the current search';
                      return Center(child: Text(message));
                    }

                    return ListView.builder(
                      itemCount: visibleTrees.length,
                      itemBuilder: (context, index) {
                        final tree = visibleTrees[index];
                        final key = _treeKey(tree);
                        final health = healthLabel(tree['healthStatus']);
                        final isHealthy = health == 'Healthy';

                        return GestureDetector(
                          onTap: () {
                            if (_selectedTrees.isNotEmpty) {
                              _toggleSelected(tree);
                              return;
                            }
                            _openTreeDetails(tree);
                          },
                          onLongPress: () => _toggleSelected(tree),
                          child: TreeCard(
                            id: _treeLabel(tree),
                            age: firstNonEmptyString(
                              [
                                tree['treeAge'],
                                tree['age'],
                              ],
                              fallback: 'Unknown',
                            ),
                            address: firstNonEmptyString(
                              [
                                tree['location'],
                                tree['plotNumber'],
                                tree['plot'],
                              ],
                              fallback: 'Farm Address',
                            ),
                            yieldValue: firstNonEmptyString(
                              [
                                tree['lastYieldKg'],
                                tree['yieldKg'],
                                tree['yield'],
                              ],
                              fallback: 'Unknown',
                            ),
                            status: tree['isScanned'] == true
                                ? 'Scanned'
                                : 'Not Scanned',
                            health: health,
                            isHealthy: isHealthy,
                            isSelected: _selectedTrees.contains(key),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _showMessage('Block action can be connected next.');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text('Block Action'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _showMessage('Export PDF can be connected next.');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text('Export PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _showMessage('Export Excel can be connected next.');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text('Export Excel'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TreeCard extends StatelessWidget {
  const TreeCard({
    super.key,
    required this.id,
    required this.age,
    required this.address,
    required this.yieldValue,
    required this.status,
    required this.health,
    required this.isHealthy,
    this.isSelected = false,
  });

  final String id;
  final String age;
  final String address;
  final String yieldValue;
  final String status;
  final String health;
  final bool isHealthy;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: isSelected ? Colors.blue[50] : Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.park, size: 50, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tree #$id',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Tree Age: $age'),
                  const SizedBox(height: 2),
                  Text(address),
                  const SizedBox(height: 2),
                  Text('Yield: $yieldValue'),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.blue),
                StatusBadge(
                  text: status,
                  color: isHealthy ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 8),
                StatusBadge(
                  text: health,
                  color: isHealthy ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
