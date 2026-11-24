# Shared report templates

Report administrators can upload versioned `.pptx` templates, preview them, and activate one template at a time. New report drafts pin the active template ID and version; activating another template does not change existing drafts or generated reports. Monthly report preview and export use the selected PPTX as their source of truth, including decks without placeholders. Templates are limited to 10 MB.

## Database migration

Before enabling the employee screenshot workflow, run `sql/migrations/report_workflow.sql` against `godigital_db`. It creates missing report history, shared-template, approval, draft, screenshot, and editable-field tables without replacing existing tables. The migration stores each draft's report data snapshot separately from the master PPTX. The workflow reuses Task Manager client assignments and the existing report approval/export routes.

## Template placeholders

- Text fields use `{{field_key}}`, for example `{{client_name}}`, `{{report_month}}`, `{{google_ads_clicks}}`, or `{{active_users}}`.
- Placeholders are optional. Without placeholders, the uploaded slides are still used as the report design.
- Provider-specific keys are prefixed with the normalized provider name to avoid collisions, such as `{{meta_ads_clicks}}` or `{{google_search_console_average_position}}`.
- Screenshot placeholders use `{{SCREENSHOT:provider}}`, such as `{{SCREENSHOT:GOOGLE_ADS}}`. Add one positioned text box placeholder for every screenshot the report should show. Repeat the placeholder for multiple screenshots from the same provider. Instagram screenshots and Creative Showcase images without a matching slot get their own slides in the report. Creative Showcase can use ordered {{SCREENSHOT:CREATIVE_SHOWCASE}} placeholders or named placeholders such as {{SCREENSHOT:POSTER_2}}.
- The generated report retains the template’s layout and slide order for included pages. The cover, Channel Summary, and Next Month Plan use the selected channels. Dashboard screenshots and Creative Showcase images also fill the named frames in the GoDigital template.
- Text placeholders can span multiple PowerPoint text runs. Missing report values are replaced with empty text.

## Server requirements

PowerPoint output uses the populated uploaded deck directly. PowerPoint view renders the deck through LibreOffice and Poppler and uses the slide objects to locate editable text, table cells, and uploaded images. Saved edits are applied to the same PowerPoint used for preview and export. PDF and Word output also use the generated deck. Monthly reports return a clear error if there is no active PPTX template; generic legacy report endpoints retain the built-in renderer for compatibility. Install both conversion tools on the backend host, or configure:

- `REPORT_OFFICE_CONVERTER_PATH` to the LibreOffice `soffice` executable.
- `REPORT_PDF_RENDERER_PATH` to Poppler's `pdftoppm` executable.

If no uploaded template exists, all formats continue to use the built-in GoDigital report renderer and do not require these conversion tools.
