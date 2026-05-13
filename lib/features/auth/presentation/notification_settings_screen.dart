import 'package:flutter/material.dart';

import '../../../shared/widgets/responsive_layout.dart';

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
      appBar: AppBar(
        title: const Text(
          "Notification Settings",
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ResponsiveScrollBody(
        maxWidth: 560,
        fillViewport: true,
        padding: ResponsiveLayout.pageInsets(
          context,
          top: 20,
          bottom: 24,
          compact: 16,
          regular: 20,
          wide: 24,
        ),
        child: Column(
          children: [
            _buildSwitchTile(
              title: "General Notifications",
              subtitle: "Receive updates about account activity and reminders.",
              value: generalNotifications,
              onChanged: (val) {
                setState(() {
                  generalNotifications = val;
                });
              },
            ),
            const SizedBox(height: 14),
            _buildSwitchTile(
              title: "Tree Alerts",
              subtitle: "Stay informed about tree health and scan activity.",
              value: treeAlerts,
              onChanged: (val) {
                setState(() {
                  treeAlerts = val;
                });
              },
            ),
            const SizedBox(height: 14),
            _buildSwitchTile(
              title: "App Updates",
              subtitle: "Get notified about new releases and feature changes.",
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Colors.deepPurple,
        inactiveTrackColor: Colors.grey.shade400,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
