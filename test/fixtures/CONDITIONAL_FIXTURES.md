# Conditional Fixture Files

This directory contains static .docx fixture files with conditional markers (`@if:@`, `@else@`, `@endif@`) for testing the conditional section processing functionality.

## Purpose

These fixtures provide:
- **Real-world compatibility**: Files can be opened and verified in Microsoft Word or compatible applications
- **Visual verification**: Content can be manually inspected to ensure markers are correctly placed
- **Integration testing**: Tests use actual .docx files rather than programmatically generated XML
- **Comprehensive coverage**: Different conditional scenarios and edge cases

## Fixture Files

### conditional_simple.docx
Simple if/endif conditional section.
- **Conditionals**: `@if:show_section@` ... `@endif@`
- **Use case**: Basic show/hide functionality

### conditional_if_else.docx
If/else conditional with alternative content.
- **Conditionals**: `@if:is_premium@` ... `@else@` ... `@endif@`
- **Use case**: Account status report showing different content for premium vs. standard members

### conditional_multi_paragraph.docx
Conditional section spanning multiple paragraphs.
- **Conditionals**: `@if:include_warranty@` ... (4 paragraphs) ... `@endif@`
- **Use case**: Contract sections that can be optionally included

### conditional_nested_path.docx
Conditional markers using nested data paths.
- **Conditionals**:
  - `@if:customer.active@` ... `@endif@`
  - `@if:customer.profile.verified@` ... `@endif@`
- **Use case**: Complex data structures with dot-notation paths

### conditional_multiple.docx
Multiple independent conditional sections in one document.
- **Conditionals**:
  - `@if:show_electronics@` ... `@endif@`
  - `@if:show_clothing@` ... `@endif@`
  - `@if:show_furniture@` ... `@endif@`
- **Use case**: Product catalog with selectable sections

### conditional_with_variables.docx
Combination of conditional markers and variable placeholders.
- **Conditionals**: `@if:has_discount@` ... `@endif@`
- **Variables**: `@customer_name@`, `@discount_percent@`, `@discount_code@`, `@total_amount@`
- **Use case**: Order confirmation with optional discount information

## Regenerating Fixtures

To recreate all fixture files (e.g., after making changes):

```bash
elixir test/fixtures/create_conditional_fixtures.exs
```

This will regenerate all conditional fixture files in the `test/fixtures/` directory.

## Testing

These fixtures are used by integration tests in:
- `test/ootempl/integration/conditional_fixture_test.exs`

Run the tests with:

```bash
mix test test/ootempl/integration/conditional_fixture_test.exs
```

## File Format

All fixture files are valid .docx files (ZIP archives containing XML):
- Can be opened in Microsoft Word, LibreOffice, or Google Docs
- Follow Office Open XML (OOXML) format
- Include minimal required files: `[Content_Types].xml`, `_rels/.rels`, `word/document.xml`, `word/_rels/document.xml.rels`

## Notes

- Conditional markers are case-insensitive: `@IF:name@`, `@if:name@`, and `@If:name@` are all equivalent
- Only `@if:variable@` markers are reported in `Ootempl.inspect/1` results
- `@else@` and `@endif@` markers are not separately reported in inspection results
- The inspect API returns placeholders (not variables) and conditionals with `condition`, `path`, and `locations` fields
