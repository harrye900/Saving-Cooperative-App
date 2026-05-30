const router = require('express').Router();
const { query } = require('../config/database');
const { auth } = require('../middleware/auth');

// Middleware: Super Admin only
const superAdminOnly = (req, res, next) => {
  if (req.user.role !== 'super_admin') return res.status(403).json({ message: 'Super Admin access required' });
  next();
};

// Get platform stats
router.get('/stats', auth, superAdminOnly, async (req, res) => {
  try {
    const users = await query('SELECT COUNT(*) FROM users');
    const groups = await query('SELECT COUNT(*) FROM groups');
    const pendingGroups = await query("SELECT COUNT(*) FROM groups WHERE status = 'pending_approval'");
    const activeGroups = await query("SELECT COUNT(*) FROM groups WHERE status = 'active'");
    const totalContributions = await query("SELECT COALESCE(SUM(amount), 0) as total FROM contributions WHERE status = 'paid'");
    const totalLoans = await query("SELECT COALESCE(SUM(amount), 0) as total FROM loans WHERE status IN ('active', 'approved')");

    res.json({
      total_users: parseInt(users.rows[0].count),
      total_groups: parseInt(groups.rows[0].count),
      pending_approval: parseInt(pendingGroups.rows[0].count),
      active_groups: parseInt(activeGroups.rows[0].count),
      total_contributions: totalContributions.rows[0].total,
      total_loans: totalLoans.rows[0].total,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get all users
router.get('/users', auth, superAdminOnly, async (req, res) => {
  try {
    const result = await query(
      `SELECT u.id, u.name, u.phone, u.email, u.role, u.kyc_verified, u.created_at,
        w.balance as wallet_balance,
        (SELECT COUNT(*) FROM group_members WHERE user_id = u.id) as group_count
       FROM users u LEFT JOIN wallets w ON w.user_id = u.id
       ORDER BY u.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Make someone a group admin
router.post('/users/:id/make-admin', auth, superAdminOnly, async (req, res) => {
  try {
    await query("UPDATE users SET role = 'admin' WHERE id = $1", [req.params.id]);
    res.json({ message: 'User promoted to admin' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
