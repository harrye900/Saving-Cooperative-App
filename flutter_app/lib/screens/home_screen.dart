import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'group_detail_screen.dart';
import 'groups_screen.dart';
import 'loans_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _wallet;
  List<dynamic> _groups = [];
  List<dynamic> _contributions = [];
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final wallet = await ApiService.get('/wallet/balance');
      final groups = await ApiService.getList('/groups/my-groups');
      final contributions = await ApiService.getList('/contributions/mine');
      final notifications = await ApiService.getList('/notifications');
      setState(() { _wallet = wallet; _groups = groups; _contributions = contributions; _notifications = notifications; });
    } catch (_) {}
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().user;
    final totalSaved = _contributions.where((c) => c['status'] == 'paid').fold<double>(0, (sum, c) => sum + (double.tryParse(c['amount'].toString()) ?? 0));
    final unreadNotifications = _notifications.where((n) => n['is_read'] == false).length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header with greeting and notification bell
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_greeting()} 👋', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      Text(user?['name'] ?? 'User', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    IconButton(icon: const Icon(Icons.notifications_outlined, size: 28), onPressed: () {}),
                    if (unreadNotifications > 0) Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: Text('$unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Wallet Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('₦${_formatAmount(double.tryParse(_wallet?['balance']?.toString() ?? '0') ?? 0)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Saved', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('₦${_formatAmount(totalSaved)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _QuickAction(icon: Icons.payment, label: 'Pay', onTap: () {
                  if (_groups.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(group: _groups[0])));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join a group first to make payments')));
                  }
                }),
                _QuickAction(icon: Icons.request_page, label: 'Loan', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoansScreen()));
                }),
                _QuickAction(icon: Icons.wallet, label: 'Fund\nWallet', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                }),
                _QuickAction(icon: Icons.history, label: 'History', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                }),
              ],
            ),
            const SizedBox(height: 24),

            // My Groups Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Groups', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (_groups.isNotEmpty) TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsScreen())),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_groups.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.group_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No groups yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('You\'ll see your groups here once you\'re added', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ..._groups.map((group) => _MemberGroupCard(
                group: group,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group))),
              )),

            const SizedBox(height: 24),

            // Recent Notifications
            if (_notifications.isNotEmpty) ...[
              Text('Notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._notifications.take(5).map((n) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: n['is_read'] == false ? const Color(0xFF10B981).withOpacity(0.03) : null,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: _notifColor(n['type']).withOpacity(0.1),
                    child: Icon(_notifIcon(n['type']), color: _notifColor(n['type']), size: 18),
                  ),
                  title: Text(n['title'] ?? '', style: TextStyle(fontWeight: n['is_read'] == false ? FontWeight.w600 : FontWeight.normal, fontSize: 14)),
                  subtitle: Text(n['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  IconData _notifIcon(String? type) {
    switch (type) {
      case 'payout': return Icons.celebration;
      case 'group': return Icons.group;
      case 'loan': return Icons.account_balance;
      case 'reminder': return Icons.notifications;
      default: return Icons.info;
    }
  }

  Color _notifColor(String? type) {
    switch (type) {
      case 'payout': return const Color(0xFFF59E0B);
      case 'group': return const Color(0xFF10B981);
      case 'loan': return const Color(0xFF3B82F6);
      case 'reminder': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}

// ============================================
// Member Group Card - shows group info clearly
// ============================================
class _MemberGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;
  const _MemberGroupCard({required this.group, required this.onTap});

  Color _typeColor() {
    switch (group['type']) {
      case 'ajo': return const Color(0xFF10B981);
      case 'thrift': return const Color(0xFFF59E0B);
      default: return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(group['contribution_amount'].toString()) ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group name + type badge
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _typeColor().withOpacity(0.1),
                    child: Icon(Icons.group, color: _typeColor(), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('Admin: ${group['admin_name'] ?? 'Unknown'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _typeColor().withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(group['type']?.toString().toUpperCase() ?? '', style: TextStyle(color: _typeColor(), fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Divider
              Divider(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 12),
              // Info row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GroupInfoItem(icon: Icons.people, label: '${group['member_count'] ?? 1}/${group['max_members']} members'),
                  _GroupInfoItem(icon: Icons.calendar_today, label: group['frequency'] ?? ''),
                  _GroupInfoItem(icon: Icons.payments, label: '₦${amount.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 12),
              // Status + action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: group['status'] == 'active' ? const Color(0xFF22C55E).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      group['status'] == 'active' ? '● Active' : group['status'] == 'pending_approval' ? '● Awaiting Approval' : '● ${group['status'] ?? ''}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: group['status'] == 'active' ? const Color(0xFF22C55E) : Colors.orange),
                    ),
                  ),
                  if (group['status'] == 'active')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Pay Now →', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GroupInfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 24, backgroundColor: const Color(0xFF10B981).withOpacity(0.1), child: Icon(icon, color: const Color(0xFF10B981))),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
