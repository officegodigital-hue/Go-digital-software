# HRMS salary and employee wiring: implementation status

This branch contains the incremental HRMS work from the local attendance project.
It is not a completed historical-data migration or an end-to-end production certification.

## Implemented

- Effective-dated monthly compensation records and admin compensation APIs.
- Employee salary summary and paid-payslip APIs, with live salary UI values.
- Payroll policy controls for weekly off days, leave/absence and salary-day divisor.
- Current-month draft generation on backend startup and monthly scheduled generation.
- Paid amounts preserved during payroll regeneration; inconsistent saved rows require review.
- Payslip confirmation dialog, approval request links and protected download access.
- Employee login identity refreshed from the database; missing or inactive accounts rejected.
- Payroll/profile ownership checks on employee payslip operations.
- New login, HRMS profile and page permissions created in one transaction.
- Employee deactivation retains history instead of deleting the account/profile.
- Employee header identity/navigation and salary empty/review states.
- Restored attendance and HRMS employee schema files required by startup.

## Validation performed locally

- API ownership checks across 13 local accounts: salary, payslips, attendance history,
  permissions, cross-employee download rejection, admin tracking access and missing accounts.
- Isolated test database: four valid writes accepted and seven invalid ownership/deletion
  operations rejected by the proposed database guards. Repeated installation was tested.
- Isolated onboarding test: account/profile/permission IDs match; duplicate employee code
  rolls back account creation.
- Dart analysis of the salary and payroll pages: no issues.
- Backend JavaScript syntax checks and successful local backend startup.

## Pending before claiming complete migration

- Existing mismatched ownership and orphaned history require an audited reconciliation.
- Invalid historical paid payroll rows need confirmed payment amounts and correction records.
- `ensureEmployeeIdentityIntegrity` is prepared and tested but NOT installed in the live
  database and is NOT called automatically by startup. Installing its persistent triggers
  requires a reviewed database migration and explicit operational approval.
- The entire attendance project has not received full browser and lifecycle regression tests.
- New salary allocations do not immediately generate payroll: the current triggers are
  admin generation, server startup and the first-of-month schedule.
- The current download endpoint returns a text payslip, not a formatted PDF.

## Deployment notes

Back up the target database first. Starting this backend can create/upgrade attendance
tables and generate current-month pending payroll using the saved policy. It does not
automatically mark employees paid. Review policy and payroll results before deployment.

Environment files, database exports, employee records, local test databases, credentials,
dependencies and generated Flutter output are intentionally excluded from this branch.
