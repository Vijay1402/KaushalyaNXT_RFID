class RoutePaths {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const farmerHome = '/farmer/home';
  static const farmManagerHome = '/farm-manager/home';
  static const forgotPassword = '/forgot-password';
  static const activityLog = '/activity-log';

  static String homeForRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    if (normalized == 'farm_manager' || normalized == 'farm manager') {
      return farmManagerHome;
    }
    return farmerHome;
  }
}
