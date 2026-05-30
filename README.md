# 🤝 AjoSave - Digital Cooperative Savings & Loan Platform

A mobile-first cooperative savings and loan management platform for Nigeria that digitizes traditional ajo/esusu/cooperative systems.

## Who It's For
- Savings groups & Cooperative societies
- Market associations & Church groups
- Friends & family contribution circles
- SME cooperatives

## Core Features (MVP)
- ✅ Authentication (phone number + PIN)
- ✅ Group creation (Ajo, Thrift, Cooperative)
- ✅ Contribution tracking with status (Paid/Pending/Overdue)
- ✅ Rotational payout system
- ✅ Loan management (request, approve, repay)
- ✅ Wallet (fund, withdraw, transaction history)
- ✅ Automated reminders (daily cron)
- ✅ Notifications
- ✅ Invite via code

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (mobile-first) |
| Backend | Node.js + Express |
| Database | PostgreSQL |
| Auth | JWT + bcrypt + PIN |
| Payments | Paystack (ready to integrate) |
| Notifications | FCM (ready to integrate) |
| Scheduling | node-cron |

## Project Structure

```
├── backend/
│   ├── src/
│   │   ├── config/       # DB connection & migrations
│   │   ├── middleware/   # Auth middleware
│   │   ├── routes/       # API endpoints
│   │   ├── services/     # Reminders, notifications
│   │   └── server.js     # Entry point
│   └── package.json
├── flutter_app/
│   ├── lib/
│   │   ├── screens/      # All app screens
│   │   ├── services/     # API & Auth services
│   │   ├── models/       # Data models
│   │   ├── widgets/      # Reusable widgets
│   │   └── main.dart     # Entry point
│   └── pubspec.yaml
└── README.md
```

## Setup

### Backend
```bash
cd backend
npm install
# Create PostgreSQL database named 'ajosave'
cp .env.example .env  # Edit with your DB credentials
npm run db:migrate    # Create tables
npm run dev           # Start server on :5000
```

### Flutter App
```bash
cd flutter_app
flutter pub get
flutter run
```

## API Endpoints

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/auth/register | Register with phone |
| POST | /api/auth/login | Login |
| POST | /api/auth/set-pin | Set 4-digit PIN |
| GET | /api/auth/profile | Get profile |

### Groups
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/groups | Create group |
| POST | /api/groups/join | Join via invite code |
| GET | /api/groups/my-groups | My groups |
| GET | /api/groups/:id | Group details + members |
| GET | /api/groups/:id/tracker | Contribution tracker |
| POST | /api/groups/:id/rotate | Advance rotation |

### Contributions
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/contributions/pay | Make payment |
| GET | /api/contributions/mine | My contributions |
| GET | /api/contributions/group/:id | Group tracker |

### Loans
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/loans/request | Request loan |
| POST | /api/loans/:id/approve | Approve (admin) |
| POST | /api/loans/:id/repay | Repay loan |
| GET | /api/loans/mine | My loans |

### Wallet
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/wallet/balance | Get balance |
| POST | /api/wallet/fund | Fund wallet |
| POST | /api/wallet/withdraw | Withdraw to bank |
| GET | /api/wallet/transactions | Transaction history |

## Design System
- **Primary**: Emerald Green (#10B981)
- **Secondary**: Gold (#F59E0B)
- **Success**: Green (#22C55E)
- **Danger**: Red (#EF4444)
- **Font**: Inter
- **Style**: Rounded cards, soft shadows, large readable text

## Phase 2 Roadmap
- [ ] Paystack/Flutterwave payment integration
- [ ] SMS notifications (Termii)
- [ ] OTP verification
- [ ] KYC/BVN verification
- [ ] Group chat
- [ ] AI repayment prediction
- [ ] Credit scoring
- [ ] WhatsApp chatbot
- [ ] Local language support
- [ ] Admin analytics dashboard
