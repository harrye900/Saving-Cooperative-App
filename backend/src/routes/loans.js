const router = require('express').Router();
const { query } = require('../config/database');
const { auth } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

// Request loan
router.post('/request', auth, async (req, res) => {
  try {
    const { group_id, amount, duration_months, reason, guarantor_id } = req.body;

    const group = await query('SELECT * FROM groups WHERE id = $1', [group_id]);
    if (!group.rows.length) return res.status(404).json({ message: 'Group not found' });
    const g = group.rows[0];

    // Calculate loan limit (total contributions * 2)
    const totalContrib = await query(
      "SELECT COALESCE(SUM(amount), 0) as total FROM contributions WHERE user_id = $1 AND group_id = $2 AND status = 'paid'",
      [req.user.id, group_id]
    );
    const limit = parseFloat(totalContrib.rows[0].total) * 2;
    if (amount > limit) return res.status(400).json({ message: `Loan limit is ₦${limit.toLocaleString()}` });

    const interest_rate = g.interest_rate;
    const total_repayment = amount * (1 + (interest_rate / 100) * duration_months);
    const due_date = new Date();
    due_date.setMonth(due_date.getMonth() + duration_months);

    const result = await query(
      `INSERT INTO loans (borrower_id, group_id, amount, interest_rate, total_repayment, duration_months, reason, guarantor_id, due_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [req.user.id, group_id, amount, interest_rate, total_repayment, duration_months, reason, guarantor_id || null, due_date]
    );

    res.status(201).json({
      loan: result.rows[0],
      message: 'Loan request submitted',
      monthly_installment: (total_repayment / duration_months).toFixed(2)
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Approve loan (group admin)
router.post('/:id/approve', auth, async (req, res) => {
  try {
    const loan = await query('SELECT l.*, g.admin_id FROM loans l JOIN groups g ON g.id = l.group_id WHERE l.id = $1', [req.params.id]);
    if (!loan.rows.length) return res.status(404).json({ message: 'Loan not found' });
    if (loan.rows[0].admin_id !== req.user.id) return res.status(403).json({ message: 'Only group admin can approve' });

    await query("UPDATE loans SET status = 'approved', approved_by = $1, approved_at = NOW() WHERE id = $2", [req.user.id, req.params.id]);

    // Disburse to wallet
    await query('UPDATE wallets SET balance = balance + $1, updated_at = NOW() WHERE user_id = $2', [loan.rows[0].amount, loan.rows[0].borrower_id]);

    const reference = `LOAN-${uuidv4().slice(0, 8).toUpperCase()}`;
    await query(
      "INSERT INTO transactions (user_id, type, amount, reference, description, group_id) VALUES ($1, 'loan_disbursement', $2, $3, 'Loan disbursed', $4)",
      [loan.rows[0].borrower_id, loan.rows[0].amount, reference, loan.rows[0].group_id]
    );

    await query("UPDATE loans SET status = 'active' WHERE id = $1", [req.params.id]);
    res.json({ message: 'Loan approved and disbursed' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Repay loan
router.post('/:id/repay', auth, async (req, res) => {
  try {
    const { amount } = req.body;
    const loan = await query('SELECT * FROM loans WHERE id = $1 AND borrower_id = $2', [req.params.id, req.user.id]);
    if (!loan.rows.length) return res.status(404).json({ message: 'Loan not found' });

    const l = loan.rows[0];
    const remaining = parseFloat(l.total_repayment) - parseFloat(l.amount_paid);
    const repayAmount = Math.min(amount, remaining);

    await query('UPDATE wallets SET balance = balance - $1, updated_at = NOW() WHERE user_id = $2', [repayAmount, req.user.id]);

    const newPaid = parseFloat(l.amount_paid) + repayAmount;
    const newStatus = newPaid >= parseFloat(l.total_repayment) ? 'completed' : 'active';
    await query('UPDATE loans SET amount_paid = $1, status = $2 WHERE id = $3', [newPaid, newStatus, req.params.id]);

    const reference = `REP-${uuidv4().slice(0, 8).toUpperCase()}`;
    await query(
      "INSERT INTO transactions (user_id, type, amount, reference, description, group_id) VALUES ($1, 'loan_repayment', $2, $3, 'Loan repayment', $4)",
      [req.user.id, repayAmount, reference, l.group_id]
    );

    res.json({ message: newStatus === 'completed' ? 'Loan fully repaid! 🎉' : 'Repayment recorded', remaining: remaining - repayAmount });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get my loans
router.get('/mine', auth, async (req, res) => {
  try {
    const result = await query(
      `SELECT l.*, g.name as group_name FROM loans l JOIN groups g ON g.id = l.group_id
       WHERE l.borrower_id = $1 ORDER BY l.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get pending loans for admin
router.get('/pending/:groupId', auth, async (req, res) => {
  try {
    const result = await query(
      `SELECT l.*, u.name as borrower_name, u.phone as borrower_phone
       FROM loans l JOIN users u ON u.id = l.borrower_id
       WHERE l.group_id = $1 AND l.status = 'pending'`,
      [req.params.groupId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
