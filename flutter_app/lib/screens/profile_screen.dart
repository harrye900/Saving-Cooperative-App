import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          // Profile Header
          Center(
            child: Column(
              children: [
                CircleAvatar(radius: 40, backgroundColor: const Color(0xFF10B981).withOpacity(0.1), child: Text(user?['name']?.substring(0, 1) ?? 'U', style: const TextStyle(fontSize: 32, color: Color(0xFF10B981)))),
                const SizedBox(height: 12),
                Text(user?['name'] ?? 'User', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(user?['phone'] ?? '', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: user?['kyc_verified'] == true ? const Color(0xFF22C55E).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user?['kyc_verified'] == true ? '✓ Verified' : 'Unverified',
                    style: TextStyle(color: user?['kyc_verified'] == true ? const Color(0xFF22C55E) : Colors.orange, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Settings
          _SettingsTile(icon: Icons.account_balance, title: 'Bank Accounts', onTap: () {}),
          _SettingsTile(icon: Icons.notifications, title: 'Notifications', onTap: () {}),
          _SettingsTile(icon: Icons.lock, title: 'Change PIN', onTap: () {}),
          _SettingsTile(icon: Icons.fingerprint, title: 'Biometric Login', onTap: () {}),
          _SettingsTile(icon: Icons.verified_user, title: 'KYC Verification', onTap: () {}),
          _SettingsTile(icon: Icons.help, title: 'Help & Support', onTap: () {}),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              await context.read<AuthService>().logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Logout', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF10B981)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
