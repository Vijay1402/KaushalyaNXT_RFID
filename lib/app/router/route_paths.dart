class RoutePaths {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const farmerHome = '/farmer/home';
  static const farmManagerHome = '/farm-manager/home';
  static const farmManagerFarms = '/farm-manager/farms';
  static const farmManagerTrees = '/farm-manager/trees';
  static const farmManagerFarmDetails = '/farm-manager/farm-details';
  static const farmManagerIssues = '/farm-manager/issues';
  static const farmManagerFarmers = '/farm-manager/farmers';
  static const farmManagerAnalytics = '/farm-manager/analytics';
  static const adminHome = '/admin/home';
  static const kvkHome = '/kvk/home';
  static const agricultureOfficerHome = '/agriculture-officer/home';
  static const forgotPassword = '/forgot-password';
  static const activityLog = '/activity-log';

  static String homeForRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    if (normalized == 'admin') {
      return adminHome;
    }
    if (normalized == 'kvk') {
      return kvkHome;
    }
    if (normalized == 'agriculture_officer' ||
        normalized == 'agriculture officer' ||
        normalized == 'aggriculture_officer' ||
        normalized == 'aggriculture officer') {
      return agricultureOfficerHome;
    }
    if (normalized == 'farm_manager' || normalized == 'farm manager') {
      return farmManagerHome;
    }
    return farmerHome;
  }
}
