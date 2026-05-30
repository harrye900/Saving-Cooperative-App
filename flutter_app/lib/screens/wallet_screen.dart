import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  List<dynamic> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final wallet = await ApiService.get('/wallet/balance');
      final txns = await ApiService.getList('/wallet/transactions');
      setState(() { _balance = double.tryParse(wallet['balance'].toString()) ?? 0; _transactions = txns; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _showFundDialog() {
    final amount = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fund Wallet'),
        content: TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₦)', prefixText: '₦ ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.post('/wallet/fund', {'amount': double.parse(amount.text)});
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Fund'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    final amount = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw'),
        content: TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₦)', prefixText: '₦ ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ApiService.post('/wallet/withdraw', {'amount': double.parse(amount.text)});
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  IconData _txnIcon(String type) {
    switch (type) {
      case 'contribution': return Icons.arrow_upward;
      case 'payout': return Icons.arrow_downward;
      case 'loan_disbursement': return Icons.account_balance;
      case 'loan_repayment': return Icons.payment;
      case 'wallet_fund': return Icons.add_circle;
      case 'withdrawal': return Icons.remove_circle;
      default: return Icons.swap_horiz;
    }
  }

  Color _txnColor(String type) {
    if (['payout', 'loan_disbursement', 'wallet_fund'].contains(type)) return const Color(0xFF22C55E);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Wallet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('₦${_balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _showFundDialog,
                        icon: const Icon(Icons.add, color: Colors.white, size: 18),
                        label: const Text('Fund', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _showWithdrawDialog,
                        icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 18),
                        label: const Text('Withdraw', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                      )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction History
            Text('Transaction History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator())
            else if (_transactions.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Text('No transactions yet', style: TextStyle(color: Colors.grey[600]))))
            else
              ..._transactions.map((txn) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _txnColor(txn['type']).withOpacity(0.1),
                    child: Icon(_txnIcon(txn['type']), color: _txnColor(txn['type']), size: 20),
                  ),
                  title: Text(txn['description'] ?? txn['type'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('${txn['reference'] ?? ''} • ${txn['created_at']?.toString().substring(0, 10) ?? ''}', style: const TextStyle(fontSize: 12)),
                  trailing: Text(
                    '${['payout', 'loan_disbursement', 'wallet_fund'].contains(txn['type']) ? '+' : '-'}₦${double.tryParse(txn['amount'].toString())?.toStringAsFixed(0) ?? '0'}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _txnColor(txn['type'])),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }
}
