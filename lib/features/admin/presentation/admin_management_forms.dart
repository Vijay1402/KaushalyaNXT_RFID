import 'package:flutter/material.dart';

import '../../../shared/widgets/responsive_layout.dart';
import '../../farm_manager/presentation/farm_manager_data.dart';

class AdminFarmFormData {
  const AdminFarmFormData({
    required this.name,
    required this.location,
    required this.areaAcres,
    required this.farmerName,
    required this.farmerPhone,
    required this.farmerEmail,
    required this.farmerId,
    required this.managerId,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String location;
  final double areaAcres;
  final String farmerName;
  final String farmerPhone;
  final String farmerEmail;
  final String farmerId;
  final String managerId;
  final double? latitude;
  final double? longitude;

  factory AdminFarmFormData.fromFarm(FarmManagerFarm farm) {
    return AdminFarmFormData(
      name: farm.name,
      location: farm.location,
      areaAcres: farm.areaAcres,
      farmerName: farm.farmerName,
      farmerPhone: farm.farmerPhone,
      farmerEmail: farm.farmerEmail,
      farmerId: farm.farmerId,
      managerId: '',
      latitude: farm.latitude,
      longitude: farm.longitude,
    );
  }
}

class AdminTreeFormData {
  const AdminTreeFormData({
    required this.treeId,
    required this.species,
    required this.location,
    required this.farmerName,
    required this.healthStatus,
    required this.ageYears,
    required this.lastYieldKg,
    required this.harvestMonth,
    required this.latitude,
    required this.longitude,
    required this.rfid,
    required this.isScanned,
  });

  final String treeId;
  final String species;
  final String location;
  final String farmerName;
  final String healthStatus;
  final int ageYears;
  final double lastYieldKg;
  final String harvestMonth;
  final double? latitude;
  final double? longitude;
  final String rfid;
  final bool isScanned;

  factory AdminTreeFormData.fromTree(Map<String, dynamic> tree) {
    return AdminTreeFormData(
      treeId: (tree['treeId'] ?? '').toString().trim(),
      species: (tree['species'] ?? '').toString().trim(),
      location: firstNonEmptyString(
        [
          tree['location'],
          tree['plotNumber'],
          tree['plot'],
        ],
      ),
      farmerName: firstNonEmptyString(
        [
          tree['ownerName'],
          tree['farmerName'],
          tree['userName'],
        ],
      ),
      healthStatus: _treeHealthCodeFromRaw(tree['healthStatus']),
      ageYears: asInt(tree['treeAge'] ?? tree['age']),
      lastYieldKg: asDouble(tree['lastYieldKg'] ?? tree['yieldKg']),
      harvestMonth: (tree['harvestMonth'] ?? '').toString().trim(),
      latitude: asNullableDouble(tree['latitude']),
      longitude: asNullableDouble(tree['longitude']),
      rfid: (tree['rfid'] ?? '').toString().trim(),
      isScanned: tree['isScanned'] == true,
    );
  }
}

Future<AdminFarmFormData?> showAdminFarmFormDialog(
  BuildContext context, {
  AdminFarmFormData? initialData,
}) async {
  return showDialog<AdminFarmFormData>(
    context: context,
    builder: (context) => _AdminFarmFormDialog(initialData: initialData),
  );
}

Future<AdminTreeFormData?> showAdminTreeFormDialog(
  BuildContext context, {
  required String farmName,
  required String defaultFarmerName,
  AdminTreeFormData? initialData,
}) async {
  return showDialog<AdminTreeFormData>(
    context: context,
    builder: (context) => _AdminTreeFormDialog(
      farmName: farmName,
      defaultFarmerName: defaultFarmerName,
      initialData: initialData,
    ),
  );
}

class _AdminFarmFormDialog extends StatefulWidget {
  const _AdminFarmFormDialog({
    this.initialData,
  });

  final AdminFarmFormData? initialData;

  @override
  State<_AdminFarmFormDialog> createState() => _AdminFarmFormDialogState();
}

class _AdminFarmFormDialogState extends State<_AdminFarmFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _areaController;
  late final TextEditingController _farmerNameController;
  late final TextEditingController _farmerPhoneController;
  late final TextEditingController _farmerEmailController;
  late final TextEditingController _farmerIdController;
  late final TextEditingController _managerIdController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;
    _nameController = TextEditingController(text: initialData?.name ?? '');
    _locationController =
        TextEditingController(text: initialData?.location ?? '');
    _areaController = TextEditingController(
      text: initialData == null || initialData.areaAcres <= 0
          ? ''
          : initialData.areaAcres.toString(),
    );
    _farmerNameController =
        TextEditingController(text: initialData?.farmerName ?? '');
    _farmerPhoneController =
        TextEditingController(text: initialData?.farmerPhone ?? '');
    _farmerEmailController =
        TextEditingController(text: initialData?.farmerEmail ?? '');
    _farmerIdController =
        TextEditingController(text: initialData?.farmerId ?? '');
    _managerIdController =
        TextEditingController(text: initialData?.managerId ?? '');
    _latitudeController = TextEditingController(
      text: initialData?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: initialData?.longitude?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _farmerNameController.dispose();
    _farmerPhoneController.dispose();
    _farmerEmailController.dispose();
    _farmerIdController.dispose();
    _managerIdController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      AdminFarmFormData(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        areaAcres: _parseDouble(_areaController.text.trim()),
        farmerName: _farmerNameController.text.trim(),
        farmerPhone: _farmerPhoneController.text.trim(),
        farmerEmail: _farmerEmailController.text.trim(),
        farmerId: _farmerIdController.text.trim(),
        managerId: _managerIdController.text.trim(),
        latitude: _parseNullableDouble(_latitudeController.text.trim()),
        longitude: _parseNullableDouble(_longitudeController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialData == null ? 'Add Farm' : 'Edit Farm'),
      content: SizedBox(
        width: ResponsiveLayout.dialogWidth(context),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AdminFormField(
                  controller: _nameController,
                  label: 'Farm Name',
                  validator: _requiredValidator('Farm name'),
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _locationController,
                  label: 'Location',
                  validator: _requiredValidator('Location'),
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _areaController,
                  label: 'Area (Acres)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _farmerNameController,
                  label: 'Farmer Name',
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _farmerPhoneController,
                  label: 'Farmer Phone',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _farmerEmailController,
                  label: 'Farmer Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _farmerIdController,
                  label: 'Farmer User ID',
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _managerIdController,
                  label: 'Manager User ID',
                ),
                const SizedBox(height: 12),
                ResponsiveWrapGrid(
                  minChildWidth: 150,
                  maxColumns: 2,
                  spacing: 10,
                  children: [
                    _AdminFormField(
                      controller: _latitudeController,
                      label: 'Latitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                    _AdminFormField(
                      controller: _longitudeController,
                      label: 'Longitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.initialData == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class _AdminTreeFormDialog extends StatefulWidget {
  const _AdminTreeFormDialog({
    required this.farmName,
    required this.defaultFarmerName,
    this.initialData,
  });

  final String farmName;
  final String defaultFarmerName;
  final AdminTreeFormData? initialData;

  @override
  State<_AdminTreeFormDialog> createState() => _AdminTreeFormDialogState();
}

class _AdminTreeFormDialogState extends State<_AdminTreeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _treeIdController;
  late final TextEditingController _speciesController;
  late final TextEditingController _locationController;
  late final TextEditingController _farmerNameController;
  late final TextEditingController _ageController;
  late final TextEditingController _yieldController;
  late final TextEditingController _harvestMonthController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _rfidController;

  late String _healthStatus;
  late bool _isScanned;

  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;
    _treeIdController = TextEditingController(text: initialData?.treeId ?? '');
    _speciesController =
        TextEditingController(text: initialData?.species ?? '');
    _locationController =
        TextEditingController(text: initialData?.location ?? '');
    _farmerNameController = TextEditingController(
      text: initialData?.farmerName ?? widget.defaultFarmerName,
    );
    _ageController = TextEditingController(
      text: initialData == null || initialData.ageYears <= 0
          ? ''
          : initialData.ageYears.toString(),
    );
    _yieldController = TextEditingController(
      text: initialData == null || initialData.lastYieldKg <= 0
          ? ''
          : initialData.lastYieldKg.toString(),
    );
    _harvestMonthController =
        TextEditingController(text: initialData?.harvestMonth ?? '');
    _latitudeController = TextEditingController(
      text: initialData?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: initialData?.longitude?.toString() ?? '',
    );
    _rfidController = TextEditingController(text: initialData?.rfid ?? '');
    _healthStatus = initialData?.healthStatus ?? '0';
    _isScanned = initialData?.isScanned ?? false;
  }

  @override
  void dispose() {
    _treeIdController.dispose();
    _speciesController.dispose();
    _locationController.dispose();
    _farmerNameController.dispose();
    _ageController.dispose();
    _yieldController.dispose();
    _harvestMonthController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _rfidController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      AdminTreeFormData(
        treeId: _treeIdController.text.trim(),
        species: _speciesController.text.trim().isEmpty
            ? 'Unknown'
            : _speciesController.text.trim(),
        location: _locationController.text.trim(),
        farmerName: _farmerNameController.text.trim(),
        healthStatus: _healthStatus,
        ageYears: _parseInt(_ageController.text.trim()),
        lastYieldKg: _parseDouble(_yieldController.text.trim()),
        harvestMonth: _harvestMonthController.text.trim(),
        latitude: _parseNullableDouble(_latitudeController.text.trim()),
        longitude: _parseNullableDouble(_longitudeController.text.trim()),
        rfid: _rfidController.text.trim(),
        isScanned: _isScanned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialData == null ? 'Add Tree' : 'Edit Tree'),
      content: SizedBox(
        width: ResponsiveLayout.dialogWidth(context),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm: ${widget.farmName}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _treeIdController,
                  label: 'Tree ID',
                  validator: _requiredValidator('Tree ID'),
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _speciesController,
                  label: 'Species',
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _locationController,
                  label: 'Tree Location / Plot',
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _farmerNameController,
                  label: 'Farmer Name',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _healthStatus,
                  decoration: const InputDecoration(
                    labelText: 'Health Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '0',
                      child: Text('Healthy'),
                    ),
                    DropdownMenuItem(
                      value: '1',
                      child: Text('Needs Attention'),
                    ),
                    DropdownMenuItem(
                      value: '2',
                      child: Text('At Risk'),
                    ),
                    DropdownMenuItem(
                      value: '3',
                      child: Text('Critical'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _healthStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ResponsiveWrapGrid(
                  minChildWidth: 150,
                  maxColumns: 2,
                  spacing: 10,
                  children: [
                    _AdminFormField(
                      controller: _ageController,
                      label: 'Age (Years)',
                      keyboardType: TextInputType.number,
                    ),
                    _AdminFormField(
                      controller: _yieldController,
                      label: 'Last Yield (Kg)',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _harvestMonthController,
                  label: 'Harvest Month',
                ),
                const SizedBox(height: 12),
                ResponsiveWrapGrid(
                  minChildWidth: 150,
                  maxColumns: 2,
                  spacing: 10,
                  children: [
                    _AdminFormField(
                      controller: _latitudeController,
                      label: 'Latitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                    _AdminFormField(
                      controller: _longitudeController,
                      label: 'Longitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AdminFormField(
                  controller: _rfidController,
                  label: 'RFID',
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: _isScanned,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark tree as scanned'),
                  onChanged: (value) {
                    setState(() {
                      _isScanned = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.initialData == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class _AdminFormField extends StatelessWidget {
  const _AdminFormField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

String? Function(String?) _requiredValidator(String label) {
  return (value) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
  };
}

double _parseDouble(String value) {
  return double.tryParse(value) ?? 0;
}

double? _parseNullableDouble(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed);
}

int _parseInt(String value) {
  return int.tryParse(value) ?? 0;
}

String _treeHealthCodeFromRaw(dynamic raw) {
  final normalized = (raw ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case 'healthy':
    case '0':
      return '0';
    case 'needsattention':
    case 'needs attention':
    case '1':
      return '1';
    case 'atrisk':
    case 'at risk':
    case '2':
      return '2';
    case 'critical':
    case 'sick':
    case '3':
      return '3';
    default:
      return '0';
  }
}
