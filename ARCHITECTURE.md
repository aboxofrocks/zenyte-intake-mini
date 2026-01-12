# System Architecture

This document describes the technical architecture of Zenyte Intake Mini.

## High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        BROWSER (Client)                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    index.html                              │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │  │
│  │  │    HTML     │  │     CSS     │  │    JavaScript   │   │  │
│  │  │  (~6000     │  │  (~5000     │  │   (~17000       │   │  │
│  │  │   lines)    │  │   lines)    │  │    lines)       │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SUPABASE (Backend)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │    Auth     │  │   Storage   │  │      PostgreSQL         │  │
│  │  (email/    │  │  (documents │  │  ┌─────────────────┐   │  │
│  │   password) │  │   bucket)   │  │  │  Tables + RLS   │   │  │
│  └─────────────┘  └─────────────┘  │  │  Views          │   │  │
│                                     │  │  Functions      │   │  │
│                                     │  └─────────────────┘   │  │
│                                     └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Application Architecture

### Single-File Application

The entire frontend is contained in `index.html`:

```
index.html
├── <style> - All CSS (~5000 lines)
├── <body>  - All HTML structure (~6000 lines)
│   ├── Login Screen
│   ├── App Container
│   │   ├── Header (search, notifications, settings, user)
│   │   ├── Admin Panel
│   │   ├── Settings Panel (Audit Log)
│   │   ├── Dashboard
│   │   ├── Practice List
│   │   └── Practice Detail Panel
│   │       ├── Profile Tab
│   │       ├── Documents Tab
│   │       └── Financial Tab
│   └── Modals (extraction, evidence, DD packet preview)
└── <script> - All JavaScript (~17000 lines)
    ├── Supabase Client Init
    ├── Global State (db object)
    ├── Auth Functions
    ├── CRUD Operations
    ├── UI Rendering
    ├── Financial Module
    ├── DD Packet Generator
    └── Audit Log Functions
```

### State Management

The app uses a simple in-memory database object synced with Supabase:

```javascript
let db = {
  practices: [],      // All practices for current org
  people: [],         // People/contacts
  practice_people: [], // Join table
  locations: [],      // Practice locations
  notes: [],          // Practice notes
  events: [],         // Activity events
  metrics: [],        // Financial metrics (legacy)
  tasks: []           // Tasks/todos
};
```

**Data Flow:**
1. On login, data is loaded from Supabase → `db`
2. UI renders from `db`
3. User actions update Supabase first, then refresh `db`
4. Real-time subscriptions update `db` on external changes

### Authentication Flow

```
┌─────────┐     ┌──────────────┐     ┌─────────────┐
│  User   │────▶│ Login Screen │────▶│ Supabase    │
│         │     │              │     │ Auth        │
└─────────┘     └──────────────┘     └─────────────┘
                                            │
                      ┌─────────────────────┼─────────────────────┐
                      ▼                     ▼                     ▼
               ┌────────────┐       ┌─────────────┐       ┌──────────────┐
               │ No Org     │       │ Pending     │       │ Approved     │
               │ (create or │       │ Approval    │       │ (show app)   │
               │ request)   │       │ Screen      │       │              │
               └────────────┘       └─────────────┘       └──────────────┘
```

**User Roles:**
- `admin` - Full access, can manage users
- `editor` - Can create/edit practices
- `viewer` - Read-only access

---

## Financial Canonical Records System

The financial module uses a 5-layer architecture for evidence-backed financial data.

### Layer Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                                    │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐   │
│  │ Financial Profile │  │   DD Packet Gen  │  │  Document Upload UI      │   │
│  │ (live view)       │  │   (evidence-     │  │  (drag-drop + status)    │   │
│  │                   │  │    backed)       │  │                          │   │
│  └────────┬─────────┘  └────────┬─────────┘  └────────────┬─────────────┘   │
└───────────┼─────────────────────┼──────────────────────────┼────────────────┘
            │                     │                          │
            ▼                     ▼                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      LAYER 5: COMPUTED PROFILE                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  SQL Views / App-computed aggregations                                │   │
│  │  • v_practice_financial_profile (TTM, coverage, confidence, YoY)      │   │
│  │  • v_financial_facts_effective (canonical fact OR override)           │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       LAYER 4: OVERRIDES                                     │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  financial_overrides                                                  │   │
│  │  • Admin corrections that supersede canonical facts                   │   │
│  │  • Preserves audit trail (who, when, why)                             │   │
│  │  • Does NOT delete underlying evidence                                │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LAYER 3: CANONICAL FACTS                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  financial_facts                                                      │   │
│  │  • Normalized facts: (practice_id, period, fact_type, value)          │   │
│  │  • Linked to source: extraction_id, doc_id, page_num                  │   │
│  │  • Confidence score from extraction                                   │   │
│  │  • fact_type: monthly_revenue_bank_deposits, ending_balance, etc.     │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LAYER 2: EXTRACTIONS                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  financial_extractions                                                │   │
│  │  • Versioned extraction per document                                  │   │
│  │  • Raw JSON extraction result                                         │   │
│  │  • Model info (manual_entry, claude-3, etc.)                          │   │
│  │  • Status: pending / completed / failed                               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      LAYER 1: EVIDENCE (IMMUTABLE)                           │
│  ┌─────────────────────────────┐  ┌─────────────────────────────────────┐   │
│  │  Supabase Storage            │  │  financial_documents (Postgres)     │   │
│  │  (private bucket)            │  │  • Metadata row per uploaded file   │   │
│  │  • Actual PDF/image files    │  │  • file_hash (SHA-256) for dedup    │   │
│  │  • Immutable after upload    │  │  • processing_status for workflow   │   │
│  └─────────────────────────────┘  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow: Document Upload to Profile Display

```
1. UPLOAD: User uploads "Bank Statement March 2025.pdf"
      │
      ▼
2. EVIDENCE: File stored in Storage, metadata row created
      │
      ▼
3. EXTRACT: User clicks "Extract" → Manual entry modal opens
      │
      ▼
4. CANONICALIZE: User enters deposits/period → financial_facts rows created
      │
      ▼
5. DISPLAY: Financial Profile queries v_practice_financial_profile view
      │
      ▼
6. DD PACKET: Pulls canonical facts with evidence links
```

### Canonicalization Logic

When extraction is confirmed, the `canonicalizeExtraction()` function:

1. **Supersedes existing facts** for same practice/period
2. **Creates new facts** from extraction data:
   - `monthly_revenue_bank_deposits` - Total deposits
   - `monthly_ending_balance` - Ending balance
   - `monthly_beginning_balance` - Beginning balance
   - `monthly_withdrawals` - Total withdrawals
3. **Links to evidence** via `financial_document_id` and `extraction_id`
4. **Stores confidence score** from extraction

---

## Multi-Tenant Architecture

### Organization Scoping

All data is scoped to organizations:

```
┌─────────────────────────────────────────────┐
│              organizations                   │
│  ┌─────────────────────────────────────┐    │
│  │ id: uuid                             │    │
│  │ slug: "acme-corp"                    │    │
│  │ name: "Acme Corporation"             │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
         │
         │ org_id (FK)
         ▼
┌─────────────────────────────────────────────┐
│  practices, people, locations, documents,   │
│  events, financial_*, etc.                  │
│  All have org_id column                     │
└─────────────────────────────────────────────┘
```

### Row Level Security (RLS)

Every table has RLS policies using `get_my_org_id()`:

```sql
-- Example policy
CREATE POLICY "select_org" ON practices
    FOR SELECT TO authenticated
    USING (org_id = get_my_org_id());
```

This ensures users can only see data from their organization.

### User Roles

```
┌─────────────────────────────────────────────┐
│              user_organizations              │
│  ┌─────────────────────────────────────┐    │
│  │ user_id: uuid (auth.users)           │    │
│  │ org_id: uuid                         │    │
│  │ role: 'admin' | 'editor' | 'viewer'  │    │
│  │ status: 'active' | 'pending'         │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## Key Functions Reference

### Authentication
| Function | Description |
|----------|-------------|
| `handleLogin()` | Email/password sign in |
| `handleSignup()` | Create new account |
| `handleLogout()` | Sign out and clear state |
| `handleAuthenticatedUser()` | Process successful auth |

### Practice Management
| Function | Description |
|----------|-------------|
| `createPractice()` | Create new practice |
| `updatePractice()` | Update practice fields |
| `deletePractice()` | Soft delete practice |
| `selectPractice()` | Load practice into detail view |
| `renderPracticeList()` | Render practice sidebar |

### Financial Module
| Function | Description |
|----------|-------------|
| `handleFinancialDocUpload()` | Upload financial document |
| `extractFinancialDocument()` | Open extraction modal |
| `confirmExtraction()` | Save extraction and canonicalize |
| `canonicalizeExtraction()` | Create financial facts |
| `loadFinancialProfile()` | Load profile from view |
| `renderFinancialProfile()` | Display profile metrics |
| `fetchMonthlyBreakdown()` | Load monthly facts |

### DD Packet
| Function | Description |
|----------|-------------|
| `generateDDPacket()` | Generate full DD packet HTML |
| `openPacketPreview()` | Show packet in modal |
| `printPacket()` | Print/export packet |

### Audit Log (Admin)
| Function | Description |
|----------|-------------|
| `openSettings()` | Open settings panel |
| `loadAuditLog()` | Fetch events from both tables |
| `renderAuditLog()` | Display events table |
| `exportAuditLog()` | Export to CSV |

---

## Event System

### Practice Events (events table)

```javascript
logEvent({
  event_type: 'practice_created',
  practice_id: 'prc_abc123',
  actor_id: 'user@example.com',
  payload: { name: 'New Practice' }
});
```

**Event Types:**
- `practice_created`, `practice_edited`, `practice_deleted`
- `status_changed` (payload: `{old, new}`)
- `note_added`, `tag_added`, `tag_removed`
- `packet_generated`, `metric_added`, `owner_added`

### Document Events (document_events table)

```javascript
// Logged automatically on document actions
{
  event_type: 'uploaded',
  document_id: 'fdoc_xyz',
  document_type: 'financial',
  actor_email: 'user@example.com',
  payload: { file_name: 'statement.pdf' }
}
```

**Event Types:**
- `uploaded`, `deleted`
- `extraction_confirmed`
- `verified`, `unverified`

---

## Performance Considerations

### Indexes
Critical indexes for scale (5,000+ practices):
- `practices(status)` - Pipeline filtering
- `practices(org_id)` - Tenant isolation
- `metrics(practice_id, metric_type, period DESC)` - Time-series
- `events(practice_id, timestamp DESC)` - Audit queries
- `financial_facts(practice_id, fact_type, period)` - Financial queries

### Caching
- Practice list cached in `db.practices`
- Monthly facts cached in `cachedMonthlyFacts`
- Audit log data cached in `auditLogData`

### Pagination
- Audit log: 25 items per page
- Monthly breakdown: 6 months default, toggle for all

---

## Security Considerations

1. **Authentication** - All API calls require valid Supabase session
2. **Authorization** - RLS policies enforce org-scoped access
3. **Admin Functions** - Settings/Audit only visible to admin role
4. **File Upload** - Private storage bucket with signed URLs
5. **Input Sanitization** - `escapeHtml()` for user content display
