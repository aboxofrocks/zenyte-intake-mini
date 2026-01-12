-- PART 1: TABLES ONLY
-- Run this first

-- Drop existing tables that might conflict
DROP TABLE IF EXISTS dd_checklist_item_documents CASCADE;
DROP TABLE IF EXISTS practice_claimed_attributes CASCADE;
DROP TABLE IF EXISTS dd_extraction_alerts CASCADE;
DROP TABLE IF EXISTS dd_document_extractions CASCADE;
DROP TABLE IF EXISTS document_templates CASCADE;
DROP TABLE IF EXISTS document_types CASCADE;

-- Drop views that might reference old schemas
DROP VIEW IF EXISTS v_active_alerts CASCADE;
DROP VIEW IF EXISTS v_current_extractions CASCADE;
DROP VIEW IF EXISTS v_practice_attributes CASCADE;
DROP VIEW IF EXISTS v_checklist_progress CASCADE;

-- 1. Document Types
CREATE TABLE document_types (
    code TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    category TEXT NOT NULL,
    extraction_schema JSONB,
    filename_patterns TEXT[],
    alert_fields TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO document_types (code, label, category, filename_patterns, alert_fields) VALUES
    ('medical_license', 'Medical License', 'corporate', ARRAY['license', 'medical.*lic'], ARRAY['expiration_date']),
    ('dea_certificate', 'DEA Certificate', 'compliance', ARRAY['dea'], ARRAY['expiration_date']),
    ('malpractice_insurance', 'Malpractice Insurance', 'compliance', ARRAY['malpractice', 'liability.*ins'], ARRAY['expiration_date']),
    ('lease_agreement', 'Lease Agreement', 'contracts', ARRAY['lease'], ARRAY['lease_end_date']),
    ('tax_return', 'Tax Return', 'financial', ARRAY['tax.*return', '1120', '1065'], NULL),
    ('bank_statement', 'Bank Statement', 'financial', ARRAY['bank.*statement'], NULL),
    ('business_license', 'Business License', 'corporate', ARRAY['business.*lic'], ARRAY['expiration_date']),
    ('board_certification', 'Board Certification', 'corporate', ARRAY['board.*cert'], ARRAY['expiration_date']),
    ('w9_form', 'W-9 Form', 'corporate', ARRAY['w-?9'], NULL),
    ('org_chart', 'Organization Chart', 'corporate', ARRAY['org.*chart'], NULL),
    ('hipaa_policy', 'HIPAA Policy', 'compliance', ARRAY['hipaa'], NULL),
    ('pnl_statement', 'P&L Statement', 'financial', ARRAY['p.*l', 'profit.*loss'], NULL),
    ('balance_sheet', 'Balance Sheet', 'financial', ARRAY['balance.*sheet'], NULL),
    ('insurance_coi', 'Certificate of Insurance', 'compliance', ARRAY['coi', 'certificate.*insurance'], ARRAY['expiration_date']);

-- 2. Document Extractions
CREATE TABLE dd_document_extractions (
    id TEXT PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    practice_id TEXT NOT NULL REFERENCES practices(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    document_table TEXT NOT NULL DEFAULT 'documents',
    doc_type_code TEXT REFERENCES document_types(code),
    doc_type_confidence NUMERIC(3,2),
    status TEXT NOT NULL DEFAULT 'pending',
    extraction_json JSONB,
    model_name TEXT,
    model_version TEXT,
    overall_confidence NUMERIC(3,2),
    error_message TEXT,
    source_pages INTEGER[],
    confirmed_at TIMESTAMPTZ,
    confirmed_by TEXT,
    edits_made JSONB,
    written_to_practice BOOLEAN DEFAULT FALSE,
    written_fields JSONB,
    version INTEGER NOT NULL DEFAULT 1,
    supersedes_extraction_id TEXT,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Extraction Alerts
CREATE TABLE dd_extraction_alerts (
    id TEXT PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    practice_id TEXT NOT NULL REFERENCES practices(id) ON DELETE CASCADE,
    extraction_id TEXT NOT NULL REFERENCES dd_document_extractions(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    alert_type TEXT NOT NULL,
    alert_date DATE NOT NULL,
    days_until INTEGER,
    field_name TEXT,
    field_value TEXT,
    description TEXT,
    doc_type_code TEXT REFERENCES document_types(code),
    doc_name TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Document Templates
CREATE TABLE document_templates (
    id TEXT PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    items JSONB NOT NULL DEFAULT '[]',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    usage_count INTEGER NOT NULL DEFAULT 0,
    created_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Checklist Item Documents (checklist_item_id is TEXT to match dd_checklist_items.id)
CREATE TABLE dd_checklist_item_documents (
    id TEXT PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    checklist_item_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    document_table TEXT NOT NULL DEFAULT 'documents',
    extraction_id TEXT REFERENCES dd_document_extractions(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    verified_at TIMESTAMPTZ,
    verified_by TEXT,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Practice Claimed Attributes
CREATE TABLE practice_claimed_attributes (
    id TEXT PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    practice_id TEXT NOT NULL REFERENCES practices(id) ON DELETE CASCADE,
    attribute_key TEXT NOT NULL,
    attribute_value TEXT,
    value_type TEXT DEFAULT 'text',
    source_type TEXT NOT NULL,
    source_extraction_id TEXT REFERENCES dd_document_extractions(id) ON DELETE SET NULL,
    source_document_id TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    verified_by TEXT,
    is_current BOOLEAN DEFAULT TRUE,
    superseded_by TEXT,
    superseded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by TEXT
);

-- Done with Part 1
SELECT 'Part 1 complete - tables created' as status;
