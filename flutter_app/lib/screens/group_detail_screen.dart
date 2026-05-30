import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Map<String, dynamic>? _groupDetail;
  Map<String, dynamic>? _poolStatus;
  List<dynamic> _tracker = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final detail = await ApiService.get('/groups/${widget.group['id']}');
      final pool = await ApiService.get('/contributions/pool/${widget.group['id']}');
      final tracker = await ApiService.getList('/contributions/group/${widget.group['id']}');
      setState(() { _groupDetail = detail; _poolStatus = pool; _tracker = tracker; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _makePayment() async {
    try {
      final result = await ApiService.post('/contributions/pay', {
        'group_id': widget.group['id'],
        'payment_method': 'wallet',
      });
      if (mounted) {
        String msg = result['message'] ?? 'Payment successful!';
        if (result['payout'] != null) msg += '\n${result['payout']}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF22C55E), duration: const Duration(seconds: 4)),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final amount = double.tryParse(group['contribution_amount'].toString()) ?? 0;
    final members = (_groupDetail?['members'] as List?) ?? [];
    final payouts = (_groupDetail?['payouts'] as List?) ?? [];
    final pendingInvites = (_groupDetail?['pending_invites'] as List?) ?? [];

    final poolCollected = double.tryParse(_poolStatus?['pool_collected']?.toString() ?? '0') ?? 0;
    final poolTarget = double.tryParse(_poolStatus?['pool_target']?.toString() ?? '0') ?? 0;
    final membersPaid = _poolStatus?['members_paid'] ?? 0;
    final totalMembers = _poolStatus?['total_members'] ?? 0;
    final progressPercent = _poolStatus?['progress_percent'] ?? 0;
    final recipient = _poolStatus?['recipient'];
    final currentCycle = _poolStatus?['current_cycle'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(group['name'] ?? 'Group'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Pool Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text('Pool Balance (This Cycle)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text('₦${poolCollected.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        Text('of ₦${poolTarget.toStringAsFixed(0)} target', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: poolTarget > 0 ? poolCollected / poolTarget : 0,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('$membersPaid/$totalMembers members paid ($progressPercent%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Next Payout Recipient
                  if (recipient != null) Card(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cycle $currentCycle - Money goes to:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(recipient['name'] ?? 'Position $currentCycle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Text('₦${poolTarget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pay Button
                  if (group['status'] == 'active') SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _makePayment,
                      icon: const Icon(Icons.payment),
                      label: Text('Pay ₦${amount.toStringAsFixed(0)}'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contribution Tracker
                  Text('Who Has Paid', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ..._tracker.map((member) {
                    final status = member['payment_status'] ?? 'pending';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: _StatusIcon(status: status),
                        title: Text(member['name'] ?? 'Member', style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('Position ${member['position']}${status == 'paid' ? ' • Paid ${_formatDate(member['paid_at'])}' : ''}'),
                        trailing: _StatusBadge(status: status),
                      ),
                    );
                  }),

                  // Pending invites (members who haven't joined yet)
                  if (pendingInvites.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Waiting to Join', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...pendingInvites.map((inv) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(radius: 18, backgroundColor: Colors.grey[200], child: const Icon(Icons.hourglass_empty, size: 18, color: Colors.grey)),
                        title: Text(inv['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(inv['phone'] ?? ''),
                        trailing: const Text('Invited', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    )),
                  ],

                  const SizedBox(height: 24),

                  // Rotation Schedule
                  Text('Rotation Schedule', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Who receives money each cycle', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 12),
                  ...members.map((member) {
                    final position = member['position'] as int;
                    final hasReceived = payouts.any((p) => p['recipient_id'] == member['id'] && p['status'] == 'completed');
                    final isCurrentRecipient = position == currentCycle;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isCurrentRecipient ? const Color(0xFF10B981).withOpacity(0.05) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: hasReceived
                              ? const Color(0xFF22C55E)
                              : isCurrentRecipient
                                  ? const Color(0xFFF59E0B)
                                  : Colors.grey[300],
                          child: Text('$position', style: TextStyle(color: hasReceived || isCurrentRecipient ? Colors.white : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(member['name'] ?? '', style: TextStyle(fontWeight: isCurrentRecipient ? FontWeight.bold : FontWeight.normal)),
                        trailing: hasReceived
                            ? const Text('Received ✓', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w500))
                            : isCurrentRecipient
                                ? const Text('RECEIVING →', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold))
                                : Text('Cycle $position', style: TextStyle(color: Colors.grey[500])),
                      ),
                    );
                  }),

                  // Group Info
                  const SizedBox(height: 24),
                  Text('Group Info', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _InfoRow(label: 'Type', value: group['type']?.toString().toUpperCase() ?? ''),
                          _InfoRow(label: 'Contribution', value: '₦${amount.toStringAsFixed(0)}'),
                          _InfoRow(label: 'Frequency', value: group['frequency'] ?? ''),
                          _InfoRow(label: 'Members', value: '${members.length}/${group['max_members']}'),
                          _InfoRow(label: 'Status', value: group['status'] ?? ''),
                          if (group['invite_code'] != null) _InfoRow(label: 'Invite Code', value: group['invite_code']),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'paid':
        return const CircleAvatar(radius: 18, backgroundColor: Color(0xFF22C55E), child: Icon(Icons.check, color: Colors.white, size: 20));
      case 'overdue':
        return const CircleAvatar(radius: 18, backgroundColor: Color(0xFFEF4444), child: Icon(Icons.close, color: Colors.white, size: 20));
      default:
        return CircleAvatar(radius: 18, backgroundColor: Colors.amber.shade100, child: const Icon(Icons.schedule, color: Color(0xFFF59E0B), size: 20));
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    switch (status) {
      case 'paid':
        color = const Color(0xFF22C55E);
        text = 'Paid ✓';
        break;
      case 'overdue':
        color = const Color(0xFFEF4444);
        text = 'Defaulted ✗';
        break;
      default:
        color = const Color(0xFFF59E0B);
        text = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
