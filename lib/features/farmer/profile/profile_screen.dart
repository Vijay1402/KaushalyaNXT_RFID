import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
        title: const Text("Profile"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,

        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.settings),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading: Icon(Icons.notifications_none),
                  title: Text("Notification Settings"),
                ),
              ),
              const PopupMenuItem(
                value: 2,
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text("FAQs"),
                ),
              ),
              const PopupMenuItem(
                value: 3,
                child: ListTile(
                  leading: Icon(Icons.support_agent),
                  title: Text("Support"),
                ),
              ),
              const PopupMenuItem(
                value: 4,
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text("About App"),
                ),
              ),
            ],

            /// ✅ ONLY CHANGE (NAVIGATION ADDED)
            onSelected: (value) {
              switch (value) {
                case 1:
                  context.push('/notification-settings');
                  break;

                case 2:
                  context.push('/faq');
                  break;

                case 3:
                  context.push('/support');
                  break;

                case 4:
                  showAboutAppDialog(context);
                  break;
              }
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildFarmDetails(),
            const SizedBox(height: 20),
            _buildActions(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 40, color: Colors.green),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Farmer Rajesh",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Organic Farmer",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return _card(
      title: "Personal Information",
      children: const [
        _InfoRow(icon: Icons.phone, label: "Phone", value: "+91 9876543210"),
        _InfoRow(icon: Icons.location_on, label: "Location", value: "Karnataka, India"),
        _InfoRow(icon: Icons.email, label: "Email", value: "farmer@gmail.com"),
      ],
    );
  }

  Widget _buildFarmDetails() {
    return _card(
      title: "Farm Details",
      children: const [
        _InfoRow(icon: Icons.landscape, label: "Land Size", value: "5 Acres"),
        _InfoRow(icon: Icons.park, label: "Total Trees", value: "120"),
        _InfoRow(icon: Icons.eco, label: "Main Crops", value: "Mango, Coconut"),
        _InfoRow(icon: Icons.water_drop, label: "Irrigation", value: "Drip Irrigation"),
      ],
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Edit Profile Coming Soon")),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text("Edit Profile"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text("Logout"),
          ],
        ),
        content: const Text(
          "Are you sure you want to logout?\nYou will need to login again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);

              final notifier = ref.read(authStateProvider.notifier);
              await notifier.logout();

              if (!context.mounted) return;

              context.go('/login');
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
void showAboutAppDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TITLE
              const Text(
                "Agri App",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              /// VERSION
              const Text(
                "1.0",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 20),

              /// DESCRIPTION
              const Text(
                "Helping farmers digitally 🌱",
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 30),

              /// BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: "Agri App",
                        applicationVersion: "1.0",
                      );
                    },
                    child: const Text("View licenses"),
                  ),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    },
  );
}