# Zenyte Intake Mini

A comprehensive practice intake and due diligence management system for healthcare M&A operations. Built as a single-page application with Supabase backend.

## Overview

Zenyte Intake Mini helps M&A teams manage the intake process for healthcare practices, including:
- Practice information management (44+ fields)
- Financial document collection and extraction
- Due diligence packet generation
- Document tracking and compliance
- Multi-tenant organization support

## Features

### Practice Management
- **44+ practice fields** covering operations, payer mix, technology, real estate, legal, and deal terms
- **Status tracking**: Lead → Onboarding → Active → Exited → Archived
- **Multi-location support** with primary location designation
- **Owner/contact management** with roles and ownership percentages
- **Notes and activity timeline**

### Financial Module
- **Document upload** with drag-drop support (PDF, images, Excel, CSV)
- **Manual extraction flow** for bank statements
- **Financial Profile UI** showing:
  - Coverage bars (X/36 months)
  - Confidence scores
  - TTM (Trailing Twelve Month) revenue
  - Historical data and YoY growth
  - Monthly breakdown table
- **Canonical Financial Records System** - 5-layer evidence chain for audit trail

### Due Diligence
- **DD Packet Generator** - 6-page PDF-ready report:
  1. Practice Overview
  2. Practice Details & Operations
  3. Payer Mix, Technology, Real Estate
  4. Legal, Deal Terms, Quality & Market
  5. Financials (evidence-backed)
  6. Timeline & Activity
- **DD Checklist** with phase-based items
- **Document Hub** with categorized tabs (Financial, Corporate, Compliance, Contracts)

### Data Import
- **Bulk Lead Import** - Import 2000+ leads from CSV, Excel, or Google Sheets
- **Smart Column Mapping** - Auto-detects 100+ column name variations
- **Fuzzy Matching** - Handles messy headers like "# of Docs", "Physician Count"
- **Data Normalization** - Cleans messy data automatically:
  - Booleans: "Yes/Y/1/TRUE" → true
  - Numbers: "$1.5M", "25%", "1,500" → proper numbers
  - Dates: Various formats → ISO dates
  - Status/Ownership: Normalizes to valid enum values
- **Duplicate Detection** - Checks against existing practices before import
- **First/Last Name Support** - Combines into practice name for contact-style data
- **Progress Tracking** - Real-time progress bar for large imports

### Admin Features
- **User access management** with role-based permissions
- **Organization-scoped data** with Row Level Security
- **Audit Log Viewer** (admin only) - browse all practice and document events
- **Email allowlist** for access control
- **Document Templates** - Create reusable document request packages

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Vanilla HTML/CSS/JavaScript (single file) |
| Backend | Supabase (PostgreSQL + Auth + Storage) |
| Authentication | Supabase Auth (email/password) |
| Database | PostgreSQL with RLS |
| Storage | Supabase Storage (for documents) |

## Project Structure

```
zenyte-intake-mini/
├── index.html          # Main application (HTML + CSS + JS)
├── supabase_schema.sql # Core database schema
├── ROADMAP.md          # Feature roadmap and progress
├── ARCHITECTURE.md     # System architecture documentation
├── DATABASE.md         # Database schema documentation
├── CONTRIBUTING.md     # Development guidelines
└── README.md           # This file
```

## Quick Start

### Prerequisites
- Supabase account (free tier works)
- Modern web browser

### Setup

1. **Create Supabase Project**
   - Go to [supabase.com](https://supabase.com) and create a new project
   - Note your project URL and anon key

2. **Run Database Schema**
   - Go to SQL Editor in Supabase dashboard
   - Run `supabase_schema.sql` to create core tables
   - Run the Financial Records schema (see DATABASE.md)

3. **Configure the App**
   - Open `index.html`
   - Find the Supabase configuration section (~line 7650)
   - Replace with your project credentials:
   ```javascript
   const SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
   const SUPABASE_ANON_KEY = 'your-anon-key';
   ```

4. **Enable Authentication**
   - In Supabase dashboard, go to Authentication → Providers
   - Enable Email provider
   - Configure email templates as needed

5. **Create Storage Bucket**
   - Go to Storage in Supabase dashboard
   - Create a bucket called `financial-documents` (private)

6. **Run Locally**
   - Simply open `index.html` in a browser
   - Or use a local server: `python -m http.server 8000`

### First Login

1. Sign up with email/password
2. You'll be the first user in your org (auto-admin)
3. Add practices and start managing intake

## Environment Configuration

The app uses these Supabase configuration variables (in `index.html`):

```javascript
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = 'your-anon-public-key';
```

For production, you should:
- Enable email verification
- Set up proper RLS policies
- Configure CORS if hosting separately

## Deployment

### Option 1: Vercel (Recommended)
1. Push to GitHub
2. Import project in Vercel
3. Deploy (no build step needed)

### Option 2: Netlify
1. Push to GitHub
2. Connect repo in Netlify
3. Deploy with default settings

### Option 3: GitHub Pages
1. Go to repo Settings → Pages
2. Set source to main branch
3. Access at `username.github.io/repo-name`

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design, data flows, financial records system
- **[DATABASE.md](DATABASE.md)** - Complete schema reference
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Development guidelines
- **[ROADMAP.md](ROADMAP.md)** - Feature progress and plans

## Key Concepts

### Multi-Tenant Architecture
- All data is scoped to organizations via `org_id`
- Row Level Security (RLS) enforces data isolation
- Users are assigned roles: `admin`, `editor`, `viewer`

### Financial Canonical Records
A 5-layer system for evidence-backed financial data:
1. **Evidence Layer** - Immutable uploaded documents
2. **Extraction Layer** - AI/manual extracted data with confidence scores
3. **Canonical Facts Layer** - Normalized financial facts
4. **Overrides Layer** - Admin corrections with audit trail
5. **Computed Profile Layer** - Aggregated views for display

### ID Conventions
All entities use prefixed IDs for type safety:
- `prc_` - Practices
- `per_` - People
- `loc_` - Locations
- `doc_` - Documents
- `evt_` - Events
- `fdoc_` - Financial Documents
- `ffact_` - Financial Facts

## License

Proprietary - Zenyte Holdings

## Support

For issues or questions, contact the development team or create an issue in the repository.
