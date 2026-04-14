class UserModel {
  final String name;
  final String email;
  final String role;
  final String phone;

  UserModel({
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
  });
}
