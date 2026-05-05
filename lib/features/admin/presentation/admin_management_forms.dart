import 'package:flutter/material.dart';

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
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: initialData?.name ?? '');
  final locationController =
      TextEditingController(text: initialData?.location ?? '');
  final areaController = TextEditingController(
    text: initialData == null || initialData.areaAcres <= 0
        ? ''
        : initialData.areaAcres.toString(),
  );
  final farmerNameController =
      TextEditingController(text: initialData?.farmerName ?? '');
  final farmerPhoneController =
      TextEditingController(text: initialData?.farmerPhone ?? '');
  final farmerEmailController =
      TextEditingController(text: initialData?.farmerEmail ?? '');
  final farmerIdController =
      TextEditingController(text: initialData?.farmerId ?? '');
  final managerIdController =
      TextEditingController(text: initialData?.managerId ?? '');
  final latitudeController = TextEditingController(
    text: initialData?.latitude?.toString() ?? '',
  );
  final longitudeController = TextEditingController(
    text: initialData?.longitude?.toString() ?? '',
  );

  final result = await showDialog<AdminFarmFormData>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(initialData == null ? 'Add Farm' : 'Edit Farm'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AdminFormField(
                    controller: nameController,
                    label: 'Farm Name',
                    validator: _requiredValidator('Farm name'),
                  ),
                  const SizedBox(height: 12),
                  _AdminFormField(
                    controller: locationController,
                    label: 'Location',
                    validator: _requiredValidator('Location'),
                  ),
                  const SizedBox(height: 12),
                  _AdminFormField(
                    controller: areaController,
                    label: 'Area (Acres)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AdminFormField(
                    controller: farmerNameController,
                    label: 'Farmer Name',
                  ),
                  const SizedBox(height: 12),
                  _AdminFormField(
                    controller: farmerPhoneController,
                    label: 'Farmer Phone',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _AdminFormField(
                    controller: farmerEmailController,
                    label: 'Farmer Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _AdminFormField(
                    controller: farmerIdController,
                    label: 'Farmer User ID',
                  ),
                  const SizedBox(height: 12),
                  _AdminFormField(
                    controller: managerIdController,
                    label: 'Manager User ID',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AdminFormField(
                          controller: latitudeController,
                          label: 'Latitude',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AdminFormField(
                          controller: longitudeController,
                          label: 'Longitude',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
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
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }

              Navigator.pop(
                context,
                AdminFarmFormData(
                  name: nameController.text.trim(),
                  location: locationController.text.trim(),
                  areaAcres: _parseDouble(areaController.text.trim()),
                  farmerName: farmerNameController.text.trim(),
                  farmerPhone: farmerPhoneController.text.trim(),
                  farmerEmail: farmerEmailController.text.trim(),
                  farmerId: farmerIdController.text.trim(),
                  managerId: managerIdController.text.trim(),
                  latitude: _parseNullableDouble(
                    latitudeController.text.trim(),
                  ),
                  longitude: _parseNullableDouble(
                    longitudeController.text.trim(),
                  ),
                ),
              );
            },
            child: Text(initialData == null ? 'Add' : 'Save'),
          ),
        ],
      );
    },
  );

  nameController.dispose();
  locationController.dispose();
  areaController.dispose();
  farmerNameController.dispose();
  farmerPhoneController.dispose();
  farmerEmailController.dispose();
  farmerIdController.dispose();
  managerIdController.dispose();
  latitudeController.dispose();
  longitudeController.dispose();

  return result;
}

Future<AdminTreeFormData?> showAdminTreeFormDialog(
  BuildContext context, {
  required String farmName,
  required String defaultFarmerName,
  AdminTreeFormData? initialData,
}) async {
  final formKey = GlobalKey<FormState>();
  final treeIdController =
      TextEditingController(text: initialData?.treeId ?? '');
  final speciesController =
      TextEditingController(text: initialData?.species ?? '');
  final locationController =
      TextEditingController(text: initialData?.location ?? '');
  final farmerNameController = TextEditingController(
    text: initialData?.farmerName ?? defaultFarmerName,
  );
  final ageController = TextEditingController(
    text: initialData == null || initialData.ageYears <= 0
        ? ''
        : initialData.ageYears.toString(),
  );
  final yieldController = TextEditingController(
    text: initialData == null || initialData.lastYieldKg <= 0
        ? ''
        : initialData.lastYieldKg.toString(),
  );
  final harvestMonthController =
      TextEditingController(text: initialData?.harvestMonth ?? '');
  final latitudeController = TextEditingController(
    text: initialData?.latitude?.toString() ?? '',
  );
  final longitudeController = TextEditingController(
    text: initialData?.longitude?.toString() ?? '',
  );
  final rfidController = TextEditingController(text: initialData?.rfid ?? '');
  var healthStatus = initialData?.healthStatus ?? '0';
  var isScanned = initialData?.isScanned ?? false;

  final result = await showDialog<AdminTreeFormData>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(initialData == null ? 'Add Tree' : 'Edit Tree'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Farm: $farmName',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AdminFormField(
                        controller: treeIdController,
                        label: 'Tree ID',
                        validator: _requiredValidator('Tree ID'),
                      ),
                      const SizedBox(height: 12),
                      _AdminFormField(
                        controller: speciesController,
                        label: 'Species',
                        validator: _requiredValidator('Species'),
                      ),
                      const SizedBox(height: 12),
                      _AdminFormField(
                        controller: locationController,
                        label: 'Tree Location / Plot',
                      ),
                      const SizedBox(height: 12),
                      _AdminFormField(
                        controller: farmerNameController,
                        label: 'Farmer Name',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: healthStatus,
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
                          setDialogState(() {
                            healthStatus = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _AdminFormField(
                              controller: ageController,
                              label: 'Age (Years)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AdminFormField(
                              controller: yieldController,
                              label: 'Last Yield (Kg)',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AdminFormField(
                        controller: harvestMonthController,
                        label: 'Harvest Month',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _AdminFormField(
                              controller: latitudeController,
                              label: 'Latitude',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AdminFormField(
                              controller: longitudeController,
                              label: 'Longitude',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AdminFormField(
                        controller: rfidController,
                        label: 'RFID',
                      ),
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        value: isScanned,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mark tree as scanned'),
                        onChanged: (value) {
                          setDialogState(() {
                            isScanned = value ?? false;
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
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  Navigator.pop(
                    context,
                    AdminTreeFormData(
                      treeId: treeIdController.text.trim(),
                      species: speciesController.text.trim(),
                      location: locationController.text.trim(),
                      farmerName: farmerNameController.text.trim(),
                      healthStatus: healthStatus,
                      ageYears: _parseInt(ageController.text.trim()),
                      lastYieldKg: _parseDouble(yieldController.text.trim()),
                      harvestMonth: harvestMonthController.text.trim(),
                      latitude: _parseNullableDouble(
                        latitudeController.text.trim(),
                      ),
                      longitude: _parseNullableDouble(
                        longitudeController.text.trim(),
                      ),
                      rfid: rfidController.text.trim(),
                      isScanned: isScanned,
                    ),
                  );
                },
                child: Text(initialData == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      );
    },
  );

  treeIdController.dispose();
  speciesController.dispose();
  locationController.dispose();
  farmerNameController.dispose();
  ageController.dispose();
  yieldController.dispose();
  harvestMonthController.dispose();
  latitudeController.dispose();
  longitudeController.dispose();
  rfidController.dispose();

  return result;
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
