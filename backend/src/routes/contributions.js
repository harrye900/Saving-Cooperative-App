const router = require('express').Router();
const { query } = require('../config/database');
const { auth } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');

// Make contribution payment
router.post('/pay', auth, async (req, res) => {
  try {
    const { group_id, payment_method } = req.body;

    const group = await query('SELECT * FROM groups WHERE id = $1', [group_id]);
    if (!group.rows.length) return res.status(404).json({ message: 'Group not found' });
    const g = group.rows[0];

    const member = await query('SELECT * FROM group_members WHERE group_id = $1 AND user_id = $2', [group_id, req.user.id]);
    if (!member.rows.length) return res.status(403).json({ message: 'Not a member of this group' });

    // Get current cycle
    const cycleResult = await query('SELECT MAX(cycle_number) as max FROM payout_cycles WHERE group_id = $1', [group_id]);
    const currentCycle = parseInt(cycleResult.rows[0].max) || 1;

    // Check if already paid this cycle
    const existing = await query(
      "SELECT id FROM contributions WHERE group_id = $1 AND user_id = $2 AND cycle_number = $3 AND status = 'paid'",
      [group_id, req.user.id, currentCycle]
    );
    if (existing.rows.length) return res.status(400).json({ message: 'Already paid for this cycle' });

    // Deduct from wallet
    if (payment_method === 'wallet') {
      const wallet = await query('SELECT balance FROM wallets WHERE user_id = $1', [req.user.id]);
      if (parseFloat(wallet.rows[0].balance) < parseFloat(g.contribution_amount))
        return res.status(400).json({ message: 'Insufficient wallet balance' });

      await query('UPDATE wallets SET balance = balance - $1, updated_at = NOW() WHERE user_id = $2', [g.contribution_amount, req.user.id]);
    }

    // Record contribution
    const reference = `CON-${uuidv4().slice(0, 8).toUpperCase()}`;
    const contribution = await query(
      `INSERT INTO contributions (group_id, user_id, cycle_number, amount, status, payment_method, paid_at)
       VALUES ($1, $2, $3, $4, 'paid', $5, NOW()) RETURNING *`,
      [group_id, req.user.id, currentCycle, g.contribution_amount, payment_method || 'wallet']
    );

    // Record transaction
    await query(
      `INSERT INTO transactions (user_id, type, amount, reference, description, group_id)
       VALUES ($1, 'contribution', $2, $3, $4, $5)`,
      [req.user.id, g.contribution_amount, reference, `Contribution to ${g.name}`, group_id]
    );

    // Get payer's name
    const payer = await query('SELECT name FROM users WHERE id = $1', [req.user.id]);
    const payerName = payer.rows[0].name;

    // Notify ALL group members that this person paid
    const allMembers = await query('SELECT user_id FROM group_members WHERE group_id = $1 AND user_id != $2', [group_id, req.user.id]);
    for (const m of allMembers.rows) {
      await query(
        `INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, 'group')`,
        [m.user_id, `${payerName} has paid! ✓`, `${payerName} contributed ₦${parseFloat(g.contribution_amount).toLocaleString()} to ${g.name}`]
      );
    }

    // Check if ALL members have paid this cycle
    const totalMembers = await query('SELECT COUNT(*) FROM group_members WHERE group_id = $1', [group_id]);
    const totalPaid = await query(
      "SELECT COUNT(*) FROM contributions WHERE group_id = $1 AND cycle_number = $2 AND status = 'paid'",
      [group_id, currentCycle]
    );

    const memberCount = parseInt(totalMembers.rows[0].count);
    const paidCount = parseInt(totalPaid.rows[0].count);

    let payoutMessage = null;

    // If everyone has paid → auto-payout to the recipient
    if (paidCount >= memberCount) {
      const poolAmount = parseFloat(g.contribution_amount) * memberCount;

      // Get the recipient for this cycle
      const recipient = await query(
        'SELECT user_id FROM group_members WHERE group_id = $1 AND position = $2',
        [group_id, currentCycle]
      );

      if (recipient.rows.length) {
        const recipientId = recipient.rows[0].user_id;

        // Credit recipient's wallet
        await query('UPDATE wallets SET balance = balance + $1, updated_at = NOW() WHERE user_id = $2', [poolAmount, recipientId]);

        // Record payout transaction
        const payoutRef = `PAY-${uuidv4().slice(0, 8).toUpperCase()}`;
        await query(
          `INSERT INTO transactions (user_id, type, amount, reference, description, group_id)
           VALUES ($1, 'payout', $2, $3, $4, $5)`,
          [recipientId, poolAmount, payoutRef, `Payout from ${g.name}`, group_id]
        );

        // Update payout cycle status
        await query(
          "UPDATE payout_cycles SET status = 'completed', completed_at = NOW() WHERE group_id = $1 AND cycle_number = $2",
          [group_id, currentCycle]
        );

        // Get recipient name
        const recipientUser = await query('SELECT name FROM users WHERE id = $1', [recipientId]);
        const recipientName = recipientUser.rows[0].name;

        // Notify recipient
        await query(
          `INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, 'payout')`,
          [recipientId, '🎉 You received your payout!', `₦${poolAmount.toLocaleString()} has been sent to your wallet from ${g.name}`]
        );

        // Notify all other members
        const others = await query('SELECT user_id FROM group_members WHERE group_id = $1 AND user_id != $2', [group_id, recipientId]);
        for (const o of others.rows) {
          await query(
            `INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, 'payout')`,
            [o.user_id, 'Payout completed! 💰', `₦${poolAmount.toLocaleString()} has been sent to ${recipientName}. All members paid this cycle!`]
          );
        }

        // Create next cycle
        const nextCycle = currentCycle + 1;
        if (nextCycle <= memberCount) {
          const nextRecipient = await query('SELECT user_id FROM group_members WHERE group_id = $1 AND position = $2', [group_id, nextCycle]);
          if (nextRecipient.rows.length) {
            await query(
              'INSERT INTO payout_cycles (group_id, cycle_number, recipient_id, amount) VALUES ($1, $2, $3, $4)',
              [group_id, nextCycle, nextRecipient.rows[0].user_id, poolAmount]
            );
          }
        } else {
          // All cycles complete
          await query("UPDATE groups SET status = 'completed' WHERE id = $1", [group_id]);
        }

        payoutMessage = `All members paid! ₦${poolAmount.toLocaleString()} sent to ${recipientName}`;
      }
    }

    res.status(201).json({
      contribution: contribution.rows[0],
      reference,
      message: 'Payment successful ✓',
      pool_status: `${paidCount}/${memberCount} members paid`,
      payout: payoutMessage,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get group pool status (total collected this cycle)
router.get('/pool/:groupId', auth, async (req, res) => {
  try {
    const group = await query('SELECT * FROM groups WHERE id = $1', [req.params.groupId]);
    if (!group.rows.length) return res.status(404).json({ message: 'Group not found' });
    const g = group.rows[0];

    const cycleResult = await query('SELECT MAX(cycle_number) as max FROM payout_cycles WHERE group_id = $1', [req.params.groupId]);
    const currentCycle = parseInt(cycleResult.rows[0].max) || 1;

    const totalMembers = await query('SELECT COUNT(*) FROM group_members WHERE group_id = $1', [req.params.groupId]);
    const totalPaid = await query(
      "SELECT COUNT(*), COALESCE(SUM(amount), 0) as total_amount FROM contributions WHERE group_id = $1 AND cycle_number = $2 AND status = 'paid'",
      [req.params.groupId, currentCycle]
    );

    const memberCount = parseInt(totalMembers.rows[0].count);
    const paidCount = parseInt(totalPaid.rows[0].count);
    const poolAmount = parseFloat(totalPaid.rows[0].total_amount);
    const targetAmount = parseFloat(g.contribution_amount) * memberCount;

    // Who is receiving this cycle
    const recipient = await query(
      `SELECT u.name, u.phone, gm.position FROM group_members gm
       JOIN users u ON u.id = gm.user_id
       WHERE gm.group_id = $1 AND gm.position = $2`,
      [req.params.groupId, currentCycle]
    );

    res.json({
      current_cycle: currentCycle,
      total_members: memberCount,
      members_paid: paidCount,
      members_pending: memberCount - paidCount,
      pool_collected: poolAmount,
      pool_target: targetAmount,
      progress_percent: Math.round((paidCount / memberCount) * 100),
      recipient: recipient.rows[0] || null,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get my contributions
router.get('/mine', auth, async (req, res) => {
  try {
    const result = await query(
      `SELECT c.*, g.name as group_name, g.type as group_type
       FROM contributions c JOIN groups g ON g.id = c.group_id
       WHERE c.user_id = $1 ORDER BY c.created_at DESC LIMIT 50`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Get group contribution tracker (who paid, pending, overdue)
router.get('/group/:groupId', auth, async (req, res) => {
  try {
    const cycleResult = await query('SELECT MAX(cycle_number) as max FROM payout_cycles WHERE group_id = $1', [req.params.groupId]);
    const currentCycle = parseInt(cycleResult.rows[0].max) || 1;
    const cycle = req.query.cycle || currentCycle;

    const result = await query(
      `SELECT gm.position, u.id as user_id, u.name, u.phone,
        COALESCE(c.status, 'pending') as payment_status, c.paid_at
       FROM group_members gm
       JOIN users u ON u.id = gm.user_id
       LEFT JOIN contributions c ON c.group_id = gm.group_id AND c.user_id = gm.user_id AND c.cycle_number = $2
       WHERE gm.group_id = $1
       ORDER BY gm.position`,
      [req.params.groupId, cycle]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
