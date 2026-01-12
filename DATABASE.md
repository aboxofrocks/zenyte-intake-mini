# Database Schema Documentation

This document provides a complete reference for the Zenyte Intake Mini database schema.

## Overview

The database is hosted on Supabase (PostgreSQL) and consists of:
- **Core Tables** - Practice management entities
- **Financial Tables** - Canonical financial records system
- **Auth Tables** - Multi-tenant user management
- **Views** - Computed aggregations

## Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│  organizations  │       │     users       │       │user_organizations│
│─────────────────│       │ (Supabase Auth) │       │─────────────────│
│ id (PK)         │◄──────│                 │──────▶│ user_id (FK)    │
│ slug            │       │                 │       │ org_id (FK)     │
│ name            │       │                 │       │ role            │
└────────┬────────┘       └─────────────────┘       │ status          │
         │                                          └─────────────────┘
         │ org_id
         ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   practices     │◄──────│ practice_people │──────▶│     people      │
│─────────────────│       │─────────────────│       │─────────────────│
│ id (PK)         │       │ id (PK)         │       │ id (PK)         │
│ org_id (FK)     │       │ practice_id(FK) │       │ first_name      │
│ status          │       │ person_id (FK)  │       │ last_name       │
│ specialty       │       │ role            │       │ email           │
│ legal_name      │       │ ownership_pct   │       │ phone           │
└────────┬────────┘       └─────────────────┘       └─────────────────┘
         │
         │ practice_id
         ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   locations     │  │     notes       │  │    documents    │  │     events      │
│─────────────────│  │─────────────────│  │─────────────────│  │─────────────────│
│ id (PK)         │  │ id (PK)         │  │ id (PK)         │  │ id (PK)         │
│ practice_id(FK) │  │ practice_id(FK) │  │ practice_id(FK) │  │ practice_id(FK) │
│ name            │  │ content         │  │ category        │  │ event_type      │
│ address         │  │ author_id       │  │ name            │  │ actor_id        │
│ is_primary      │  │ is_pinned       │  │ status          │  │ payload (JSONB) │
└─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘
```

## Core Tables

### practices

The main entity representing a healthcare practice.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `prc_xxxxxxxx` |
| `internal_uuid` | UUID | System identifier |
| `org_id` | UUID (FK) | Organization |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update |
| `status` | ENUM | Lead, Onboarding, Active, Exited, Archived |
| `specialty` | TEXT | Medical specialty |
| `legal_name` | TEXT | Legal entity name |
| `dba_name` | TEXT | Doing business as |
| `ownership_structure` | ENUM | Solo, Partnership, Group, etc. |
| `primary_location_id` | TEXT (FK) | Primary location reference |
| `onboarding_state` | JSONB | Checklist state |
| `risk_flags` | JSONB | Computed risk indicators |

**Extended Fields (stored in practices):**
- Operations: `num_providers`, `num_staff`, `num_patients`, `emr_system`, `practice_management_system`
- Payer Mix: `payer_mix_medicare_pct`, `payer_mix_medicaid_pct`, `payer_mix_commercial_pct`, etc.
- Real Estate: `real_estate_status`, `lease_remaining_years`, `monthly_rent`
- Legal: `pending_litigation`, `outstanding_liens`, `prior_bankruptcy`
- Deal Terms: `asking_price`, `deal_structure_preference`, `seller_financing_available`

### people

Contacts, owners, and staff associated with practices.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `per_xxxxxxxx` |
| `internal_uuid` | UUID | System identifier |
| `first_name` | TEXT | First name |
| `last_name` | TEXT | Last name |
| `email` | TEXT | Email address |
| `phone` | TEXT | Phone number |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update |

### practice_people

Join table linking people to practices with roles.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `pp_xxxxxxxx` |
| `practice_id` | TEXT (FK) | Practice reference |
| `person_id` | TEXT (FK) | Person reference |
| `role` | ENUM | owner, physician, admin, billing, etc. |
| `is_primary` | BOOLEAN | Primary contact flag |
| `ownership_pct` | NUMERIC(5,2) | Ownership percentage (0-100) |

### locations

Physical locations for practices.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `loc_xxxxxxxx` |
| `practice_id` | TEXT (FK) | Parent practice |
| `name` | TEXT | Location name |
| `address1` | TEXT | Street address |
| `address2` | TEXT | Suite/unit |
| `city` | TEXT | City |
| `state` | TEXT | State code |
| `zip` | TEXT | ZIP code |
| `phone` | TEXT | Location phone |
| `fax` | TEXT | Fax number |
| `is_primary` | BOOLEAN | Primary location flag |
| `services` | TEXT[] | Services offered |

### notes

Practice notes and comments.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `not_xxxxxxxx` |
| `practice_id` | TEXT (FK) | Parent practice |
| `author_id` | TEXT | Note author |
| `content` | TEXT | Note content |
| `is_pinned` | BOOLEAN | Pinned to top |
| `created_at` | TIMESTAMPTZ | Creation timestamp |

### documents

General document metadata.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `doc_xxxxxxxx` |
| `practice_id` | TEXT (FK) | Parent practice |
| `category` | ENUM | financial, contract, license, etc. |
| `name` | TEXT | Document name |
| `description` | TEXT | Description |
| `url` | TEXT | Storage URL |
| `file_type` | TEXT | MIME type |
| `status` | ENUM | pending, received, reviewed, approved |
| `expires_at` | TIMESTAMPTZ | Expiration date |

### events

Audit log for practice-level events.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `evt_xxxxxxxx` |
| `practice_id` | TEXT (FK) | Associated practice |
| `org_id` | UUID (FK) | Organization |
| `event_type` | TEXT | Type of event |
| `actor_id` | TEXT | User who performed action |
| `timestamp` | TIMESTAMPTZ | Event timestamp |
| `payload` | JSONB | Event-specific data |

---

## Financial Tables

### financial_documents

Uploaded financial documents (evidence layer).

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `fdoc_xxxxxxxx` |
| `org_id` | UUID (FK) | Organization |
| `practice_id` | TEXT (FK) | Parent practice |
| `file_name` | TEXT | Original filename |
| `file_type` | TEXT | MIME type |
| `file_size_bytes` | BIGINT | File size |
| `file_hash` | TEXT | SHA-256 hash (dedup) |
| `storage_bucket` | TEXT | Storage bucket name |
| `storage_path` | TEXT | Path in bucket |
| `document_type` | TEXT | bank_statement, income_statement, etc. |
| `document_subtype` | TEXT | checking, savings, etc. |
| `period_start` | DATE | Statement start date |
| `period_end` | DATE | Statement end date |
| `processing_status` | TEXT | uploaded, queued, processing, completed, failed |
| `uploaded_by_id` | UUID | Uploader user ID |
| `uploaded_at` | TIMESTAMPTZ | Upload timestamp |
| `is_deleted` | BOOLEAN | Soft delete flag |

### financial_extractions

Extraction records from documents.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `fext_xxxxxxxx` |
| `org_id` | UUID (FK) | Organization |
| `practice_id` | TEXT (FK) | Practice |
| `financial_document_id` | TEXT (FK) | Source document |
| `status` | TEXT | pending, completed, failed |
| `extraction_json` | JSONB | Raw extraction data |
| `model_name` | TEXT | manual_entry, claude-3, etc. |
| `model_version` | TEXT | Model version |
| `overall_confidence` | NUMERIC(3,2) | 0.00 to 1.00 |
| `is_canonicalized` | BOOLEAN | Facts created flag |
| `canonicalized_at` | TIMESTAMPTZ | When canonicalized |
| `created_at` | TIMESTAMPTZ | Creation timestamp |

### financial_facts

Canonical financial facts (normalized data).

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `ffact_xxxxxxxx` |
| `org_id` | UUID (FK) | Organization |
| `practice_id` | TEXT (FK) | Practice |
| `financial_document_id` | TEXT (FK) | Source document |
| `financial_extraction_id` | TEXT (FK) | Source extraction |
| `fact_type` | TEXT | monthly_revenue_bank_deposits, etc. |
| `period_start` | DATE | Period start (1st of month) |
| `period_end` | DATE | Period end (last of month) |
| `value_numeric` | NUMERIC | Numeric value |
| `currency_code` | TEXT | USD |
| `confidence` | NUMERIC(3,2) | Confidence score |
| `source_page` | INTEGER | Page in document |
| `source_text` | TEXT | Relevant snippet |
| `source_path` | TEXT | JSON path in extraction |
| `is_current` | BOOLEAN | Latest version flag |
| `superseded_by_fact_id` | TEXT | Replacement fact |
| `superseded_at` | TIMESTAMPTZ | When superseded |

**Fact Types:**
- `monthly_revenue_bank_deposits` - Total deposits for month
- `monthly_ending_balance` - Ending balance
- `monthly_beginning_balance` - Beginning balance
- `monthly_withdrawals` - Total withdrawals

### financial_overrides

Admin corrections to canonical facts.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Format: `fover_xxxxxxxx` |
| `org_id` | UUID (FK) | Organization |
| `practice_id` | TEXT (FK) | Practice |
| `fact_type` | TEXT | Fact type being overridden |
| `period_start` | DATE | Period start |
| `period_end` | DATE | Period end |
| `value_numeric` | NUMERIC | Override value |
| `reason` | TEXT | Reason for override (required) |
| `is_active` | BOOLEAN | Active override flag |
| `created_by` | UUID | Admin user ID |
| `revoked_at` | TIMESTAMPTZ | If revoked |
| `revoked_reason` | TEXT | Revocation reason |

### document_events

Audit log for document-specific events.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Event ID |
| `org_id` | UUID (FK) | Organization |
| `practice_id` | TEXT (FK) | Practice |
| `document_id` | TEXT | Document ID |
| `document_type` | TEXT | financial, dd_corporate, etc. |
| `event_type` | TEXT | uploaded, deleted, extraction_confirmed, etc. |
| `actor_user_id` | TEXT | User ID |
| `actor_email` | TEXT | User email |
| `payload` | JSONB | Event data |
| `created_at` | TIMESTAMPTZ | Event timestamp |

---

## Views

### v_financial_facts_effective

Returns canonical facts with overrides applied.

```sql
SELECT
    practice_id,
    fact_type,
    to_char(period_start, 'YYYY-MM') AS period,
    COALESCE(override.value_numeric, fact.value_numeric) AS value,
    CASE WHEN override.id IS NOT NULL THEN TRUE ELSE FALSE END AS is_override,
    confidence,
    document_id,
    extraction_id
FROM financial_facts fact
LEFT JOIN financial_overrides override ON ...
WHERE fact.is_current = TRUE;
```

### v_practice_financial_profile

Aggregated financial profile for a practice.

| Column | Description |
|--------|-------------|
| `practice_id` | Practice identifier |
| `months_covered` | Number of months with data |
| `earliest_period` | First period (YYYY-MM) |
| `latest_period` | Last period (YYYY-MM) |
| `coverage_score` | % of last 36 months covered |
| `confidence_score` | Average confidence (0-100) |
| `all_time_deposits` | Sum of all deposits ever |
| `avg_monthly_deposits` | Average monthly deposits |
| `trailing_12m_revenue` | TTM revenue |
| `ttm_months_with_data` | Months with data in TTM window |
| `ttm_start` | TTM window start (YYYY-MM) |
| `ttm_end` | TTM window end (YYYY-MM) |
| `yoy_growth_pct` | Year-over-year growth % |

---

## Auth Tables

### organizations

Multi-tenant organizations.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Organization ID |
| `slug` | TEXT (unique) | URL-friendly identifier |
| `name` | TEXT | Display name |
| `created_at` | TIMESTAMPTZ | Creation timestamp |

### user_organizations

User membership in organizations.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Record ID |
| `user_id` | UUID (FK) | Supabase auth.users |
| `org_id` | UUID (FK) | Organization |
| `role` | TEXT | admin, editor, viewer |
| `status` | TEXT | active, pending |
| `created_at` | TIMESTAMPTZ | Join timestamp |

### email_allowlist

Pre-approved email domains/addresses.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Record ID |
| `org_id` | UUID (FK) | Organization |
| `email_pattern` | TEXT | Email or @domain.com |
| `created_by` | UUID | Admin who added |
| `created_at` | TIMESTAMPTZ | Creation timestamp |

---

## ID Conventions

All entities use prefixed IDs for type safety:

| Prefix | Entity |
|--------|--------|
| `prc_` | Practices |
| `per_` | People |
| `pp_` | Practice-People joins |
| `loc_` | Locations |
| `not_` | Notes |
| `doc_` | Documents |
| `evt_` | Events |
| `met_` | Metrics |
| `fdoc_` | Financial Documents |
| `fext_` | Financial Extractions |
| `ffact_` | Financial Facts |
| `fover_` | Financial Overrides |

IDs are generated using:
```javascript
function generateId(prefix) {
  return prefix + '_' + Math.random().toString(36).substring(2, 10);
}
```

---

## Row Level Security

All tables have RLS enabled with org-scoped policies:

```sql
-- Helper function
CREATE FUNCTION get_my_org_id() RETURNS UUID AS $$
  SELECT org_id FROM user_organizations
  WHERE user_id = auth.uid() AND status = 'active'
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Example policy
CREATE POLICY "select_own_org" ON practices
  FOR SELECT TO authenticated
  USING (org_id = get_my_org_id());
```

---

## Indexes

### Critical Performance Indexes

```sql
-- Practice queries
CREATE INDEX idx_practices_org ON practices(org_id);
CREATE INDEX idx_practices_status ON practices(status);

-- Time-series queries
CREATE INDEX idx_financial_facts_practice_period
  ON financial_facts(practice_id, fact_type, period_start DESC);

-- Audit queries
CREATE INDEX idx_events_practice_timestamp
  ON events(practice_id, timestamp DESC);
CREATE INDEX idx_document_events_created
  ON document_events(created_at DESC);
```

---

## Migration Notes

### Import Order (respect foreign keys)

1. `organizations`
2. `practices` (no FK dependencies)
3. `people` (no FK dependencies)
4. `locations` (depends on practices)
5. UPDATE `practices.primary_location_id`
6. `practice_people` (depends on practices, people)
7. `notes`, `documents`, `events` (depend on practices)
8. `financial_documents` (depends on practices)
9. `financial_extractions` (depends on financial_documents)
10. `financial_facts` (depends on extractions)
