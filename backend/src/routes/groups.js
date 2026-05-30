const router = require('express').Router();
const { query } = require('../config/database');
const { auth, adminOnly } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');
const { sendInviteSMS } = require('../services/sms');

// ============================================
// GROUP ADMIN: Create group + add members
// ============================================
router.post('/', auth, async (req, res) => {
  try {
    const { name, description, type, contribution_amount, frequency, max_members, start_date, penalty_amount, interest_rate, members } = req.body;
    const invite_code = uuidv4().slice(0, 8).toUpperCase();

    // Create group (status = pending_approval until Super Admin approves)
    const result = await query(
      `INSERT INTO groups (name, description, type, admin_id, contribution_amount, frequency, max_members, start_date, penalty_amount, interest_rate, invite_code, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'pending_approval') RETURNING *`,
      [name, description, type, req.user.id, contribution_amount, frequency, max_members, start_date, penalty_amount || 0, interest_rate || 5, invite_code]
    );
    const group = result.rows[0];

    // Promote user to admin role if they're just a member
    if (req.user.role === 'member') {
      await query("UPDATE users SET role = 'admin' WHERE id = $1", [req.user.id]);
    }

    // Add creator as first member (position 1)
    await query('INSERT INTO group_members (group_id, user_id, position) VALUES ($1, $2, 1)', [group.id, req.user.id]);

    // Add invited members (name, phone, email)
    if (members && members.length > 0) {
      for (let i = 0; i < members.length; i++) {
        const m = members[i];
        const invite_token = uuidv4().slice(0, 12).toUpperCase();
        await query(
          'INSERT INTO group_invites (group_id, name, phone, email, position, invite_token) VALUES ($1,$2,$3,$4,$5,$6)',
          [group.id, m.name, m.phone, m.email || null, i + 2, invite_token] // position starts at 2 (admin is 1)
        );
      }
    }

    res.status(201).json({ ...group, message: 'Group created! Awaiting Super Admin approval.' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// SUPER ADMIN: Approve group & send SMS invites
// ============================================
router.post('/:id/approve', auth, async (req, res) => {
  try {
    // Check if super admin
    if (req.user.role !== 'super_admin') {
      return res.status(403).json({ message: 'Only Super Admin can approve groups' });
    }

    const group = await query('SELECT * FROM groups WHERE id = $1', [req.params.id]);
    if (!group.rows.length) return res.status(404).json({ message: 'Group not found' });

    // Approve the group
    await query(
      "UPDATE groups SET status = 'pending', approved = TRUE, approved_by = $1, approved_at = NOW() WHERE id = $2",
      [req.user.id, req.params.id]
    );

    // Get all invited members and send SMS
    const invites = await query('SELECT * FROM group_invites WHERE group_id = $1 AND status = $2', [req.params.id, 'pending']);

    const g = group.rows[0];
    for (const invite of invites.rows) {
      const inviteLink = `https://ajosave.app/join/${invite.invite_token}`;
      const message = `Hi ${invite.name}! You've been invited to join "${g.name}" on AjoSave. Contribute ₦${g.contribution_amount} ${g.frequency}. Click to join: ${inviteLink}`;

      await sendInviteSMS(invite.phone, message);
      await query('UPDATE group_invites SET sms_sent = TRUE WHERE id = $1', [invite.id]);
    }

    res.json({ message: `Group approved! SMS sent to ${invites.rows.length} members.` });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// SUPER ADMIN: Reject group
// ============================================
router.post('/:id/reject', auth, async (req, res) => {
  try {
    if (req.user.role !== 'super_admin') return res.status(403).json({ message: 'Only Super Admin' });

    await query("UPDATE groups SET status = 'paused' WHERE id = $1", [req.params.id]);
    res.json({ message: 'Group rejected' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// SUPER ADMIN: Get all groups pending approval
// ============================================
router.get('/pending-approval', auth, async (req, res) => {
  try {
    if (req.user.role !== 'super_admin') return res.status(403).json({ message: 'Only Super Admin' });

    const result = await query(
      `SELECT g.*, u.name as admin_name, u.phone as admin_phone,
        (SELECT COUNT(*) FROM group_invites WHERE group_id = g.id) as invited_count
       FROM groups g JOIN users u ON u.id = g.admin_id
       WHERE g.status = 'pending_approval'
       ORDER BY g.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// SUPER ADMIN: Get invited members for a group
// ============================================
router.get('/:id/invites', auth, async (req, res) => {
  try {
    const result = await query(
      'SELECT * FROM group_invites WHERE group_id = $1 ORDER BY position',
      [req.params.id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// MEMBER: Join via invite link token
// ============================================
router.post('/join-invite/:token', auth, async (req, res) => {
  try {
    const invite = await query("SELECT * FROM group_invites WHERE invite_token = $1 AND status = 'pending'", [req.params.token]);
    if (!invite.rows.length) return res.status(404).json({ message: 'Invalid or expired invite' });

    const inv = invite.rows[0];
    const group = await query('SELECT * FROM groups WHERE id = $1', [inv.group_id]);
    if (!group.rows.length) return res.status(404).json({ message: 'Group not found' });

    // Check if already a member
    const existing = await query('SELECT id FROM group_members WHERE group_id = $1 AND user_id = $2', [inv.group_id, req.user.id]);
    if (existing.rows.length) return res.status(400).json({ message: 'Already a member' });

    // Add to group at the assigned position
    await query('INSERT INTO group_members (group_id, user_id, position) VALUES ($1, $2, $3)', [inv.group_id, req.user.id, inv.position]);

    // Mark invite as accepted
    await query("UPDATE group_invites SET status = 'accepted' WHERE id = $1", [inv.id]);

    // Check if group is now full → activate and generate rotation
    const memberCount = await query('SELECT COUNT(*) FROM group_members WHERE group_id = $1', [inv.group_id]);
    if (parseInt(memberCount.rows[0].count) >= group.rows[0].max_members) {
      await query("UPDATE groups SET status = 'active' WHERE id = $1", [inv.group_id]);

      // Auto-generate first payout cycle
      const firstRecipient = await query('SELECT user_id FROM group_members WHERE group_id = $1 AND position = 1', [inv.group_id]);
      if (firstRecipient.rows.length) {
        const g = group.rows[0];
        const poolAmount = parseFloat(g.contribution_amount) * g.max_members;
        await query(
          'INSERT INTO payout_cycles (group_id, cycle_number, recipient_id, amount) VALUES ($1, 1, $2, $3) ON CONFLICT DO NOTHING',
          [inv.group_id, firstRecipient.rows[0].user_id, poolAmount]
        );
      }

      // Notify all members
      const members = await query('SELECT user_id FROM group_members WHERE group_id = $1', [inv.group_id]);
      const g = group.rows[0];
      for (const m of members.rows) {
        await query(
          `INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, 'group')`,
          [m.user_id, '🎉 Group is now active!', `${g.name} is ready! All members have joined. Contributions start now.`]
        );
      }
    }

    res.json({ message: 'Joined successfully!', group: group.rows[0] });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// MEMBER: Join via invite code (manual)
// ============================================
router.post('/join', auth, async (req, res) => {
  try {
    const { invite_code } = req.body;
    const groupResult = await query("SELECT * FROM groups WHERE invite_code = $1 AND approved = TRUE", [invite_code]);
    if (!groupResult.rows.length) return res.status(404).json({ message: 'Group not found or not approved' });

    const group = groupResult.rows[0];
    const memberCount = await query('SELECT COUNT(*) FROM group_members WHERE group_id = $1', [group.id]);
    if (parseInt(memberCount.rows[0].count) >= group.max_members)
      return res.status(400).json({ message: 'Group is full' });

    const existing = await query('SELECT id FROM group_members WHERE group_id = $1 AND user_id = $2', [group.id, req.user.id]);
    if (existing.rows.length) return res.status(400).json({ message: 'Already a member' });

    const position = parseInt(memberCount.rows[0].count) + 1;
    await query('INSERT INTO group_members (group_id, user_id, position) VALUES ($1, $2, $3)', [group.id, req.user.id, position]);

    // Activate group if full and generate rotation
    if (position >= group.max_members) {
      await query("UPDATE groups SET status = 'active' WHERE id = $1", [group.id]);

      // Auto-generate first payout cycle
      const firstRecipient = await query('SELECT user_id FROM group_members WHERE group_id = $1 AND position = 1', [group.id]);
      if (firstRecipient.rows.length) {
        const poolAmount = parseFloat(group.contribution_amount) * group.max_members;
        await query(
          'INSERT INTO payout_cycles (group_id, cycle_number, recipient_id, amount) VALUES ($1, 1, $2, $3)',
          [group.id, firstRecipient.rows[0].user_id, poolAmount]
        );
      }

      // Notify all members that group is active
      const members = await query('SELECT gm.user_id, u.name FROM group_members gm JOIN users u ON u.id = gm.user_id WHERE gm.group_id = $1', [group.id]);
      for (const m of members.rows) {
        await query(
          `INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, 'group')`,
          [m.user_id, '🎉 Group is now active!', `${group.name} is ready! All members have joined. Contributions start now.`]
        );
      }
    }

    res.json({ message: 'Joined successfully', group });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// Get my groups
// ============================================
router.get('/my-groups', auth, async (req, res) => {
  try {
    const result = await query(
      `SELECT g.*, gm.position,
        (SELECT COUNT(*) FROM group_members WHERE group_id = g.id) as member_count,
        (SELECT name FROM users WHERE id = g.admin_id) as admin_name
       FROM groups g
       JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
       ORDER BY g.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// Get group details with members
// ============================================
router.get('/:id', auth, async (req, res) => {
  try {
    const group = await query('SELECT * FROM groups WHERE id = $1', [req.params.id]);
    if (!group.rows.length) return res.status(404).json({ message: 'Group not found' });

    const members = await query(
      `SELECT gm.position, gm.status, u.id, u.name, u.phone
       FROM group_members gm JOIN users u ON u.id = gm.user_id
       WHERE gm.group_id = $1 ORDER BY gm.position`,
      [req.params.id]
    );

    const payouts = await query(
      `SELECT pc.*, u.name as recipient_name FROM payout_cycles pc
       LEFT JOIN users u ON u.id = pc.recipient_id
       WHERE pc.group_id = $1 ORDER BY pc.cycle_number`,
      [req.params.id]
    );

    // Include pending invites (members who haven't joined yet)
    const pendingInvites = await query(
      "SELECT name, phone, position, status FROM group_invites WHERE group_id = $1 AND status = 'pending' ORDER BY position",
      [req.params.id]
    );

    res.json({ ...group.rows[0], members: members.rows, payouts: payouts.rows, pending_invites: pendingInvites.rows });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// Get contribution tracker
// ============================================
router.get('/:id/tracker', auth, async (req, res) => {
  try {
    const cycle = req.query.cycle || 1;
    const result = await query(
      `SELECT gm.position, u.id as user_id, u.name, u.phone,
        COALESCE(c.status, 'pending') as payment_status, c.paid_at
       FROM group_members gm
       JOIN users u ON u.id = gm.user_id
       LEFT JOIN contributions c ON c.group_id = gm.group_id AND c.user_id = gm.user_id AND c.cycle_number = $2
       WHERE gm.group_id = $1
       ORDER BY gm.position`,
      [req.params.id, cycle]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// Advance rotation (group admin only)
// ============================================
router.post('/:id/rotate', auth, async (req, res) => {
  try {
    const group = await query('SELECT * FROM groups WHERE id = $1 AND admin_id = $2', [req.params.id, req.user.id]);
    if (!group.rows.length) return res.status(403).json({ message: 'Admin only' });

    const g = group.rows[0];
    const lastCycle = await query('SELECT MAX(cycle_number) as max FROM payout_cycles WHERE group_id = $1', [g.id]);
    const nextCycle = (parseInt(lastCycle.rows[0].max) || 0) + 1;

    const memberCount = await query('SELECT COUNT(*) FROM group_members WHERE group_id = $1', [g.id]);
    const position = ((nextCycle - 1) % parseInt(memberCount.rows[0].count)) + 1;
    const recipient = await query('SELECT user_id FROM group_members WHERE group_id = $1 AND position = $2', [g.id, position]);

    const payout_amount = g.contribution_amount * parseInt(memberCount.rows[0].count);
    await query(
      'INSERT INTO payout_cycles (group_id, cycle_number, recipient_id, amount, payout_date) VALUES ($1,$2,$3,$4,$5)',
      [g.id, nextCycle, recipient.rows[0].user_id, payout_amount, new Date()]
    );

    res.json({ message: 'Rotation advanced', cycle: nextCycle, recipient_position: position });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ============================================
// SUPER ADMIN: Get all groups
// ============================================
router.get('/admin/all', auth, async (req, res) => {
  try {
    if (req.user.role !== 'super_admin') return res.status(403).json({ message: 'Only Super Admin' });

    const result = await query(
      `SELECT g.*, u.name as admin_name,
        (SELECT COUNT(*) FROM group_members WHERE group_id = g.id) as member_count,
        (SELECT COUNT(*) FROM group_invites WHERE group_id = g.id) as invited_count
       FROM groups g JOIN users u ON u.id = g.admin_id
       ORDER BY g.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
