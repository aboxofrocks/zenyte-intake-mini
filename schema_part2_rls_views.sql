-- PART 2: INDEXES, RLS, VIEWS
-- Run this after Part 1

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_ddx_org ON dd_document_extractions(org_id);
CREATE INDEX IF NOT EXISTS idx_ddx_practice ON dd_document_extractions(practice_id);
CREATE INDEX IF NOT EXISTS idx_ddx_document ON dd_document_extractions(document_id);
CREATE INDEX IF NOT EXISTS idx_ddx_status ON dd_document_extractions(status);
CREATE INDEX IF NOT EXISTS idx_ddx_doc_type ON dd_document_extractions(doc_type_code);
CREATE INDEX IF NOT EXISTS idx_alerts_org ON dd_extraction_alerts(org_id);
CREATE INDEX IF NOT EXISTS idx_alerts_practice ON dd_extraction_alerts(practice_id);
CREATE INDEX IF NOT EXISTS idx_alerts_date ON dd_extraction_alerts(alert_date);
CREATE INDEX IF NOT EXISTS idx_templates_org ON document_templates(org_id);
CREATE INDEX IF NOT EXISTS idx_clid_org ON dd_checklist_item_documents(org_id);
CREATE INDEX IF NOT EXISTS idx_clid_checklist ON dd_checklist_item_documents(checklist_item_id);
CREATE INDEX IF NOT EXISTS idx_pcla_org ON practice_claimed_attributes(org_id);
CREATE INDEX IF NOT EXISTS idx_pcla_practice ON practice_claimed_attributes(practice_id);

-- RLS
ALTER TABLE document_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE dd_document_extractions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dd_extraction_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE dd_checklist_item_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE practice_claimed_attributes ENABLE ROW LEVEL SECURITY;

-- document_types (everyone can read)
DROP POLICY IF EXISTS "doc_types_select_all" ON document_types;
CREATE POLICY "doc_types_select_all" ON document_types FOR SELECT TO authenticated USING (true);

-- dd_document_extractions
DROP POLICY IF EXISTS "ddx_all_org" ON dd_document_extractions;
CREATE POLICY "ddx_all_org" ON dd_document_extractions FOR ALL TO authenticated
    USING (org_id = get_my_org_id()) WITH CHECK (org_id = get_my_org_id());

-- dd_extraction_alerts
DROP POLICY IF EXISTS "alerts_all_org" ON dd_extraction_alerts;
CREATE POLICY "alerts_all_org" ON dd_extraction_alerts FOR ALL TO authenticated
    USING (org_id = get_my_org_id()) WITH CHECK (org_id = get_my_org_id());

-- document_templates
DROP POLICY IF EXISTS "templates_all_org" ON document_templates;
CREATE POLICY "templates_all_org" ON document_templates FOR ALL TO authenticated
    USING (org_id = get_my_org_id()) WITH CHECK (org_id = get_my_org_id());

-- dd_checklist_item_documents
DROP POLICY IF EXISTS "clid_all_org" ON dd_checklist_item_documents;
CREATE POLICY "clid_all_org" ON dd_checklist_item_documents FOR ALL TO authenticated
    USING (org_id = get_my_org_id()) WITH CHECK (org_id = get_my_org_id());

-- practice_claimed_attributes
DROP POLICY IF EXISTS "pcla_all_org" ON practice_claimed_attributes;
CREATE POLICY "pcla_all_org" ON practice_claimed_attributes FOR ALL TO authenticated
    USING (org_id = get_my_org_id()) WITH CHECK (org_id = get_my_org_id());

-- EXTEND DD_CHECKLIST_ITEMS (add new columns if missing)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'template_id') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN template_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'doc_type_code') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN doc_type_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'item_key') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN item_key TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'description') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN description TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'due_date') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN due_date DATE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'status') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN status TEXT DEFAULT 'required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'rejection_reason') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN rejection_reason TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'verified_at') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN verified_at TIMESTAMPTZ;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dd_checklist_items' AND column_name = 'verified_by') THEN
        ALTER TABLE dd_checklist_items ADD COLUMN verified_by TEXT;
    END IF;
END $$;

-- Done
SELECT 'Part 2 complete - indexes, RLS, and columns added' as status;
