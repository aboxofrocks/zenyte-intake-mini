-- ============================================================
-- ZENYTE INTAKE - FEATURE 8 & 9 SCHEMA (FIX VERSION)
-- Drops and recreates document_types with correct schema
-- ============================================================

-- Drop existing document_types if it has wrong schema
DROP TABLE IF EXISTS document_types CASCADE;

-- ============================================================
-- DOCUMENT TYPES REFERENCE TABLE
-- ============================================================

CREATE TABLE document_types (
    code TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    category TEXT NOT NULL,
    extraction_schema JSONB,
    filename_patterns TEXT[],
    alert_fields TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed document types
INSERT INTO document_types (code, label, category, filename_patterns, alert_fields) VALUES
    ('medical_license', 'Medical License', 'corporate',
     ARRAY['license', 'medical.*lic', 'md.*lic', 'do.*lic', 'physician.*lic'],
     ARRAY['expiration_date']),
    ('dea_certificate', 'DEA Certificate', 'compliance',
     ARRAY['dea', 'drug.*enforce', 'controlled.*substance'],
     ARRAY['expiration_date']),
    ('malpractice_insurance', 'Malpractice Insurance', 'compliance',
     ARRAY['malpractice', 'liability.*ins', 'prof.*liability', 'medical.*liability'],
     ARRAY['expiration_date']),
    ('lease_agreement', 'Lease Agreement', 'contracts',
     ARRAY['lease', 'rental.*agree', 'property.*agree', 'commercial.*lease'],
     ARRAY['lease_end_date']),
    ('tax_return', 'Tax Return', 'financial',
     ARRAY['tax.*return', '1120', '1065', 'schedule.*c', 'form.*1040'],
     NULL),
    ('bank_statement', 'Bank Statement', 'financial',
     ARRAY['bank.*statement', 'account.*statement', 'checking.*statement'],
     NULL),
    ('business_license', 'Business License', 'corporate',
     ARRAY['business.*lic', 'operating.*permit', 'city.*license'],
     ARRAY['expiration_date']),
    ('board_certification', 'Board Certification', 'corporate',
     ARRAY['board.*cert', 'specialty.*cert', 'abms', 'aobp'],
     ARRAY['expiration_date']),
    ('w9_form', 'W-9 Form', 'corporate',
     ARRAY['w-?9', 'tax.*id.*form', 'taxpayer.*id'],
     NULL),
    ('org_chart', 'Organization Chart', 'corporate',
     ARRAY['org.*chart', 'organization.*chart', 'corporate.*structure'],
     NULL),
    ('hipaa_policy', 'HIPAA Policy', 'compliance',
     ARRAY['hipaa', 'privacy.*policy', 'phi.*policy'],
     NULL),
    ('pnl_statement', 'P&L Statement', 'financial',
     ARRAY['p.*l', 'profit.*loss', 'income.*statement'],
     NULL),
    ('balance_sheet', 'Balance Sheet', 'financial',
     ARRAY['balance.*sheet', 'assets.*liabilities', 'financial.*position'],
     NULL),
    ('insurance_coi', 'Certificate of Insurance', 'compliance',
     ARRAY['certificate.*insurance', 'coi', 'proof.*insurance'],
     ARRAY['expiration_date']),
    ('npi_confirmation', 'NPI Confirmation', 'corporate',
     ARRAY['npi', 'national.*provider'],
     NULL),
    ('state_incorporation', 'State Incorporation', 'corporate',
     ARRAY['incorporat', 'articles.*org', 'certificate.*formation'],
     NULL),
    ('provider_agreement', 'Provider Agreement', 'contracts',
     ARRAY['provider.*agree', 'physician.*employ', 'employment.*agree'],
     ARRAY['expiration_date']),
    ('payor_contract', 'Payor Contract', 'contracts',
     ARRAY['payor.*contract', 'payer.*agree', 'insurance.*contract', 'managed.*care'],
     ARRAY['expiration_date']);


-- ============================================================
-- DOCUMENT EXTRACTIONS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS dd_document_extractions (
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
    supersedes_extraction_id TEXT REFERENCES dd_document_extractions(id),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ddx_org ON dd_document_extractions(org_id);
CREATE INDEX IF NOT EXISTS idx_ddx_practice ON dd_document_extractions(practice_id);
CREATE INDEX IF NOT EXISTS idx_ddx_document ON dd_document_extractions(document_id);
CREATE INDEX IF NOT EXISTS idx_ddx_status ON dd_document_extractions(status);
CREATE INDEX IF NOT EXISTS idx_ddx_doc_type ON dd_document_extractions(doc_type_code);
CREATE INDEX IF NOT EXISTS idx_ddx_current ON dd_document_extractions(is_current) WHERE is_current = TRUE;
CREATE INDEX IF NOT EXISTS idx_ddx_created ON dd_document_extractions(created_at DESC);


-- ============================================================
-- EXTRACTION ALERTS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS dd_extraction_alerts (
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

CREATE INDEX IF NOT EXISTS idx_alerts_org ON dd_extraction_alerts(org_id);
CREATE INDEX IF NOT EXISTS idx_alerts_practice ON dd_extraction_alerts(practice_id);
CREATE INDEX IF NOT EXISTS idx_alerts_date ON dd_extraction_alerts(alert_date);
CREATE INDEX IF NOT EXISTS idx_alerts_status_active ON dd_extraction_alerts(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_alerts_org_active ON dd_extraction_alerts(org_id, status, alert_date) WHERE status = 'active';


-- ============================================================
-- DOCUMENT TEMPLATES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS document_templates (
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

CREATE INDEX IF NOT EXISTS idx_templates_org ON document_templates(org_id);
CREATE INDEX IF NOT EXISTS idx_templates_active ON document_templates(org_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_templates_category ON document_templates(category);


-- ============================================================
-- EXTEND DD_CHECKLIST_ITEMS
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'template_id') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN template_id TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'doc_type_code') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN doc_type_code TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'item_key') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN item_key TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'description') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN description TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'due_date') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN due_date DATE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'status') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN status TEXT DEFAULT 'required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'rejection_reason') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN rejection_reason TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'verified_at') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN verified_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'dd_checklist_items' AND column_name = 'verified_by') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN verified_by TEXT;
    END IF;
END $$;


-- ============================================================
-- CHECKLIST ITEM DOCUMENTS LINK TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS dd_checklist_item_documents (
    id TEXT PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    checklist_item_id UUID NOT NULL REFERENCES dd_checklist_items(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    document_table TEXT NOT NULL DEFAULT 'documents',
    extraction_id TEXT REFERENCES dd_document_extractions(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    verified_at TIMESTAMPTZ,
    verified_by TEXT,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clid_org ON dd_checklist_item_documents(org_id);
CREATE INDEX IF NOT EXISTS idx_clid_checklist ON dd_checklist_item_documents(checklist_item_id);
CREATE INDEX IF NOT EXISTS idx_clid_document ON dd_checklist_item_documents(document_id);
CREATE INDEX IF NOT EXISTS idx_clid_extraction ON dd_checklist_item_documents(extraction_id);


-- ============================================================
-- PRACTICE CLAIMED ATTRIBUTES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS practice_claimed_attributes (
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

CREATE INDEX IF NOT EXISTS idx_pcla_org ON practice_claimed_attributes(org_id);
CREATE INDEX IF NOT EXISTS idx_pcla_practice ON practice_claimed_attributes(practice_id);
CREATE INDEX IF NOT EXISTS idx_pcla_key ON practice_claimed_attributes(attribute_key);
CREATE INDEX IF NOT EXISTS idx_pcla_current ON practice_claimed_attributes(practice_id, attribute_key, is_current) WHERE is_current = TRUE;
CREATE INDEX IF NOT EXISTS idx_pcla_extraction ON practice_claimed_attributes(source_extraction_id);


-- ============================================================
-- VIEWS
-- ============================================================

CREATE OR REPLACE VIEW v_active_alerts AS
SELECT
    a.*,
    dt.label as doc_type_label,
    p.dba_name as practice_name,
    p.legal_name as practice_legal_name,
    (a.alert_date - CURRENT_DATE) as days_remaining,
    CASE
        WHEN (a.alert_date - CURRENT_DATE) <= 0 THEN 'overdue'
        WHEN (a.alert_date - CURRENT_DATE) <= 7 THEN 'critical'
        WHEN (a.alert_date - CURRENT_DATE) <= 30 THEN 'warning'
        ELSE 'upcoming'
    END as urgency
FROM dd_extraction_alerts a
LEFT JOIN document_types dt ON a.doc_type_code = dt.code
LEFT JOIN practices p ON a.practice_id = p.id
WHERE a.status = 'active';

CREATE OR REPLACE VIEW v_current_extractions AS
SELECT
    e.*,
    dt.label as doc_type_label,
    dt.category as doc_type_category
FROM dd_document_extractions e
LEFT JOIN document_types dt ON e.doc_type_code = dt.code
WHERE e.is_current = TRUE;

CREATE OR REPLACE VIEW v_practice_attributes AS
SELECT
    pca.practice_id,
    pca.attribute_key,
    pca.attribute_value,
    pca.value_type,
    pca.is_verified,
    pca.source_type,
    pca.source_document_id,
    pca.created_at,
    pca.verified_at
FROM practice_claimed_attributes pca
WHERE pca.is_current = TRUE;

CREATE OR REPLACE VIEW v_checklist_progress AS
SELECT
    ci.practice_id,
    ci.template_id,
    COUNT(*) as total_items,
    COUNT(*) FILTER (WHERE ci.is_complete = TRUE OR ci.status = 'verified') as completed_items,
    COUNT(*) FILTER (WHERE ci.status = 'rejected') as rejected_items,
    COUNT(*) FILTER (WHERE ci.status = 'received') as pending_review_items,
    COUNT(*) FILTER (WHERE ci.status = 'required' OR ci.status = 'requested') as missing_items,
    ROUND(
        (COUNT(*) FILTER (WHERE ci.is_complete = TRUE OR ci.status = 'verified')::NUMERIC /
         NULLIF(COUNT(*), 0) * 100),
        1
    ) as completion_pct
FROM dd_checklist_items ci
GROUP BY ci.practice_id, ci.template_id;


-- ============================================================
-- TRIGGERS
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_ddx_updated_at ON dd_document_extractions;
CREATE TRIGGER update_ddx_updated_at
    BEFORE UPDATE ON dd_document_extractions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_templates_updated_at ON document_templates;
CREATE TRIGGER update_templates_updated_at
    BEFORE UPDATE ON document_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION update_alert_days_until()
RETURNS TRIGGER AS $$
BEGIN
    NEW.days_until = NEW.alert_date - CURRENT_DATE;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_alert_days ON dd_extraction_alerts;
CREATE TRIGGER update_alert_days
    BEFORE INSERT OR UPDATE ON dd_extraction_alerts
    FOR EACH ROW EXECUTE FUNCTION update_alert_days_until();


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE document_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE dd_document_extractions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dd_extraction_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE dd_checklist_item_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE practice_claimed_attributes ENABLE ROW LEVEL SECURITY;

-- document_types (read-only for all)
DROP POLICY IF EXISTS "doc_types_select_all" ON document_types;
CREATE POLICY "doc_types_select_all" ON document_types
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "doc_types_admin_all" ON document_types;
CREATE POLICY "doc_types_admin_all" ON document_types
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM user_organizations WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'))
    WITH CHECK (EXISTS (SELECT 1 FROM user_organizations WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'));

-- dd_document_extractions (org-scoped)
DROP POLICY IF EXISTS "ddx_select_org" ON dd_document_extractions;
CREATE POLICY "ddx_select_org" ON dd_document_extractions FOR SELECT TO authenticated USING (org_id = get_my_org_id());
DROP POLICY IF EXISTS "ddx_insert_org" ON dd_document_extractions;
CREATE POLICY "ddx_insert_org" ON dd_document_extractions FOR INSERT TO authenticated WITH CHECK (org_id = get_my_org_id());
DROP POLICY IF EXISTS "ddx_update_org" ON dd_document_extractions;
CREATE POLICY "ddx_update_org" ON dd_document_extractions FOR UPDATE TO authenticated USING (org_id = get_my_org_id()) WITH CHECK (org_id = get_my_org_id());
DROP POLICY IF EXISTS "ddx_delete_org" ON dd_document_extractions;
CREATE POLICY "ddx_delete_org" ON dd_document_extractions FOR DELETE TO authenticated USING (org_id = get_my_org_id());

-- dd_extraction_alerts (org-scoped)
DROP POLICY IF EXISTS "alerts_select_org" ON dd_extraction_alerts;
CREATE POLICY "alerts_select_org" ON dd_extraction_alerts FOR SELECT TO authenticated USING (org_id = get_my_org_id());
DROP POLICY IF EXISTS "alerts_insert_org" ON dd_extraction_alerts;
CREATE POLICY "alerts_insert_org" ON dd_extraction_alerts FOR INSERT TO authenticated WITH CHECK (org_id = get_my_org_id());
DROP POLICY IF EXISTS "alerts_update_org" ON dd_extraction_alerts;
CREATE POLICY "alerts_update_org" ON dd_extraction_alerts FOR UPDATE TO authenticated USING (org_id = get_my_org_id());
DROP POLICY IF EXISTS "alerts_delete_org" ON dd_extraction_alerts;
CREATE POLICY "alerts_delete_org" ON dd_extraction_alerts FOR DELETE TO authenticated USING (org_id = get_my_org_id());

-- document_templates (org-scoped, admin write)
DROP POLICY IF EXISTS "templates_select_org" ON document_templates;
CREATE POLICY "templates_select_org" ON document_templates FOR SELECT TO authenticated USING (org_id = get_my_org_id());
DROP POLICY IF EXISTS "templates_insert_admin" ON document_templates;
CREATE POLICY "templates_insert_admin" ON document_templates FOR INSERT TO authenticated
    WITH CHECK (org_id = get_my_org_id() AND EXISTS (SELECT 1 FROM user_organizations WHERE user_id = auth.uid() AND org_id = get_my_org_id() AND role = 'admin' AND status = 'active'));
DROP POLICY IF EXISTS "templates_update_admin" ON document_templates;
CREATE POLICY "templates_update_admin" ON document_templates FOR UPDATE TO authenticated
    USING (org_id = get_my_org_id() AND EXISTS (SELECT 1 FROM user_organizations WHERE user_id = auth.uid() AND org_id = get_my_org_id() AND role = 'admin' AND status = 'active'))
    WITH CHECK (org_id = get_my_org_id() AND EXISTS (SELECT 1 FROM user_organizations WHERE user_id = auth.uid() AND org_id = get_my_org_id() AND role = 'admin' AND status = 'active'));
DROP POLICY IF EXISTS "templates_delete_admin" ON document_templates;
CREATE POLICY "templates_delete_admin" ON document_templates FOR DELETE TO authenticated
    USING (org_id = get_my_org_id() AND EXISTS (SELECT 1 FROM user_organizations WHERE user_id = auth.uid() AND org_id = get_my_org_id() AND role = 'admin' AND status = 'active'));

-- dd_checklist_item_documents (org-scoped)
DROP POLICY IF EXISTS "clid_select_org" ON dd_checklist_item_documents;
CREATE POLICY "clid_select_org" ON dd_checklist_item_documents FOR SELECT TO authenticated USING (org_id = get_my_org_id());
DROP POLICY IF EXISTS "clid_insert_org" ON dd_checklist_item_documents;
CREATE POLICY "clid_insert_org" ON dd_checklist_item_documents FOR INSERT TO authenticated WITH CHECK (org_id = get_my_org_id());
DROP POLICY IF EXISTS "clid_update_org" ON dd_checklist_item_documents;
CREATE POLICY "clid_update_org" ON dd_checklist_item_documents FOR UPDATE TO authenticated USING (org_id = get_my_org_id());
DROP POLICY IF EXISTS "clid_delete_org" ON dd_checklist_item_documents;
CREATE POLICY "clid_delete_org" ON dd_checklist_item_documents FOR DELETE TO authenticated USING (org_id = get_my_org_id());

-- practice_claimed_attributes (org-scoped)
DROP POLICY IF EXISTS "pcla_select_org" ON practice_claimed_attributes;
CREATE POLICY "pcla_select_org" ON practice_claimed_attributes FOR SELECT TO authenticated USING (org_id = get_my_org_id());
DROP POLICY IF EXISTS "pcla_insert_org" ON practice_claimed_attributes;
CREATE POLICY "pcla_insert_org" ON practice_claimed_attributes FOR INSERT TO authenticated WITH CHECK (org_id = get_my_org_id());
DROP POLICY IF EXISTS "pcla_update_org" ON practice_claimed_attributes;
CREATE POLICY "pcla_update_org" ON practice_claimed_attributes FOR UPDATE TO authenticated USING (org_id = get_my_org_id());
DROP POLICY IF EXISTS "pcla_delete_org" ON practice_claimed_attributes;
CREATE POLICY "pcla_delete_org" ON practice_claimed_attributes FOR DELETE TO authenticated USING (org_id = get_my_org_id());


-- ============================================================
-- EXTRACTION SCHEMAS
-- ============================================================

UPDATE document_types SET extraction_schema = '{"fields": {"license_number": {"type": "string", "required": true, "label": "License Number"}, "license_state": {"type": "string", "required": true, "label": "State"}, "license_type": {"type": "string", "required": false, "label": "License Type"}, "provider_name": {"type": "string", "required": true, "label": "Provider Name"}, "issue_date": {"type": "date", "required": false, "label": "Issue Date"}, "expiration_date": {"type": "date", "required": true, "label": "Expiration Date", "creates_alert": true}, "status": {"type": "string", "required": false, "label": "Status"}, "specialty": {"type": "string", "required": false, "label": "Specialty"}}}'::jsonb WHERE code = 'medical_license';

UPDATE document_types SET extraction_schema = '{"fields": {"dea_number": {"type": "string", "required": true, "label": "DEA Number"}, "registrant_name": {"type": "string", "required": true, "label": "Registrant Name"}, "business_address": {"type": "string", "required": false, "label": "Business Address"}, "expiration_date": {"type": "date", "required": true, "label": "Expiration Date", "creates_alert": true}, "schedules": {"type": "array", "required": true, "label": "Schedules"}, "business_activity": {"type": "string", "required": false, "label": "Business Activity"}}}'::jsonb WHERE code = 'dea_certificate';

UPDATE document_types SET extraction_schema = '{"fields": {"policy_number": {"type": "string", "required": true, "label": "Policy Number"}, "carrier_name": {"type": "string", "required": true, "label": "Insurance Carrier"}, "insured_name": {"type": "string", "required": true, "label": "Insured Name"}, "coverage_type": {"type": "string", "required": false, "label": "Coverage Type"}, "per_claim_limit": {"type": "currency", "required": true, "label": "Per Claim Limit"}, "aggregate_limit": {"type": "currency", "required": true, "label": "Aggregate Limit"}, "effective_date": {"type": "date", "required": true, "label": "Effective Date"}, "expiration_date": {"type": "date", "required": true, "label": "Expiration Date", "creates_alert": true}, "tail_coverage": {"type": "boolean", "required": false, "label": "Tail Coverage"}}}'::jsonb WHERE code = 'malpractice_insurance';

UPDATE document_types SET extraction_schema = '{"fields": {"landlord_name": {"type": "string", "required": true, "label": "Landlord Name"}, "tenant_name": {"type": "string", "required": true, "label": "Tenant Name"}, "property_address": {"type": "string", "required": true, "label": "Property Address"}, "square_footage": {"type": "number", "required": false, "label": "Square Footage"}, "monthly_rent": {"type": "currency", "required": true, "label": "Monthly Rent"}, "lease_start_date": {"type": "date", "required": true, "label": "Lease Start Date"}, "lease_end_date": {"type": "date", "required": true, "label": "Lease End Date", "creates_alert": true}, "renewal_options": {"type": "string", "required": false, "label": "Renewal Options"}, "escalation_clause": {"type": "string", "required": false, "label": "Escalation Clause"}, "security_deposit": {"type": "currency", "required": false, "label": "Security Deposit"}}}'::jsonb WHERE code = 'lease_agreement';

UPDATE document_types SET extraction_schema = '{"fields": {"tax_year": {"type": "number", "required": true, "label": "Tax Year"}, "form_type": {"type": "string", "required": true, "label": "Form Type"}, "entity_name": {"type": "string", "required": true, "label": "Entity Name"}, "ein": {"type": "string", "required": false, "label": "EIN", "redacted": true}, "gross_revenue": {"type": "currency", "required": true, "label": "Gross Revenue"}, "total_deductions": {"type": "currency", "required": false, "label": "Total Deductions"}, "net_income": {"type": "currency", "required": true, "label": "Net Income"}, "officer_compensation": {"type": "currency", "required": false, "label": "Officer Compensation"}}}'::jsonb WHERE code = 'tax_return';

UPDATE document_types SET extraction_schema = '{"fields": {"bank_name": {"type": "string", "required": true, "label": "Bank Name"}, "account_type": {"type": "string", "required": true, "label": "Account Type"}, "account_number_last4": {"type": "string", "required": true, "label": "Account (Last 4)", "redacted": true}, "statement_period_start": {"type": "date", "required": true, "label": "Period Start"}, "statement_period_end": {"type": "date", "required": true, "label": "Period End"}, "beginning_balance": {"type": "currency", "required": true, "label": "Beginning Balance"}, "ending_balance": {"type": "currency", "required": true, "label": "Ending Balance"}, "total_deposits": {"type": "currency", "required": true, "label": "Total Deposits"}, "total_withdrawals": {"type": "currency", "required": true, "label": "Total Withdrawals"}}}'::jsonb WHERE code = 'bank_statement';


-- ============================================================
-- DONE
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE 'Feature 8 & 9 Schema Installation Complete!';
END $$;
