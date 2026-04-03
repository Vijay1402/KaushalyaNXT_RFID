import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool generalNotifications = true;
  bool treeAlerts = true;
  bool appUpdates = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      /// 🔥 APP BAR
      appBar: AppBar(
        title: const Text("Notification Settings"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      /// BODY
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            _buildSwitchTile(
              title: "General Notifications",
              value: generalNotifications,
              onChanged: (val) {
                setState(() {
                  generalNotifications = val;
                });
              },
            ),

            const SizedBox(height: 20),

            _buildSwitchTile(
              title: "Tree Alerts",
              value: treeAlerts,
              onChanged: (val) {
                setState(() {
                  treeAlerts = val;
                });
              },
            ),

            const SizedBox(height: 20),

            _buildSwitchTile(
              title: "App Updates",
              value: appUpdates,
              onChanged: (val) {
                setState(() {
                  appUpdates = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 🔧 CUSTOM SWITCH TILE (MATCHES DESIGN)
  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),

        /// SWITCH
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.deepPurple,
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.grey.shade400,
        ),
      ],
    );
  }
}