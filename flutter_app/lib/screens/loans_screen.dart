import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  List<dynamic> _loans = [];
  List<dynamic> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final loans = await ApiService.getList('/loans/mine');
      final groups = await ApiService.getList('/groups/my-groups');
      setState(() { _loans = loans; _groups = groups; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _showRequestDialog() {
    final amount = TextEditingController();
    final duration = TextEditingController();
    final reason = TextEditingController();
    String? selectedGroup;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(builder: (ctx, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request Loan', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedGroup,
              decoration: const InputDecoration(labelText: 'Select Group'),
              items: _groups.map((g) => DropdownMenuItem(value: g['id'] as String, child: Text(g['name']))).toList(),
              onChanged: (v) => setModalState(() => selectedGroup = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₦)', prefixText: '₦ ')),
            const SizedBox(height: 12),
            TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (months)')),
            const SizedBox(height: 12),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason (optional)')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (selectedGroup == null) return;
                await ApiService.post('/loans/request', {
                  'group_id': selectedGroup, 'amount': double.parse(amount.text),
                  'duration_months': int.parse(duration.text), 'reason': reason.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan request submitted ✓')));
              },
              child: const Text('Submit Request'),
            ),
          ],
        )),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return const Color(0xFF22C55E);
      case 'pending': return const Color(0xFFF59E0B);
      case 'overdue': return const Color(0xFFEF4444);
      case 'completed': return Colors.grey;
      default: return Colors.grey;
    }
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
                Text('Loans', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(onPressed: _showRequestDialog, icon: const Icon(Icons.add, size: 18), label: const Text('Request')),
              ],
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loans.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No loans yet', style: TextStyle(color: Colors.grey[600])),
                  ]))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _loans.length,
                      itemBuilder: (_, i) {
                        final loan = _loans[i];
                        final amount = double.tryParse(loan['amount'].toString()) ?? 0;
                        final totalRepay = double.tryParse(loan['total_repayment'].toString()) ?? 0;
                        final paid = double.tryParse(loan['amount_paid'].toString()) ?? 0;
                        final progress = totalRepay > 0 ? paid / totalRepay : 0.0;

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
                                    Text('₦${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: _statusColor(loan['status']).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: Text(loan['status'], style: TextStyle(color: _statusColor(loan['status']), fontWeight: FontWeight.w600, fontSize: 12)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(loan['group_name'] ?? '', style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Paid: ₦${paid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
                                    Text('Total: ₦${totalRepay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[200], color: _statusColor(loan['status']), borderRadius: BorderRadius.circular(4)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
