# Shared report templates

The built-in GoDigital report remains the default until a report administrator uploads a `.pptx` file. The latest upload becomes the shared default for PowerPoint, PDF, Word, and approval previews. Templates are limited to 10 MB.

## Database migration

Before enabling the employee screenshot workflow, run `sql/migrations/report_workflow.sql` against `godigital_db`. It creates missing report history, shared-template, approval, draft, screenshot, and editable-field tables without replacing existing tables. The workflow reuses Task Manager client assignments and the existing report approval/export routes.

## Template placeholders

- Text fields use `{{field_key}}`, for example `{{client_name}}`, `{{report_month}}`, `{{google_ads_clicks}}`, or `{{active_users}}`.
- A template must contain at least one text or screenshot placeholder.
- Provider-specific keys are prefixed with the normalized provider name to avoid collisions, such as `{{meta_ads_clicks}}` or `{{google_search_console_average_position}}`.
- Screenshot placeholders use `{{SCREENSHOT:provider}}`, such as `{{SCREENSHOT:GOOGLE_ADS}}`. Add one positioned text box placeholder for every screenshot the report should show. Repeat the placeholder for multiple screenshots from the same provider.
- Provider slide titles should include the provider name (for example `Google Ads`, `Google Analytics`, or `LinkedIn Ads`). Unselected provider slides are omitted; Channel Summary, Creatives Published, Creative Showcase, and Next Month Plan slides are retained.
- Place each token in one PowerPoint text run. Missing report values are replaced with empty text.

## Server requirements

PowerPoint output uses the populated uploaded deck directly. PDF and Word output render that same deck through LibreOffice and Poppler. Install both tools on the backend host, or configure:

- `REPORT_OFFICE_CONVERTER_PATH` to the LibreOffice `soffice` executable.
- `REPORT_PDF_RENDERER_PATH` to Poppler's `pdftoppm` executable.

If no uploaded template exists, all formats continue to use the built-in GoDigital report renderer and do not require these conversion tools.
