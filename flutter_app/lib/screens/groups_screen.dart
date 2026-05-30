import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<dynamic> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await ApiService.getList('/groups/my-groups');
      setState(() { _groups = groups; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _showCreateDialog() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _CreateGroupScreen(onCreated: _loadGroups)));
  }

  void _showJoinDialog() {
    final code = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(controller: code, decoration: const InputDecoration(labelText: 'Invite Code', hintText: 'Enter 8-character code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.post('/groups/join', {'invite_code': code.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
              _loadGroups();
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Groups', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (context.read<AuthService>().user?['role'] == 'admin' || context.read<AuthService>().user?['role'] == 'super_admin')
                  Row(children: [
                    IconButton(onPressed: _showJoinDialog, icon: const Icon(Icons.qr_code), tooltip: 'Join Group'),
                    IconButton(onPressed: _showCreateDialog, icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 32), tooltip: 'Create Group'),
                  ]),
              ],
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _groups.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No groups yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('You\'ll be added to a group by your admin', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _loadGroups,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _groups.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(group: _groups[i]))),
                        child: _GroupCard(group: _groups[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// CREATE GROUP SCREEN - with member addition
// ============================================
class _CreateGroupScreen extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateGroupScreen({required this.onCreated});

  @override
  State<_CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<_CreateGroupScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _maxMembers = TextEditingController();
  String _type = 'ajo';
  String _frequency = 'monthly';
  final List<Map<String, String>> _members = [];
  bool _submitting = false;

  void _addMember() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone), hintText: '08012345678')),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.email))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                setState(() {
                  _members.add({'name': nameCtrl.text, 'phone': phoneCtrl.text, 'email': emailCtrl.text});
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    if (_name.text.isEmpty || _amount.text.isEmpty || _maxMembers.text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await ApiService.post('/groups', {
        'name': _name.text,
        'type': _type,
        'contribution_amount': double.parse(_amount.text),
        'frequency': _frequency,
        'max_members': int.parse(_maxMembers.text),
        'start_date': DateTime.now().toIso8601String(),
        'members': _members,
      });
      widget.onCreated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created! Awaiting admin approval.'), backgroundColor: Color(0xFF10B981)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Group Details Section
          Text('Group Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Group Name', hintText: 'e.g. Unity Women Savings')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'ajo', child: Text('Ajo (Rotation)')),
              DropdownMenuItem(value: 'thrift', child: Text('Thrift (Daily Savings)')),
              DropdownMenuItem(value: 'cooperative', child: Text('Cooperative')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Contribution Amount (₦)', prefixText: '₦ ')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            ],
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: _maxMembers, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Members (including you)')),
          const SizedBox(height: 24),

          // Members Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Members (${_members.length} added)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              TextButton.icon(onPressed: _addMember, icon: const Icon(Icons.person_add, size: 18), label: const Text('Add')),
            ],
          ),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[400]),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Add members by their name and phone number. They will receive an SMS invite link.', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                  ],
                ),
              ),
            )
          else
            ..._members.asMap().entries.map((entry) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                  child: Text('${entry.key + 2}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                title: Text(entry.value['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(entry.value['phone']!),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                  onPressed: () => setState(() => _members.removeAt(entry.key)),
                ),
              ),
            )),
          const SizedBox(height: 24),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _createGroup,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Group & Submit for Approval'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Group will be reviewed by admin before members are invited.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }
}

// ============================================
// GROUP CARD WIDGET
// ============================================
class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  const _GroupCard({required this.group});

  Color _typeColor() {
    switch (group['type']) {
      case 'ajo': return const Color(0xFF10B981);
      case 'thrift': return const Color(0xFFF59E0B);
      default: return const Color(0xFF3B82F6);
    }
  }

  Color _statusColor() {
    switch (group['status']) {
      case 'active': return const Color(0xFF22C55E);
      case 'pending_approval': return const Color(0xFFF59E0B);
      default: return Colors.grey;
    }
  }

  String _statusText() {
    switch (group['status']) {
      case 'active': return 'Active';
      case 'pending_approval': return 'Awaiting Approval';
      case 'pending': return 'Waiting for Members';
      default: return group['status'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Expanded(child: Text(group['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _typeColor().withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(group['type'].toString().toUpperCase(), style: TextStyle(color: _typeColor(), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('₦${double.tryParse(group['contribution_amount'].toString())?.toStringAsFixed(0) ?? '0'} / ${group['frequency']}', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${group['member_count'] ?? 1}/${group['max_members']} members', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _statusColor().withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(_statusText(), style: TextStyle(fontSize: 11, color: _statusColor(), fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (int.tryParse(group['member_count']?.toString() ?? '1') ?? 1) / (group['max_members'] ?? 10),
              backgroundColor: Colors.grey[200],
              color: _typeColor(),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
