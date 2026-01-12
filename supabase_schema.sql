-- ============================================================
-- ZENYTE INTAKE - SUPABASE SCHEMA (Production Ready)
-- Generated from canonical localStorage schema (Practice v1)
-- Version: 1.1 - Portfolio/M&A semantics, internal UUIDs
-- ============================================================

-- Drop existing tables (for clean re-runs)
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS notes CASCADE;
DROP TABLE IF EXISTS metrics CASCADE;
DROP TABLE IF EXISTS practice_people CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS people CASCADE;
DROP TABLE IF EXISTS practices CASCADE;

-- Drop existing types
DROP TYPE IF EXISTS practice_status CASCADE;
DROP TYPE IF EXISTS ownership_structure CASCADE;
DROP TYPE IF EXISTS person_role CASCADE;
DROP TYPE IF EXISTS document_category CASCADE;
DROP TYPE IF EXISTS document_status CASCADE;

-- ============================================================
-- ENUM TYPES
-- ============================================================

-- Practice status reflects portfolio/M&A lifecycle (not SaaS churn)
CREATE TYPE practice_status AS ENUM ('Lead', 'Onboarding', 'Active', 'Exited', 'Archived');
CREATE TYPE ownership_structure AS ENUM ('Solo', 'Partnership', 'Group', 'PE-Backed', 'Hospital-Owned', 'Unknown');
CREATE TYPE person_role AS ENUM ('owner', 'physician', 'admin', 'billing', 'manager', 'nurse', 'other');
CREATE TYPE document_category AS ENUM ('financial', 'contract', 'license', 'insurance', 'corporate', 'compliance', 'other');
CREATE TYPE document_status AS ENUM ('pending', 'received', 'reviewed', 'approved');

-- ============================================================
-- PRACTICES (Core Entity)
-- ============================================================

CREATE TABLE practices (
    -- Primary identifier (human-readable, type-safe)
    id TEXT PRIMARY KEY,  -- Format: prc_xxxxxxxx

    -- Internal UUID for future microservices/system joins
    internal_uuid UUID NOT NULL DEFAULT gen_random_uuid(),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_to TEXT,

    -- Practice info
    status practice_status NOT NULL DEFAULT 'Lead',
    specialty TEXT NOT NULL DEFAULT '',
    legal_name TEXT NOT NULL DEFAULT '',
    dba_name TEXT NOT NULL DEFAULT '',
    ownership_structure ownership_structure NOT NULL DEFAULT 'Unknown',

    -- Reference to primary location (nullable, set after location created)
    primary_location_id TEXT,

    -- Structured JSON fields
    onboarding_state JSONB DEFAULT '{"checklist_version": "v1", "items": [], "last_reviewed_at": null}'::jsonb,
    risk_flags JSONB DEFAULT '{"missing_fields": [], "aging_flags": [], "computed_at": null}'::jsonb,

    -- Schema version
    data_version TEXT NOT NULL DEFAULT '1.0',

    -- Constraints
    CONSTRAINT practices_id_format CHECK (id ~ '^prc_[a-z0-9]+$'),
    CONSTRAINT practices_internal_uuid_unique UNIQUE (internal_uuid)
);

-- Indexes for practices
CREATE INDEX idx_practices_status ON practices(status);
CREATE INDEX idx_practices_specialty ON practices(specialty);
CREATE INDEX idx_practices_created_at ON practices(created_at DESC);
CREATE INDEX idx_practices_updated_at ON practices(updated_at DESC);
CREATE INDEX idx_practices_internal_uuid ON practices(internal_uuid);

-- ============================================================
-- PEOPLE (Owners, Contacts, Staff)
-- ============================================================

CREATE TABLE people (
    -- Primary identifier (human-readable, type-safe)
    id TEXT PRIMARY KEY,  -- Format: per_xxxxxxxx

    -- Internal UUID for future microservices/system joins
    internal_uuid UUID NOT NULL DEFAULT gen_random_uuid(),

    -- Person info
    first_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    email TEXT DEFAULT '',
    phone TEXT DEFAULT '',

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT people_id_format CHECK (id ~ '^per_[a-z0-9]+$'),
    CONSTRAINT people_internal_uuid_unique UNIQUE (internal_uuid)
);

-- Indexes for people
CREATE INDEX idx_people_email ON people(email) WHERE email != '';
CREATE INDEX idx_people_name ON people(last_name, first_name);
CREATE INDEX idx_people_internal_uuid ON people(internal_uuid);

-- ============================================================
-- PRACTICE_PEOPLE (Join Table - Many-to-Many)
-- ============================================================

CREATE TABLE practice_people (
    -- Primary identifier (human-readable, type-safe)
    id TEXT PRIMARY KEY,  -- Format: pp_xxxxxxxx

    -- Internal UUID for future microservices/system joins
    internal_uuid UUID NOT NULL DEFAULT gen_random_uuid(),

    -- Foreign keys
    practice_id TEXT NOT NULL REFERENCES practices(id) ON DELETE CASCADE,
    person_id TEXT NOT NULL REFERENCES people(id) ON DELETE CASCADE,

    -- Role info
    role person_role NOT NULL DEFAULT 'other',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    ownership_pct NUMERIC(5,2) CHECK (ownership_pct IS NULL OR (ownership_pct >= 0 AND ownership_pct <= 100)),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT practice_people_id_format CHECK (id ~ '^pp_[a-z0-9]+$'),
    CONSTRAINT practice_people_internal_uuid_unique UNIQUE (internal_uuid),
    CONSTRAINT practice_people_unique UNIQUE (practice_id, person_id, role)
);

-- Indexes for practice_people
CREATE INDEX idx_practice_people_practice ON practice_people(practice_id);
CREATE INDEX idx_practice_people_person ON practice_people(person_id);
CREATE INDEX idx_practice_people_role_primary ON practice_people(practice_id, role, is_primary);
CREATE INDEX idx_practice_people_internal_uuid ON practice_people(internal_uuid);

-- ============================================================
-- LOCATIONS (Multi-location Support)
-- ============================================================

CREATE TABLE locations (
    -- Primary identifier (human-readable, type-safe)
    id TEXT PRIMARY KEY,  -- Format: loc_xxxxxxxx

    -- Internal UUID for future microservices/system joins
    internal_uuid UUID NOT NULL DEFAULT gen_random_uuid(),

    -- Foreign key
    practice_id TEXT NOT NULL REFERENCES practices(id) ON DELETE CASCADE,

    -- Location info
    name TEXT NOT NULL DEFAULT '',
    address1 TEXT DEFAULT '',
    address2 TEXT DEFAULT '',
    city TEXT DEFAULT '',
    state TEXT DEFAULT '',
    zip TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    fax TEXT DEFAULT '',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    services TEXT[] DEFAULT '{}',

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT locations_id_format CHECK (id ~ '^loc_[a-z0-9]+$'),
    CONSTRAINT locations_internal_uuid_unique UNIQUE (internal_uuid)
);

-- Indexes for locations
CREATE INDEX idx_locations_practice ON locations(practice_id);
CREATE INDEX idx_locations_practice_primary ON locations(practice_id, is_primary);
CREATE INDEX idx_locations_state ON locations(state) WHERE state != '';
CREATE INDEX idx_locations_internal_uuid ON locations(internal_uuid);

-- Add FK from practices to locations (after locations table exists)
ALTER TABLE practices
    ADD CONSTRAINT fk_practices_primary_location
    FOREIGN KEY (primary_location_id) REFERENCES locations(id) ON DELETE SET NULL;

-- ============================================================
-- METRICS (Time-Series Financial/Operational Data)
-- ============================================================

CREATE TABLE metrics (
    -- Primary identifier (human-readable, type-safe)
    id TEXT PRIMARY KEY,  -- Format: met_xxxxxxxx

    -- Internal UUID for future microservices/system joins
    internal_uuid UUID NOT NULL DEFAULT gen_random_uuid(),

    -- Foreign keys
    practice_id TEXT NOT NULL REFERENCES practices(id) ON DELETE CASCADE,
    location_id TEXT REFERENCES locations(id) ON DELETE SET NULL,

    -- Metric data
    period TEXT NOT NULL,  -- Format: YYYY-MM
    metric_type TEXT NOT NULL,  -- e.g., 'monthly_revenue', 'collections', 'ar_30', etc.
    value NUMERIC NOT NULL,
    source TEXT NOT NULL DEFAULT 'manual',

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT metrics_id_format CHECK (id ~ '^met_[a-z0-9]+$'),
    CONSTRAINT metrics_internal_uuid_unique UNIQUE (internal_uuid),
    CONSTRAINT metrics_period_format CHECK (period ~ '^\d{4}-\d{2}$')
);

-- Indexes for metrics (critical for time-series queries)
CREATE INDEX idx_metrics_practice_type_period ON metrics(practice_id, metric_type, period DESC);
CREATE INDEX idx_metrics_period ON metrics(period DESC);
CREATE INDEX idx_metrics_metric_type ON metrics(metric_type);
CREATE INDEX idx_metrics_internal_uuid ON metrics(internal_uuid);

-- ============================================================
-- NOTES (Practice Notes/Comments)
-- ============================================================

CREATE TABLE notes (
    -- Primary identifier (human-readable, type-safe)
    id TEXT PRIMARY KEY,  -- Format: not_xxxxxxxx

    -- Internal UUID for future microservices/system joins
    internal_uuid UUID NOT NULL DEFAULT gen_random_uuid(),

    -- Foreign key
    practice_id TEXT NOT NULL REFERENCES practices(id) ON DELETE CASCADE,

    -- Note data
    author_id TEXT,  -- Could reference people or be 'system'
    content TEXT NOT NULL DEFAULT '',
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT notes_id_format CHECK (id ~ '^not_[a-z0-9]+$'),
    CONSTRAINT notes_internal_uuid_unique UNIQUE (internal_uuid)
);

-- Indexes for notes
CREATE INDEX idx_notes_practice ON notes(practice_id);
CREATE INDEX idx_notes_practice_pinned ON notes(practice_id, is_pinned DESC, created_at DESC);
CREATE INDEX idx_notes_internal_uuid ON notes(internal_uuid);

-- ============================================================
-- DOCUMENTS (Document Metadata & Tracking)
-- ============================================================

CREATE TABLE documents (
    -- Primary identifier (human-readable, type-safe)
    id TEXT PRIMARY KEY,  -- Format: doc_xxxxxxxx

    -- Internal UUID for future microservices/system joins
    internal_uuid UUID NOT NULL DEFAULT gen_random_uuid(),

    -- Foreign key
    practice_id TEXT NOT NULL REFERENCES practices(id) ON DELETE CASCADE,

    -- Document metadata
    category document_category NOT NULL DEFAULT 'other',
    name TEXT NOT NULL DEFAULT '',
    description TEXT DEFAULT '',
    url TEXT DEFAULT '',
    file_type TEXT DEFAULT '',
    uploaded_by_id TEXT,
    expires_at TIMESTAMPTZ,
    status document_status NOT NULL DEFAULT 'pending',

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT documents_id_format CHECK (id ~ '^doc_[a-z0-9]+$'),
    CONSTRAINT documents_internal_uuid_unique UNIQUE (internal_uuid)
);

-- Indexes for documents
CREATE INDEX idx_documents_practice ON documents(practice_id);
CREATE INDEX idx_documents_category ON documents(practice_id, category);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_expires ON documents(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_documents_internal_uuid ON documents(internal_uuid);

-- ============================================================
-- EVENTS (Audit Log / Activity Trail)
-- ============================================================

CREATE TABLE events (
    -- Primary identifier (human-readable, type-safe)
    id TEXT PRIMARY KEY,  -- Format: evt_xxxxxxxx

    -- Internal UUID for future microservices/system joins
    internal_uuid UUID NOT NULL DEFAULT gen_random_uuid(),

    -- Foreign key (nullable for system-level events)
    practice_id TEXT REFERENCES practices(id) ON DELETE CASCADE,

    -- Event data
    event_type TEXT NOT NULL,
    actor_id TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payload JSONB DEFAULT '{}'::jsonb,

    -- Constraints
    CONSTRAINT events_id_format CHECK (id ~ '^evt_[a-z0-9]+$'),
    CONSTRAINT events_internal_uuid_unique UNIQUE (internal_uuid)
);

-- Indexes for events (critical for audit queries)
CREATE INDEX idx_events_practice_timestamp ON events(practice_id, timestamp DESC);
CREATE INDEX idx_events_timestamp ON events(timestamp DESC);
CREATE INDEX idx_events_event_type ON events(event_type);
CREATE INDEX idx_events_actor ON events(actor_id) WHERE actor_id IS NOT NULL;
CREATE INDEX idx_events_internal_uuid ON events(internal_uuid);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER trigger_practices_updated_at
    BEFORE UPDATE ON practices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_people_updated_at
    BEFORE UPDATE ON people
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_locations_updated_at
    BEFORE UPDATE ON locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_notes_updated_at
    BEFORE UPDATE ON notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY (RLS) - Enable for Supabase
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE practices ENABLE ROW LEVEL SECURITY;
ALTER TABLE people ENABLE ROW LEVEL SECURITY;
ALTER TABLE practice_people ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Default policies (allow all for authenticated users - customize as needed)
-- In production, you'd want more restrictive policies based on user roles

CREATE POLICY "Allow all for authenticated users" ON practices
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON people
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON practice_people
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON locations
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON metrics
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON notes
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON documents
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users" ON events
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- IMPORT MAPPING (localStorage → Postgres)
-- ============================================================
/*
SCHEMA VERSION: 1.1 (Production Ready)

ENUM VALUES:
  practice_status: 'Lead', 'Onboarding', 'Active', 'Exited', 'Archived'
    - 'Exited' = practice sold/divested (replaces 'Churned')
    - 'Archived' = historical record, no longer active in portfolio

Each localStorage table maps directly to a Postgres table:

  localStorage.zenyte_db.practices    → INSERT INTO practices (...)
  localStorage.zenyte_db.people       → INSERT INTO people (...)
  localStorage.zenyte_db.practice_people → INSERT INTO practice_people (...)
  localStorage.zenyte_db.locations    → INSERT INTO locations (...)
  localStorage.zenyte_db.metrics      → INSERT INTO metrics (...)
  localStorage.zenyte_db.notes        → INSERT INTO notes (...)
  localStorage.zenyte_db.documents    → INSERT INTO documents (...)
  localStorage.zenyte_db.events       → INSERT INTO events (...)

Field mappings (all 1:1 since we use canonical snake_case):

  practices:
    id → id (TEXT, PK)
    (internal_uuid auto-generated by Postgres)
    created_at → created_at (TIMESTAMPTZ, parse ISO string)
    updated_at → updated_at (TIMESTAMPTZ)
    status → status (cast to practice_status enum)
      NOTE: Map 'Churned' → 'Exited' during import
    specialty → specialty (TEXT)
    legal_name → legal_name (TEXT)
    dba_name → dba_name (TEXT)
    ownership_structure → ownership_structure (cast to enum)
    primary_location_id → primary_location_id (TEXT, nullable)
    onboarding_state → onboarding_state (JSONB)
    risk_flags → risk_flags (JSONB)
    data_version → data_version (TEXT)

  people:
    id → id
    (internal_uuid auto-generated)
    first_name → first_name
    last_name → last_name
    email → email
    phone → phone
    created_at → created_at
    updated_at → updated_at

  practice_people:
    id → id
    (internal_uuid auto-generated)
    practice_id → practice_id (FK)
    person_id → person_id (FK)
    role → role (cast to person_role enum)
    is_primary → is_primary
    ownership_pct → ownership_pct
    created_at → created_at

  locations:
    id → id
    (internal_uuid auto-generated)
    practice_id → practice_id (FK)
    name → name
    address1, address2, city, state, zip → same
    phone, fax → same
    is_primary → is_primary
    services → services (TEXT[], parse JSON array)
    created_at, updated_at → same

  metrics:
    id → id
    (internal_uuid auto-generated)
    practice_id → practice_id (FK)
    location_id → location_id (FK, nullable)
    period → period (TEXT, YYYY-MM)
    metric_type → metric_type (TEXT)
      NOTE: Column is 'metric_type', NOT 'type'
    value → value (NUMERIC)
    source → source
    created_at → created_at

  notes:
    id → id
    (internal_uuid auto-generated)
    practice_id → practice_id (FK)
    author_id → author_id
    content → content
    is_pinned → is_pinned
    created_at, updated_at → same

  documents:
    id → id
    (internal_uuid auto-generated)
    practice_id → practice_id (FK)
    category → category (cast to enum)
    name, description, url, file_type → same
    uploaded_by_id → uploaded_by_id
    expires_at → expires_at (TIMESTAMPTZ, nullable)
    status → status (cast to enum)
    created_at, updated_at → same

  events:
    id → id
    (internal_uuid auto-generated)
    practice_id → practice_id (FK, nullable)
    event_type → event_type
    actor_id → actor_id
    timestamp → timestamp (TIMESTAMPTZ)
    payload → payload (JSONB)

IMPORT ORDER (respect foreign keys):
  1. practices (no dependencies)
  2. people (no dependencies)
  3. locations (depends on practices)
  4. UPDATE practices SET primary_location_id (now locations exist)
  5. practice_people (depends on practices, people)
  6. metrics (depends on practices, locations)
  7. notes (depends on practices)
  8. documents (depends on practices)
  9. events (depends on practices)

EXAMPLE IMPORT (JavaScript → Supabase):

  // Map 'Churned' to 'Exited' for M&A semantics
  const mapStatus = (s) => s === 'Churned' ? 'Exited' : s;

  const { data, error } = await supabase
    .from('practices')
    .insert(localDb.practices.map(p => ({
      id: p.id,
      created_at: p.created_at,
      updated_at: p.updated_at,
      status: mapStatus(p.status),
      specialty: p.specialty,
      legal_name: p.legal_name,
      dba_name: p.dba_name,
      ownership_structure: p.ownership_structure,
      onboarding_state: p.onboarding_state,
      risk_flags: p.risk_flags,
      data_version: p.data_version
      // Note: internal_uuid auto-generated, primary_location_id set later
    })));

CASCADING DELETES:
  - Deleting a practice cascades to: locations, practice_people, metrics, notes, documents, events
  - Deleting a person cascades to: practice_people
  - Deleting a location sets metrics.location_id to NULL, practices.primary_location_id to NULL

INDEXES FOR SCALE (5,000+ practices):
  - practices(status) - filter by pipeline stage
  - practices(specialty) - filter by practice type
  - practices(created_at DESC) - sort by newest
  - metrics(practice_id, metric_type, period DESC) - time-series queries
  - events(practice_id, timestamp DESC) - audit log queries
  - locations(practice_id, is_primary) - find primary location
  - practice_people(practice_id, role, is_primary) - find primary owner

*/
