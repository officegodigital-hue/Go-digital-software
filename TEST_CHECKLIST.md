# Client Name Dropdown - Quick Test Checklist

## Pre-Testing Requirements
- [ ] Backend server running on http://127.0.0.1:5000
- [ ] Frontend running in Flutter (web or mobile)
- [ ] Database with clients table populated
- [ ] Browser dev tools open (for network inspection)

## Feature Tests

### ✅ Test 1: Uppercase Conversion
**Expected**: Text typed in Client Name field appears as UPPERCASE
1. [ ] Navigate to Create Quotation
2. [ ] Click on Client Name field
3. [ ] Type: "test client name"
4. [ ] Verify displays: "TEST CLIENT NAME"
5. [ ] Continue typing: " more text"
6. [ ] Verify all text is UPPERCASE

### ✅ Test 2: Dropdown Opens on Type
**Expected**: Dropdown appears when user starts typing
1. [ ] Navigate to Create Quotation
2. [ ] Click on Client Name field
3. [ ] Type any character
4. [ ] Verify dropdown list appears below field
5. [ ] Verify dropdown contains client suggestions

### ✅ Test 3: Search Filtering Works
**Expected**: Dropdown filters to show matching clients
1. [ ] Navigate to Create Quotation
2. [ ] Type "G" (or first letter of a company name in your DB)
3. [ ] Wait ~300ms
4. [ ] Verify dropdown shows only companies containing "G"
5. [ ] Type "O" to make "GO"
6. [ ] Verify dropdown filters further
7. [ ] Delete all text
8. [ ] Verify all companies appear again

### ✅ Test 4: Select from Dropdown
**Expected**: Clicking on a dropdown item populates the field
1. [ ] Navigate to Create Quotation
2. [ ] Type to show dropdown items
3. [ ] Click on a company name
4. [ ] Verify field populates with that company name in UPPERCASE
5. [ ] Verify dropdown closes
6. [ ] Verify selection shows checkmark in previous dropdown

### ✅ Test 5: Manual Entry (No Match)
**Expected**: User can type a new client name manually
1. [ ] Navigate to Create Quotation
2. [ ] Type a company name that doesn't exist in DB
3. [ ] Verify dropdown shows "No results for..."
4. [ ] Verify you can continue typing
5. [ ] Try to save quotation with the manually entered name
6. [ ] Verify quotation saves successfully

### ✅ Test 6: Edit Mode - Read-Only
**Expected**: Field is read-only when editing an existing quotation
1. [ ] Create and save a quotation first
2. [ ] Click Edit on that quotation
3. [ ] Verify Client Name field shows the saved name in UPPERCASE
4. [ ] Verify field has blue background
5. [ ] Try to click/type in the field
6. [ ] Verify field does not accept input
7. [ ] Verify dropdown arrow is NOT visible
8. [ ] Verify you cannot modify the client name

### ✅ Test 7: Edit Mode - Other Fields Editable
**Expected**: Other fields can be edited while client name is read-only
1. [ ] In Edit mode (from Test 6)
2. [ ] Try to modify Quotation Date
3. [ ] Verify Quotation Date is editable
4. [ ] Try to modify other fields
5. [ ] Verify all other fields except Client Name are editable

### ✅ Test 8: Dropdown Styling Unchanged
**Expected**: UI appearance matches original design
1. [ ] Navigate to Create Quotation
2. [ ] Verify field styling (border, padding, font) matches original
3. [ ] Open dropdown
4. [ ] Verify dropdown styling (colors, shadows, separators) matches original
5. [ ] Verify blue background in edit mode matches spec
6. [ ] Verify company names display in correct font/size
7. [ ] Verify industry text displays below company name

### ✅ Test 9: API Integration
**Expected**: Backend API is called with correct parameters
1. [ ] Open browser Dev Tools → Network tab
2. [ ] Navigate to Create Quotation
3. [ ] Type "GA" in Client Name field
4. [ ] Wait for API call to complete
5. [ ] Verify API request: GET /api/clients/search/query?query=GA
6. [ ] Verify response contains data array
7. [ ] Verify response data includes company_name, industry
8. [ ] Delete query text
9. [ ] Verify new API request with empty query: /api/clients/search/query

### ✅ Test 10: Debouncing Works
**Expected**: Only one API call made despite rapid typing
1. [ ] Open browser Dev Tools → Network tab
2. [ ] Navigate to Create Quotation
3. [ ] Click on Client Name field
4. [ ] Type quickly: "G", "A", "L" (all within 1 second)
5. [ ] Check Network tab
6. [ ] Verify ONLY 1 API call was made (not 3)
7. [ ] Verify the call was made ~300ms after last keystroke

### ✅ Test 11: Save Quotation with Selected Client
**Expected**: Quotation saves with the selected client name
1. [ ] Navigate to Create Quotation
2. [ ] Select a client from dropdown
3. [ ] Fill in other required fields
4. [ ] Click "Save Quotation"
5. [ ] Verify quotation saves successfully
6. [ ] Click View or Edit on saved quotation
7. [ ] Verify client name is saved in UPPERCASE
8. [ ] Verify it matches the selected company name

### ✅ Test 12: View Quotation (Read-Only)
**Expected**: View mode also shows read-only client name
1. [ ] Open a saved quotation in View mode
2. [ ] Verify Client Name field shows saved name
3. [ ] Verify field has blue background
4. [ ] Verify field is read-only
5. [ ] Verify dropdown arrow is hidden
6. [ ] Verify styling matches edit mode

## Edge Cases

### ✅ Test 13: Empty Company Names
**Expected**: System handles clients with empty company names
1. [ ] Verify no errors in console
2. [ ] Verify dropdown doesn't show empty items

### ✅ Test 14: Special Characters
**Expected**: Special characters in company names work correctly
1. [ ] Search for company with special characters (if available)
2. [ ] Verify search finds it
3. [ ] Verify name displays correctly in UPPERCASE
4. [ ] Verify it saves correctly

### ✅ Test 15: Very Long Company Names
**Expected**: Long names display correctly (truncated if needed)
1. [ ] Find or add a company with very long name
2. [ ] Search for it
3. [ ] Verify it displays with truncation (ellipsis) if needed
4. [ ] Verify selected name displays in field without truncation
5. [ ] Verify field can hold the full name

## Browser Compatibility

- [ ] Test in Chrome
- [ ] Test in Firefox
- [ ] Test in Safari (if using MacOS)
- [ ] Test in Mobile Browser (if applicable)

## Performance Tests

- [ ] Type continuously for 5 seconds - verify only ~1 API call per second
- [ ] Search with 1000+ clients in DB - verify response time < 500ms
- [ ] Open/close dropdown multiple times - verify no memory leaks

## Regression Tests

- [ ] Other quotation fields still work correctly
- [ ] Other screens/modules not affected
- [ ] Previous quotations display correctly
- [ ] PDF generation still works with saved client names
- [ ] Package selection still works
- [ ] Date picker still works

## Sign-Off

- [ ] All tests passed
- [ ] UI matches original design
- [ ] No console errors
- [ ] No network errors
- [ ] Performance acceptable
- [ ] Ready for production deployment

---

**Notes for Testing**:
1. If a test fails, check the browser console for errors
2. Check the backend server logs for API errors
3. Verify database contains test data with company names
4. Clear browser cache if experiencing stale data issues
5. Restart servers if API endpoints not responding
