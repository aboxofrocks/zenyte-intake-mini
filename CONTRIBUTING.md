# Contributing to Zenyte Intake Mini

This guide helps developers understand how to work with and contribute to this codebase.

## Getting Started

### Prerequisites
- Modern web browser (Chrome, Firefox, Safari, Edge)
- Text editor or IDE (VS Code recommended)
- Supabase account (for backend)
- Basic knowledge of HTML, CSS, JavaScript

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/aboxofrocks/zenyte-intake-mini.git
   cd zenyte-intake-mini
   ```

2. **Configure Supabase**
   - Create a Supabase project at [supabase.com](https://supabase.com)
   - Run the schema SQL files in Supabase SQL Editor
   - Update credentials in `index.html` (~line 7650):
   ```javascript
   const SUPABASE_URL = 'https://your-project.supabase.co';
   const SUPABASE_ANON_KEY = 'your-anon-key';
   ```

3. **Run locally**
   ```bash
   # Option 1: Python
   python -m http.server 8000

   # Option 2: Node.js
   npx serve .

   # Option 3: Just open in browser
   open index.html
   ```

4. **Access the app**
   - Navigate to `http://localhost:8000`
   - Sign up with email/password
   - You'll be the first admin in your org

---

## Code Structure

### File Organization

```
index.html
├── Lines 1-50        → DOCTYPE, meta, title
├── Lines 50-5500     → <style> CSS
├── Lines 5500-6500   → <body> HTML structure
│   ├── Login screen
│   ├── Main app container
│   ├── Settings panel
│   └── Modals
└── Lines 6500-22000  → <script> JavaScript
    ├── Supabase init
    ├── Global state
    ├── Auth functions
    ├── CRUD operations
    ├── UI rendering
    ├── Financial module
    ├── DD packet generator
    ├── Audit log
    └── App initialization
```

### Finding Code

Use your editor's search (Cmd/Ctrl + F) with these patterns:

| To find... | Search for... |
|------------|---------------|
| A function | `function functionName` |
| CSS for a component | `.class-name {` |
| HTML element | `id="element-id"` |
| Event handler | `onclick="functionName"` |
| Supabase query | `.from('table_name')` |

### Key Sections

| Line Range | Section |
|------------|---------|
| ~50-5500 | CSS styles |
| ~5500-6500 | HTML structure |
| ~7650 | Supabase config |
| ~8000 | Global state (db object) |
| ~9300 | Event logging (logEvent) |
| ~12000 | Practice CRUD |
| ~15000 | Financial module |
| ~17000 | DD packet generator |
| ~17300 | Settings/Audit log |
| ~21800 | App initialization |

---

## Coding Standards

### JavaScript

**Naming Conventions:**
```javascript
// Functions: camelCase, verb-first
function loadPractices() { }
function handleSubmit() { }
function renderPracticeList() { }

// Variables: camelCase
let selectedPracticeId = null;
const auditPageSize = 25;

// Constants: UPPER_SNAKE_CASE
const SUPABASE_URL = '...';
const MAX_FILE_SIZE = 50 * 1024 * 1024;

// IDs: prefix_random
const id = 'prc_' + Math.random().toString(36).substring(2, 10);
```

**Function Structure:**
```javascript
// Async functions for Supabase operations
async function loadPractices() {
  try {
    const { data, error } = await window.sb
      .from('practices')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;

    db.practices = data || [];
    renderPracticeList();
  } catch (err) {
    console.error('[Practices] Load error:', err);
  }
}
```

**Error Handling:**
```javascript
// Always use try/catch for async operations
try {
  const { data, error } = await window.sb.from('...').select('*');
  if (error) throw error;
  // success handling
} catch (err) {
  console.error('[Module] Operation failed:', err);
  // Show user-friendly error if needed
  alert('Failed to load data. Please try again.');
}
```

### CSS

**Class Naming (BEM-inspired):**
```css
/* Component */
.practice-list { }

/* Component element */
.practice-list-item { }
.practice-list-empty { }

/* Component modifier */
.practice-list-item.active { }
.practice-list-item.selected { }

/* State classes */
.is-loading { }
.is-visible { }
.has-error { }
```

**Organization:**
```css
/* Group related styles with comments */

/* ========== Practice List ========== */
.practice-list { }
.practice-list-item { }

/* ========== Settings Panel ========== */
.settings-overlay { }
.settings-panel { }
```

### HTML

**Element IDs:**
```html
<!-- Use descriptive IDs -->
<div id="practice-list"></div>
<input id="audit-filter-type">
<button id="audit-prev-btn">

<!-- Use data attributes for JS hooks -->
<button data-tab="audit-log" onclick="switchTab('audit-log')">
```

**Accessibility:**
```html
<!-- Include labels and titles -->
<button title="Settings (Admin)" onclick="openSettings()">
<label for="audit-filter-type">Event Type</label>
<input id="audit-filter-type" ...>
```

---

## Common Tasks

### Adding a New Feature

1. **Plan the feature**
   - What UI elements needed?
   - What data/tables involved?
   - What functions required?

2. **Add HTML structure**
   - Find appropriate location in body
   - Add with `style="display: none"` if hidden by default

3. **Add CSS styles**
   - Add at end of `<style>` section
   - Group with comment header

4. **Add JavaScript**
   - Add functions near related code
   - Follow existing patterns
   - Add console logging for debugging

5. **Test thoroughly**
   - Test with different user roles
   - Test error cases
   - Check browser console for errors

### Adding a New Database Table

1. **Write SQL schema**
   ```sql
   CREATE TABLE new_table (
     id TEXT PRIMARY KEY,
     org_id UUID NOT NULL REFERENCES organizations(id),
     -- other columns
     created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );

   -- Indexes
   CREATE INDEX idx_new_table_org ON new_table(org_id);

   -- RLS
   ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;

   CREATE POLICY "select_org" ON new_table
     FOR SELECT TO authenticated
     USING (org_id = get_my_org_id());
   ```

2. **Run in Supabase SQL Editor**

3. **Add to DATABASE.md documentation**

4. **Add JavaScript CRUD functions**

### Adding a New Event Type

1. **Log the event**
   ```javascript
   await logEvent({
     event_type: 'new_event_type',
     practice_id: practiceId,
     actor_id: window.currentUser?.email,
     payload: { relevant: 'data' }
   });
   ```

2. **Update audit log filter dropdown**
   ```html
   <option value="new_event_type">New Event</option>
   ```

3. **Add formatting in `formatEventBadge()`**
   ```javascript
   const icons = {
     // existing...
     new_event_type: '&#128640;'
   };
   const labels = {
     // existing...
     new_event_type: 'New Event'
   };
   ```

---

## Testing

### Manual Testing Checklist

Before submitting changes:

- [ ] Login/logout works
- [ ] Create/edit/delete practice works
- [ ] Document upload works
- [ ] Financial extraction flow works
- [ ] DD packet generates correctly
- [ ] Audit log shows events (admin only)
- [ ] Non-admin cannot see admin features
- [ ] No console errors
- [ ] Mobile responsive (if applicable)

### Testing Different Roles

1. **Admin user**
   - Should see Settings button
   - Should see Admin Panel
   - Full edit capabilities

2. **Editor user**
   - No Settings button
   - No Admin Panel
   - Can create/edit practices

3. **Viewer user**
   - No Settings button
   - No Admin Panel
   - Read-only access

---

## Git Workflow

### Commit Messages

```
<type>: <short description>

<optional longer description>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `style:` - CSS/formatting
- `refactor:` - Code restructure
- `perf:` - Performance improvement

**Examples:**
```
feat: Add audit log viewer for admins

- Settings panel with tabbed navigation
- Combined view of practice and document events
- Filter by type, practice, date range
- Export to CSV

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

### Branch Strategy

```
main (production)
  └── feature/audit-log
  └── feature/export-pdf
  └── fix/login-error
```

---

## Debugging

### Console Logging

The app uses prefixed console logs:

```javascript
console.log('[Auth] User signed in:', user.email);
console.error('[Practices] Load error:', err);
console.log('[FinDocs] Upload complete:', docId);
```

### Common Issues

**"Permission denied" on Supabase query**
- Check RLS policies
- Verify user has org membership
- Check `get_my_org_id()` returns valid org

**UI not updating after data change**
- Call the appropriate render function
- Check if data was actually saved
- Verify you're updating the right state

**Function not defined**
- Check for typos in function name
- Verify function is defined before use
- Check for JavaScript errors earlier in file

---

## Resources

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [MDN Web Docs](https://developer.mozilla.org/)

---

## Questions?

If you have questions about the codebase:
1. Check this documentation first
2. Search the code for similar patterns
3. Review ARCHITECTURE.md for system design
4. Review DATABASE.md for schema details
