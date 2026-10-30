# Employee exits and retained history

## Using the workflow

Both admin employee screens use the same exit dialog. Deactivation automatically uses yesterday in India time as the last working date; admin enters only the reason. The date is inclusive for salary and cannot precede the known joining/current employment start date. Access stops when the exit commits, regardless of the last working date.

The preview shows salary cycles and attendance after the chosen date. Admin must correct the source record or record an audited exception before confirming. Exception approval is tied to the exact record contents and cutoff; changing the record invalidates that approval. Records are never deleted by an exit.

Open **Inactive Employees • Final Settlements** from Employee Management or the Attendance Employees page. Employee history includes employment periods, attendance, clock logs, leave, tracking, saved payroll, paid PDF payslips, salary adjustments, and audit events. The history icon on Employee Management also opens an individual employee directly.

Employee exits do not archive, transfer, or change task or client assignments. Those are managed in their own modules.

## Salary and reactivation

Daily rate is monthly salary divided by working days in the **full** configured cycle. Eligible days are the intersection with employment periods; existing paid leave, unpaid leave, absence, weekly-off, and holiday policies continue to apply. Days outside employment never become absences. Standard, flexible, and saved custom cycles are supported.

Exit recalculates saved unpaid rows in the same transaction as the account/profile changes. Use **Refresh unpaid salary** in the employee archive to generate missing final-cycle drafts for that employee only. Review each amount before marking paid. Paid amounts/timestamps remain immutable; discrepancies are stored as adjustments, requiring a recorded decision and payment/recovery reference. **Complete final settlement** remains blocked until final-cycle payroll is paid, other saved unpaid rows are paid, and adjustments are resolved. Missing salary or unknown legacy departure dates block settlement, not access removal.

Reactivation automatically uses today in India time as the new joining date, which must be after the previous last working date. Admin does not select a date. Previous periods remain closed. Tokens issued before exit cannot become valid again after rehire. A new login is required.

## Interfaces and startup

New admin endpoints under `/api/employees`:

- `POST /:id/exit-preview`, `POST /:id/exit`: `{reason}`. The server sets yesterday as the last working date; client date values are ignored.
- `POST /:id/exit-exceptions`: `{lastWorkingDate, source, sourceId, resolution}`.
- `POST /:id/reactivate`: `{}`. The server sets today as the new joining date; client date values are ignored.
- `GET /:id/lifecycle`, `GET /settlements/outstanding`.
- `POST /adjustments/:adjustmentId/resolve`: `{resolution}`.
- `POST /:id/settlement/complete`; `GET /:id/payroll/:payrollId/payslip`.

Legacy employee status PATCH/DELETE routes and HRMS status changes call the same lifecycle service. Profile edits cannot cross the active/inactive boundary. Hard employee deletion is disabled.

Payroll generation accepts optional `employeeId`; paying a former employee requires `reviewedSettlement: true`. `GET /hrms/payroll?view=settlements` filters the selected period to former employees. The archive's Outstanding / Final Settlements tab also retains unsettled employees across periods.

Backend startup idempotently creates employment periods, exits, exit exceptions, salary adjustments, and audit tables. It adds nullable `employee_users.date_of_joining` when missing. Initial active periods use the known joining date or account creation date. Existing inactive accounts are not assigned an invented exit date; record it through **Record exit**. No historic payroll or attendance rows are deleted by migration.

Restart the backend and rebuild/reload the frontend together: API requests now require an active authenticated session, and sockets authenticate with the session token. The shared frontend HTTP adapter includes that token for internal API calls. External API calls do not receive it.

## Verification

Run the backend `*.test.js` files with Node's test runner. The optional `EMPLOYEE_EXIT_MYSQL_TEST=1 node --test lib/employeeLifecycle.mysql.test.js` creates synthetic data in a uniquely named `codex_employee_exit_test_*` database and drops only that database afterward; it never targets the configured application's database for writes.

Flutter: `flutter test --no-pub test/employee_exit_dialog_test.dart`. The focused tests cover required dates/reasons, automatic rehire dates, preview contents, and blocking confirmation for unresolved records.

Full application analysis additionally depends on the repository's existing notification/Firebase packages being installed. This change does not alter those dependencies.
