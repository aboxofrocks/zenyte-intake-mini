# Lead Import Feature Documentation

## Overview
Bulk import system for 2000+ leads from CSV, Excel (.xlsx), or Google Sheets paste.

**Location:** Settings > Import Data tab

---

## Code Locations (index.html)

| Component | Line Range | Description |
|-----------|------------|-------------|
| SheetJS CDN | ~8322 | Excel parsing library |
| Import Tab Button | ~6973 | Settings tab navigation |
| Import HTML (4-step wizard) | ~7077-7165 | Upload, Map, Progress, Complete steps |
| Import CSS | ~5640-5890 | All import styling |
| Import State Object | ~18830 | `importState` global |
| Field Mappings | ~19469-19550 | 100+ column name variations |
| Data Normalization | ~18862-19027 | Boolean, number, date, status, ownership |
| Fuzzy Matching | ~19030-19065 | String similarity for unmapped columns |
| Duplicate Detection | ~19607-19639 | `checkForDuplicates()` |
| First/Last Name Logic | ~19684-19691 | Combines into legal_name |
| Chunked Import | ~19700-19780 | `importPracticesInChunks()` |

---

## Key Functions

```javascript
// File parsing
handleImportFile(event)      // CSV/Excel file upload
handleImportPaste()          // Google Sheets paste (tab-separated)
parseCSV(text)               // CSV parsing with quoted fields
parseExcel(data)             // Excel via SheetJS

// Column mapping
autoMapColumns()             // Auto-detect mappings from headers
stringSimilarity(s1, s2)     // Fuzzy matching fallback
renderMappingGrid()          // UI for column mapping
updateMapping(col, field)    // Manual mapping adjustment

// Data normalization
normalizeBoolean(val)        // Yes/Y/1/TRUE → true
normalizeNumber(val)         // $1.5M, 25%, 1,500 → number
normalizeDate(val)           // Various formats → ISO date
normalizeStatus(val)         // Maps to Lead/Onboarding/Active/Exited/Archived
normalizeOwnership(val)      // Maps to Solo/Partnership/Group/PE-Backed/etc.
normalizeFieldValue(field, val)  // Routes to appropriate normalizer

// Import execution
validateAndImport()          // Start import process
checkForDuplicates(practices) // Pre-check for existing matches
importPracticesInChunks(practices, 50)  // Batch insert with progress
updateImportProgress(current, total)    // Progress bar update
renderImportSummary()        // Final results display

// Navigation
goToImportStep(step)         // Switch between wizard steps
```

---

## Field Mapping Examples

The system auto-maps 100+ column name variations:

| User's Column | Maps To |
|---------------|---------|
| Practice Name, Legal Name, Name | legal_name |
| Type of practice, Specialty | specialty |
| First, First Name | _first_name (combined with last) |
| Last, Last Name | _last_name (combined with first) |
| # of Docs, Physician Count, Providers | num_providers |
| Asking, Price, Ask Price | asking_price |
| Owner Age, Age of Owner | owner_age |
| Status, Lead Status | status |

---

## Data Normalization Examples

**Booleans:**
- "Yes", "Y", "1", "TRUE", "true" → `true`
- "No", "N", "0", "FALSE", "false" → `false`

**Numbers:**
- "$1,500,000" → `1500000`
- "1.5M" → `1500000`
- "25%" → `25`
- "2.5K" → `2500`

**Status:**
- "prospect", "pipeline", "new", "inquiry" → "Lead"
- "in progress", "pending", "onboard" → "Onboarding"
- "current", "active", "engaged" → "Active"

**Ownership:**
- "solo", "single", "individual" → "Solo Practice"
- "partner", "partners" → "Partnership"
- "group", "multi" → "Group Practice"
- "pe", "private equity" → "PE-Backed"

---

## Special Handling

### First/Last Name Combination
If no `legal_name` column exists but `First` and `Last` columns do:
```javascript
legal_name = `${first} ${last}`.trim();
```

### Default Specialty
If specialty is missing (NOT NULL constraint):
```javascript
if (!practice.specialty) practice.specialty = 'Other';
```

### Duplicate Detection
Checks against existing practices by legal_name before import.
User can choose to skip duplicates or import anyway.

---

## UI Flow

```
Upload → Map Columns → Progress → Complete
   ↓         ↓            ↓          ↓
  File    Auto-map     Chunked    Summary
  Parse   + Preview    Batches    + Errors
```

---

## Dependencies

- **SheetJS (xlsx)** - CDN loaded for Excel parsing
- **Supabase** - `sb.from('practices').insert()` for database writes
- **createCanonicalPractice()** - Existing function for practice defaults
- **practiceToSupabaseRow()** - Existing function for DB format

---

## Testing Checklist

1. [ ] Upload CSV file - verify parsing
2. [ ] Upload Excel file (.xlsx) - verify SheetJS parsing
3. [ ] Paste from Google Sheets - verify tab-separated parsing
4. [ ] Check auto-mapping works for common columns
5. [ ] Manually adjust a mapping - verify preview updates
6. [ ] Import 10 rows - verify success
7. [ ] Import with duplicates - verify detection works
8. [ ] Import with missing specialty - verify default applied
9. [ ] Import contact-style data (First/Last) - verify name combination
10. [ ] Import 2000+ rows - verify chunking and progress bar
