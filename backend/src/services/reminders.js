const { query } = require('../config/database');

async function sendReminders() {
  try {
    // Get active groups
    const groups = await query("SELECT * FROM groups WHERE status = 'active'");

    for (const group of groups.rows) {
      const today = new Date();
      const shouldRemind =
        group.frequency === 'daily' ||
        (group.frequency === 'weekly' && today.getDay() === 1) ||
        (group.frequency === 'monthly' && today.getDate() === 1);

      if (!shouldRemind) continue;

      const lastCycle = await query('SELECT MAX(cycle_number) as max FROM payout_cycles WHERE group_id = $1', [group.id]);
      const currentCycle = parseInt(lastCycle.rows[0].max) || 1;

      // Find members who haven't paid
      const unpaid = await query(
        `SELECT gm.user_id, u.name FROM group_members gm
         JOIN users u ON u.id = gm.user_id
         WHERE gm.group_id = $1 AND gm.user_id NOT IN (
           SELECT user_id FROM contributions WHERE group_id = $1 AND cycle_number = $2 AND status = 'paid'
         )`,
        [group.id, currentCycle]
      );

      for (const member of unpaid.rows) {
        await query(
          `INSERT INTO notifications (user_id, title, message, type)
           VALUES ($1, $2, $3, 'reminder')`,
          [
            member.user_id,
            'Contribution Reminder 👋',
            `Hi ${member.name}! Your ₦${group.contribution_amount.toLocaleString()} contribution for ${group.name} is due. Pay now to stay on track!`
          ]
        );
      }
    }

    // Loan repayment reminders
    const dueSoonLoans = await query(
      `SELECT l.*, u.name, g.name as group_name FROM loans l
       JOIN users u ON u.id = l.borrower_id
       JOIN groups g ON g.id = l.group_id
       WHERE l.status = 'active' AND l.due_date <= NOW() + INTERVAL '3 days'`
    );

    for (const loan of dueSoonLoans.rows) {
      await query(
        `INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, 'loan')`,
        [loan.borrower_id, 'Loan Repayment Due Soon', `Your loan repayment of ₦${loan.total_repayment.toLocaleString()} for ${loan.group_name} is due soon. Please make your payment.`]
      );
    }

    // Mark overdue contributions
    await query(
      `UPDATE contributions SET status = 'overdue'
       WHERE status = 'pending' AND due_date < NOW()`
    );

    console.log(`[${new Date().toISOString()}] Reminders sent`);
  } catch (err) {
    console.error('Reminder error:', err.message);
  }
}

module.exports = { sendReminders };
