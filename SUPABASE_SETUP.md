# Supabase Setup Guide for AjoSave

## Step 1: Create Supabase Project

1. Go to https://supabase.com and sign up/login
2. Click "New Project"
3. Choose your organization
4. Enter:
   - **Name**: `ajosave`
   - **Database Password**: (save this! you'll need it)
   - **Region**: Choose closest to Nigeria (e.g. EU West or US East)
5. Click "Create new project" and wait ~2 minutes

## Step 2: Get Your Credentials

Go to **Project Settings > API** and copy:

- **Project URL** → `SUPABASE_URL` in `.env`
- **anon public key** → `SUPABASE_ANON_KEY` in `.env`
- **service_role key** → `SUPABASE_SERVICE_KEY` in `.env`

Go to **Project Settings > Database** and copy:

- **Connection string (URI)** → `DATABASE_URL` in `.env`
  - Replace `[YOUR-PASSWORD]` with your database password

## Step 3: Create Tables

1. Go to **SQL Editor** in Supabase Dashboard
2. Click "New Query"
3. Copy and paste the entire contents of `supabase_schema.sql`
4. Click "Run"
5. You should see all tables created in the **Table Editor**

## Step 4: Update Your .env File

```env
PORT=5000
SUPABASE_URL=https://abcdefghijk.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...
DATABASE_URL=postgresql://postgres.abcdefghijk:YourPassword@aws-0-eu-west-2.pooler.supabase.com:6543/postgres
JWT_SECRET=your_own_secret_key
JWT_EXPIRES_IN=30d
```

## Step 5: Update Flutter App

In `flutter_app/lib/main.dart`, replace:
```dart
await Supabase.initialize(
  url: 'https://your-project-id.supabase.co',  // Your Supabase URL
  anonKey: 'your-anon-key',                     // Your anon key
);
```

## Step 6: Run the App

```bash
cd backend
npm install
npm run dev
```

## Viewing Data in Supabase

Once the app is running and users register:

1. Go to **Table Editor** in Supabase Dashboard
2. Click on any table (users, groups, contributions, etc.)
3. You'll see all data in real-time!

### What you can see:
- **users** → All registered users with phone, name, role
- **wallets** → Each user's wallet balance
- **groups** → All ajo/thrift/cooperative groups
- **group_members** → Who belongs to which group
- **contributions** → Every payment (paid/pending/overdue)
- **loans** → All loan requests and their status
- **transactions** → Complete financial history with receipts
- **notifications** → All reminders sent

## Supabase Dashboard Features You Get Free:

- ✅ View/edit/filter all table data
- ✅ Real-time data updates
- ✅ SQL editor for custom queries
- ✅ Built-in auth (optional, we use our own JWT)
- ✅ Storage for profile pictures
- ✅ Edge functions
- ✅ Database backups
- ✅ 500MB database (free tier)
- ✅ 50,000 monthly active users (free tier)
