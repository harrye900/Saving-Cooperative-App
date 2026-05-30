const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../config/database');
const { auth } = require('../middleware/auth');

// Register with phone number
// If this phone was invited to a group, auto-join them
router.post('/register', async (req, res) => {
  try {
    const { name, phone, email, password } = req.body;
    if (!name || !phone || !password)
      return res.status(400).json({ message: 'Name, phone and password are required' });

    const exists = await query('SELECT id FROM users WHERE phone = $1', [phone]);
    if (exists.rows.length) return res.status(400).json({ message: 'Phone already registered' });

    const password_hash = await bcrypt.hash(password, 10);
    const result = await query(
      'INSERT INTO users (name, phone, email, password_hash) VALUES ($1, $2, $3, $4) RETURNING id, name, phone, email, role',
      [name, phone, email || null, password_hash]
    );
    const user = result.rows[0];

    // Create wallet
    await query('INSERT INTO wallets (user_id) VALUES ($1)', [user.id]);

    // Auto-join any groups this phone was invited to
    const pendingInvites = await query(
      "SELECT * FROM group_invites WHERE phone = $1 AND status = 'pending'",
      [phone]
    );

    const joinedGroups = [];
    for (const invite of pendingInvites.rows) {
      try {
        await query('INSERT INTO group_members (group_id, user_id, position) VALUES ($1, $2, $3)', [invite.group_id, user.id, invite.position]);
        await query("UPDATE group_invites SET status = 'accepted' WHERE id = $1", [invite.id]);

        // Check if group is now full → activate
        const group = await query('SELECT max_members FROM groups WHERE id = $1', [invite.group_id]);
        const memberCount = await query('SELECT COUNT(*) FROM group_members WHERE group_id = $1', [invite.group_id]);
        if (parseInt(memberCount.rows[0].count) >= group.rows[0].max_members) {
          await query("UPDATE groups SET status = 'active' WHERE id = $1", [invite.group_id]);
        }

        joinedGroups.push(invite.group_id);
      } catch (_) {} // Skip if position conflict
    }

    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
    res.status(201).json({
      token,
      user,
      joined_groups: joinedGroups.length,
      message: joinedGroups.length > 0
        ? `Welcome! You've been automatically added to ${joinedGroups.length} group(s).`
        : 'Registration successful!'
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { phone, password } = req.body;
    const result = await query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (!result.rows.length) return res.status(400).json({ message: 'Invalid credentials' });

    const user = result.rows[0];
    if (!(await bcrypt.compare(password, user.password_hash)))
      return res.status(400).json({ message: 'Invalid credentials' });

    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
    res.json({ token, user: { id: user.id, name: user.name, phone: user.phone, email: user.email, role: user.role } });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Set transaction PIN
router.post('/set-pin', auth, async (req, res) => {
  try {
    const { pin } = req.body;
    if (!pin || pin.length !== 4) return res.status(400).json({ message: 'PIN must be 4 digits' });

    const pin_hash = await bcrypt.hash(pin, 10);
    await query('UPDATE users SET pin_hash = $1 WHERE id = $2', [pin_hash, req.user.id]);
    res.json({ message: 'PIN set successfully' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get profile
router.get('/profile', auth, async (req, res) => {
  try {
    const result = await query(
      'SELECT u.id, u.name, u.phone, u.email, u.role, u.kyc_verified, u.created_at, w.balance as wallet_balance FROM users u LEFT JOIN wallets w ON w.user_id = u.id WHERE u.id = $1',
      [req.user.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
