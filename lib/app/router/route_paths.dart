class RoutePaths {
  /// AUTH
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  /// DASHBOARDS
  static const farmerHome = '/farmer/home';
  static const farmManagerHome = '/farm-manager/home';

  /// FEATURES
  static const activityLog = '/activity-log';
  static const myTrees = '/my-trees';
  static const profile = '/profile';
  static const report = '/report';
  static const scan = '/scan';

  /// ✅ IMPORTANT (ADD THIS)
  static const farms = '/farms';

  /// ✅ TREE DETAILS
  static const treeDetails = '/tree-details';

  /// ROLE BASED NAVIGATION
  static String homeForRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();

    if (normalized == 'farm_manager' || normalized == 'farm manager') {
      return farmManagerHome;
    }

    return farmerHome;
  }
}
