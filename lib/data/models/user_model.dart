class UserModel {
  final String name;
  final String email;
  final String role;
  final String phone;
  final String managerCode;
  final String farmManagerId;
  final String farmManagerName;
  final String farmManagerCode;

  UserModel({
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.managerCode = '',
    this.farmManagerId = '',
    this.farmManagerName = '',
    this.farmManagerCode = '',
  });
}
