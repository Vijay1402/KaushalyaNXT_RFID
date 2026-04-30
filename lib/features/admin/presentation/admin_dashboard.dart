import 'package:flutter/material.dart';

import '../../farm_manager/presentation/screens/analytics_screen.dart';
import '../../farm_manager/presentation/screens/issue_tracker_screen.dart';
import '../../farm_manager/presentation/screens/managed_tree_list_screen.dart';
import '../../farmer/reports/reports_screen.dart';
import 'admin_user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _screens = const [
    AdminUserManagementScreen(),
    ManagedTreeListScreen(),
    IssueTrackerScreen(),
    AnalyticsScreen(showBottomNavigation: false),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF2E8933),
        unselectedItemColor: Colors.grey.shade600,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.park_outlined),
            label: 'My Trees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Issues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            label: 'Report',
          ),
        ],
      ),
    );
  }
}
