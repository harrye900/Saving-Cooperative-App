-- Run this in Supabase SQL Editor to add invite system
-- AjoSave - Group Invite & Approval System

-- Table to store invited members before they register
CREATE TABLE IF NOT EXISTS group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(15) NOT NULL,
  email VARCHAR(100),
  position INT NOT NULL,
  invite_token VARCHAR(50) UNIQUE NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired')),
  sms_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Add approval fields to groups table
ALTER TABLE groups ADD COLUMN IF NOT EXISTS approved BOOLEAN DEFAULT FALSE;
ALTER TABLE groups ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id);
ALTER TABLE groups ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP;

-- Update status check to include 'pending_approval'
ALTER TABLE groups DROP CONSTRAINT IF EXISTS groups_status_check;
ALTER TABLE groups ADD CONSTRAINT groups_status_check CHECK (status IN ('pending_approval', 'pending', 'active', 'completed', 'paused'));

-- Update default status to pending_approval
ALTER TABLE groups ALTER COLUMN status SET DEFAULT 'pending_approval';

-- Index for fast invite lookups
CREATE INDEX IF NOT EXISTS idx_group_invites_phone ON group_invites(phone);
CREATE INDEX IF NOT EXISTS idx_group_invites_token ON group_invites(invite_token);
