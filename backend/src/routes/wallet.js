const router = require('express').Router();
const { query } = require('../config/database');
const { auth } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

// Get wallet balance
router.get('/balance', auth, async (req, res) => {
  try {
    const result = await query('SELECT balance FROM wallets WHERE user_id = $1', [req.user.id]);
    res.json({ balance: result.rows[0]?.balance || 0 });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Fund wallet (simulated - integrate Paystack in production)
router.post('/fund', auth, async (req, res) => {
  try {
    const { amount } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ message: 'Invalid amount' });

    await query('UPDATE wallets SET balance = balance + $1, updated_at = NOW() WHERE user_id = $2', [amount, req.user.id]);

    const reference = `WF-${uuidv4().slice(0, 8).toUpperCase()}`;
    await query(
      "INSERT INTO transactions (user_id, type, amount, reference, description) VALUES ($1, 'wallet_fund', $2, $3, 'Wallet funded')",
      [req.user.id, amount, reference]
    );

    res.json({ message: 'Wallet funded successfully', reference });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Withdraw to bank
router.post('/withdraw', auth, async (req, res) => {
  try {
    const { amount } = req.body;
    const wallet = await query('SELECT balance FROM wallets WHERE user_id = $1', [req.user.id]);
    if (parseFloat(wallet.rows[0].balance) < amount)
      return res.status(400).json({ message: 'Insufficient balance' });

    await query('UPDATE wallets SET balance = balance - $1, updated_at = NOW() WHERE user_id = $2', [amount, req.user.id]);

    const reference = `WD-${uuidv4().slice(0, 8).toUpperCase()}`;
    await query(
      "INSERT INTO transactions (user_id, type, amount, reference, description) VALUES ($1, 'withdrawal', $2, $3, 'Withdrawal to bank')",
      [req.user.id, amount, reference]
    );

    res.json({ message: 'Withdrawal initiated', reference });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Transaction history
router.get('/transactions', auth, async (req, res) => {
  try {
    const result = await query(
      `SELECT t.*, g.name as group_name FROM transactions t
       LEFT JOIN groups g ON g.id = t.group_id
       WHERE t.user_id = $1 ORDER BY t.created_at DESC LIMIT 50`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
