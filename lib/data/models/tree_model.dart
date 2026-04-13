

enum TreeHealthStatus {
  healthy,
  atRisk,
  sick,
  needsAttention,
}

class HealthRecord {
  final DateTime date;
  final TreeHealthStatus status;
  final String note;
  final String recordedBy;

  HealthRecord({
    required this.date,
    required this.status,
    required this.note,
    required this.recordedBy,
  });
}

class MaintenanceRecord {
  final DateTime date;
  final String type; // e.g., Pruning, Fertilizing, Watering
  final String description;
  final String technician;

  MaintenanceRecord({
    required this.date,
    required this.type,
    required this.description,
    required this.technician,
  });
}

class Tree {
  final String id;
  final String name;
  final String species;
  final String plotNumber;
  final String rfidTag;
  final DateTime plantingDate;
  final TreeHealthStatus currentStatus;
  final DateTime lastInspectionDate;
  final List<HealthRecord> healthHistory;
  final List<MaintenanceRecord> maintenanceRecords;
  final List<String> photoUrls;
  final double latitude;
  final double longitude;
  final String notes;

  Tree({
    required this.id,
    required this.name,
    required this.species,
    required this.plotNumber,
    required this.rfidTag,
    required this.plantingDate,
    required this.currentStatus,
    required this.lastInspectionDate,
    this.healthHistory = const [],
    this.maintenanceRecords = const [],
    this.photoUrls = const [],
    required this.latitude,
    required this.longitude,
    this.notes = "",
  });

  int get ageInYears {
    return DateTime.now().year - plantingDate.year;
  }
}

// Mock Data
final List<Tree> mockTrees = [
  Tree(
    id: "T001",
    name: "Mango Alpha",
    species: "Mangifera indica",
    plotNumber: "Plot A1",
    rfidTag: "RFID-12345",
    plantingDate: DateTime(2020, 5, 20),
    currentStatus: TreeHealthStatus.healthy,
    lastInspectionDate: DateTime(2025, 3, 15),
    latitude: 12.9716,
    longitude: 77.5946,
    notes: "Main tree in the northern sector.",
    healthHistory: [
      HealthRecord(
        date: DateTime(2025, 3, 15),
        status: TreeHealthStatus.healthy,
        note: "Initial check - Looks good.",
        recordedBy: "John Doe",
      ),
    ],
    maintenanceRecords: [
      MaintenanceRecord(
        date: DateTime(2025, 2, 10),
        type: "Fertilizing",
        description: "Applied organic fertilizer.",
        technician: "Alice Smith",
      ),
    ],
  ),
  Tree(
    id: "T002",
    name: "Coconut Beta",
    species: "Cocos nucifera",
    plotNumber: "Plot B2",
    rfidTag: "RFID-67890",
    plantingDate: DateTime(2018, 10, 10),
    currentStatus: TreeHealthStatus.atRisk,
    lastInspectionDate: DateTime(2025, 3, 20),
    latitude: 12.9720,
    longitude: 77.5950,
    notes: "Signs of yellowing leaves.",
    healthHistory: [
      HealthRecord(
        date: DateTime(2025, 3, 20),
        status: TreeHealthStatus.atRisk,
        note: "Yellowing leaves observed.",
        recordedBy: "John Doe",
      ),
    ],
  ),
  Tree(
    id: "T003",
    name: "Apple Gamma",
    species: "Malus domestica",
    plotNumber: "Plot C3",
    rfidTag: "RFID-11223",
    plantingDate: DateTime(2022, 2, 14),
    currentStatus: TreeHealthStatus.needsAttention,
    lastInspectionDate: DateTime(2025, 3, 25),
    latitude: 12.9710,
    longitude: 77.5940,
    notes: "Requires pruning.",
  ),
];
