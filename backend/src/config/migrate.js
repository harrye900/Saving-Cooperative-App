require('dotenv').config();
const { pool } = require('./database');
const fs = require('fs');
const path = require('path');

const migrate = async () => {
  const client = await pool.connect();
  try {
    // Try to use the SQL file first
    const schemaPath = path.join(__dirname, '../../supabase_schema.sql');
    if (fs.existsSync(schemaPath)) {
      const sql = fs.readFileSync(schemaPath, 'utf8');
      await client.query(sql);
      console.log('Migration completed from supabase_schema.sql');
      client.release();
      process.exit();
      return;
    }

    await client.query('BEGIN');

    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(100) NOT NULL,
        phone VARCHAR(15) UNIQUE NOT NULL,
        email VARCHAR(100) UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        pin_hash VARCHAR(255),
        role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('member', 'admin', 'super_admin')),
        profile_picture TEXT,
        kyc_verified BOOLEAN DEFAULT FALSE,
        fcm_token TEXT,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS bank_accounts (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        bank_name VARCHAR(100) NOT NULL,
        account_number VARCHAR(20) NOT NULL,
        account_name VARCHAR(100) NOT NULL,
        is_default BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS wallets (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
        balance DECIMAL(15,2) DEFAULT 0.00,
        updated_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS groups (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(100) NOT NULL,
        description TEXT,
        type VARCHAR(20) NOT NULL CHECK (type IN ('ajo', 'thrift', 'cooperative')),
        admin_id UUID REFERENCES users(id),
        contribution_amount DECIMAL(15,2) NOT NULL,
        frequency VARCHAR(10) NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly')),
        max_members INT NOT NULL,
        penalty_amount DECIMAL(15,2) DEFAULT 0,
        interest_rate DECIMAL(5,2) DEFAULT 5.00,
        start_date DATE NOT NULL,
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed', 'paused')),
        invite_code VARCHAR(10) UNIQUE,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS group_members (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        position INT NOT NULL,
        status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'removed', 'pending')),
        joined_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(group_id, user_id),
        UNIQUE(group_id, position)
      );

      CREATE TABLE IF NOT EXISTS payout_cycles (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
        cycle_number INT NOT NULL,
        recipient_id UUID REFERENCES users(id),
        amount DECIMAL(15,2) NOT NULL,
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'skipped')),
        payout_date DATE,
        completed_at TIMESTAMP,
        UNIQUE(group_id, cycle_number)
      );

      CREATE TABLE IF NOT EXISTS contributions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id),
        cycle_number INT NOT NULL,
        amount DECIMAL(15,2) NOT NULL,
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('paid', 'pending', 'overdue')),
        payment_method VARCHAR(20),
        paid_at TIMESTAMP,
        due_date DATE,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS loans (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        borrower_id UUID REFERENCES users(id),
        group_id UUID REFERENCES groups(id),
        amount DECIMAL(15,2) NOT NULL,
        interest_rate DECIMAL(5,2) NOT NULL,
        total_repayment DECIMAL(15,2) NOT NULL,
        amount_paid DECIMAL(15,2) DEFAULT 0,
        duration_months INT NOT NULL,
        reason TEXT,
        guarantor_id UUID REFERENCES users(id),
        status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'active', 'completed', 'rejected', 'overdue')),
        due_date DATE,
        approved_by UUID REFERENCES users(id),
        approved_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS transactions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id),
        type VARCHAR(30) NOT NULL CHECK (type IN ('contribution', 'payout', 'loan_disbursement', 'loan_repayment', 'wallet_fund', 'withdrawal', 'penalty')),
        amount DECIMAL(15,2) NOT NULL,
        reference VARCHAR(50) UNIQUE,
        description TEXT,
        group_id UUID REFERENCES groups(id),
        status VARCHAR(20) DEFAULT 'completed',
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS notifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(200) NOT NULL,
        message TEXT NOT NULL,
        type VARCHAR(30) CHECK (type IN ('reminder', 'payout', 'loan', 'group', 'system')),
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_contributions_group ON contributions(group_id, cycle_number);
      CREATE INDEX IF NOT EXISTS idx_contributions_user ON contributions(user_id);
      CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id);
      CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);
      CREATE INDEX IF NOT EXISTS idx_group_members ON group_members(group_id, user_id);
    `);

    await client.query('COMMIT');
    console.log('Migration completed successfully');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Migration failed:', err);
  } finally {
    client.release();
    process.exit();
  }
};

migrate();
