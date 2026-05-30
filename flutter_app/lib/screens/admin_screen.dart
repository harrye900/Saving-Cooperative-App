import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _stats;
  List<dynamic> _pendingGroups = [];
  List<dynamic> _allUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await ApiService.get('/admin/stats');
      final pending = await ApiService.getList('/groups/pending-approval');
      final users = await ApiService.getList('/admin/users');
      setState(() { _stats = stats; _pendingGroups = pending; _allUsers = users; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _approveGroup(String groupId) async {
    try {
      await ApiService.post('/groups/$groupId/approve', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group approved! SMS invites sent ✓'), backgroundColor: Color(0xFF22C55E)));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectGroup(String groupId) async {
    try {
      await ApiService.post('/groups/$groupId/reject', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group rejected'), backgroundColor: Colors.orange));
      }
      _loadData();
    } catch (_) {}
  }

  void _showGroupMembers(Map<String, dynamic> group) async {
    try {
      final invites = await ApiService.getList('/groups/${group['id']}/invites');
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invited Members - ${group['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${invites.length} members invited', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              ...invites.map((inv) => ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: inv['status'] == 'accepted' ? const Color(0xFF22C55E).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  child: Text('${inv['position']}', style: TextStyle(color: inv['status'] == 'accepted' ? const Color(0xFF22C55E) : Colors.orange, fontWeight: FontWeight.bold)),
                ),
                title: Text(inv['name'] ?? ''),
                subtitle: Text(inv['phone'] ?? ''),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: inv['status'] == 'accepted' ? const Color(0xFF22C55E).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inv['status'] == 'accepted' ? 'Joined' : 'Pending',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: inv['status'] == 'accepted' ? const Color(0xFF22C55E) : Colors.orange),
                  ),
                ),
              )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Approvals'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(),
                _buildApprovals(),
                _buildUsers(),
              ],
            ),
    );
  }

  Widget _buildOverview() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Row(children: [
            _AdminStatCard(title: 'Total Users', value: '${_stats?['total_users'] ?? 0}', icon: Icons.people, color: const Color(0xFF3B82F6)),
            const SizedBox(width: 12),
            _AdminStatCard(title: 'Total Groups', value: '${_stats?['total_groups'] ?? 0}', icon: Icons.group_work, color: const Color(0xFF10B981)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _AdminStatCard(title: 'Pending Approval', value: '${_stats?['pending_approval'] ?? 0}', icon: Icons.pending_actions, color: const Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            _AdminStatCard(title: 'Active Groups', value: '${_stats?['active_groups'] ?? 0}', icon: Icons.check_circle, color: const Color(0xFF22C55E)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _AdminStatCard(title: 'Contributions', value: '₦${_formatAmount(_stats?['total_contributions'])}', icon: Icons.savings, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 12),
            _AdminStatCard(title: 'Active Loans', value: '₦${_formatAmount(_stats?['total_loans'])}', icon: Icons.account_balance, color: const Color(0xFFEF4444)),
          ]),
        ],
      ),
    );
  }

  Widget _buildApprovals() {
    if (_pendingGroups.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No pending approvals', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _pendingGroups.length,
        itemBuilder: (_, i) {
          final group = _pendingGroups[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(group['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(group['type']?.toString().toUpperCase() ?? '', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Created by: ${group['admin_name']} (${group['admin_phone']})', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('₦${double.tryParse(group['contribution_amount'].toString())?.toStringAsFixed(0) ?? '0'} / ${group['frequency']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('${group['invited_count'] ?? 0} members invited • Max ${group['max_members']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => _showGroupMembers(group),
                        child: const Text('View Members'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton(
                        onPressed: () => _rejectGroup(group['id']),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text('Reject'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton(
                        onPressed: () => _approveGroup(group['id']),
                        child: const Text('Approve'),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUsers() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _allUsers.length,
        itemBuilder: (_, i) {
          final user = _allUsers[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                child: Text(user['name']?.substring(0, 1) ?? 'U', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ),
              title: Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('${user['phone']} • ${user['group_count'] ?? 0} groups'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user['role'] == 'super_admin' ? Colors.purple.withOpacity(0.1) : user['role'] == 'admin' ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(user['role'] ?? 'member', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: user['role'] == 'super_admin' ? Colors.purple : user['role'] == 'admin' ? const Color(0xFF3B82F6) : Colors.grey[700])),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    final val = double.tryParse(amount?.toString() ?? '0') ?? 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
    return val.toStringAsFixed(0);
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _AdminStatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
