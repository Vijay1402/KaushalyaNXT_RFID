import 'package:flutter/material.dart';
import '../../../data/models/tree_model.dart';

class TreeSearchFilterWidget extends StatefulWidget {
  final Function(String query, TreeHealthStatus? status, String? species, String? plot) onFilterChanged;

  const TreeSearchFilterWidget({super.key, required this.onFilterChanged});

  @override
  State<TreeSearchFilterWidget> createState() => _TreeSearchFilterWidgetState();
}

class _TreeSearchFilterWidgetState extends State<TreeSearchFilterWidget> {
  final TextEditingController _searchController = TextEditingController();
  TreeHealthStatus? _selectedStatus;
  String? _selectedSpecies;
  String? _selectedPlot;

  // Derive unique species and plots from mock data for filters
  late List<String> _speciesList;
  late List<String> _plotList;

  @override
  void initState() {
    super.initState();
    _speciesList = mockTrees.map((t) => t.species).toSet().toList();
    _plotList = mockTrees.map((t) => t.plotNumber).toSet().toList();
  }

  void _notifyChanges() {
    widget.onFilterChanged(
      _searchController.text,
      _selectedStatus,
      _selectedSpecies,
      _selectedPlot,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by ID, Name, or RFID",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear();
                      _notifyChanges();
                    }) 
                  : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => _notifyChanges(),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text("Filter Options", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.filter_list),
              children: [
                _buildStatusFilter(),
                _buildDropdownFilter("Species", _speciesList, _selectedSpecies, (val) {
                  setState(() => _selectedSpecies = val);
                  _notifyChanges();
                }),
                _buildDropdownFilter("Plot/Location", _plotList, _selectedPlot, (val) {
                  setState(() => _selectedPlot = val);
                  _notifyChanges();
                }),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedStatus = null;
                      _selectedSpecies = null;
                      _selectedPlot = null;
                    });
                    _notifyChanges();
                  },
                  child: const Text("Reset Filters"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Health Status", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip("All", null),
                const SizedBox(width: 8),
                _buildStatusChip("Healthy", TreeHealthStatus.healthy),
                const SizedBox(width: 8),
                _buildStatusChip("At-Risk", TreeHealthStatus.atRisk),
                const SizedBox(width: 8),
                _buildStatusChip("Needs Attention", TreeHealthStatus.needsAttention),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, TreeHealthStatus? status) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
        _notifyChanges();
      },
      selectedColor: Colors.green.shade100,
      labelStyle: TextStyle(fontSize: 12, color: isSelected ? Colors.green.shade900 : Colors.black),
    );
  }

  Widget _buildDropdownFilter(String label, List<String> items, String? currentValue, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: currentValue,
              hint: Text("Select $label"),
              items: items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
