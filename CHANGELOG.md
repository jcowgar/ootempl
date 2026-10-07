# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-10-07

### Added
- Inline conditionals: `{{if}}`/`{{else}}`/`{{endif}}` within a single paragraph
  show or hide just the text between them
- Line breaks (`\n`, `\r\n`, `\r`) and tabs in substituted values render as
  Word line breaks and tabs instead of spaces
- `:split_placeholder` placeholder error for placeholders split across document
  structure (e.g. partly inside a hyperlink), which were previously left in the
  output unreplaced
- `Ootempl.Conditional.detect_markers/1` and `Ootempl.Xml.put_text/2`

### Changed
- **Breaking:** substituted values are XML-escaped once. Values containing
  `&`, `<`, `>`, `'` or `"` previously rendered as `&amp;`, `&lt;`, etc. in
  Word; callers that worked around this should drop their workarounds
- Fragmented placeholders are normalized by moving the placeholder into the
  run where it starts instead of merging runs, so surrounding text keeps its
  own formatting
- A multi-paragraph conditional whose marker shares a paragraph with other
  text now returns an error instead of deleting that text

### Fixed
- Leading/trailing spaces lost around substituted values (`xml:space="preserve"`
  dropped or not added) (MS-1524)
- Tabs, line breaks, symbols and other run content deleted from runs
  containing a placeholder
- Placeholders fragmented across runs inside hyperlinks, tracked insertions,
  smart tags or content controls, or separated by bookmarks or whitespace,
  were not replaced
- Inline conditionals deleted their whole paragraph
- Conditions garbled by multi-byte characters (e.g. `’`, `é`) earlier in the
  document
- Paragraph-level markers with different case or extra spaces (`{{IF  x}}`)
  failed to process despite being documented as supported
- Paragraph-level conditionals in headers and footers raised an exception
- A hidden section filling a table cell left the cell without a paragraph,
  producing an invalid document

## [0.3.0] - 2026-06-15

### Added
- Placeholder formatting filters (Jinja/Liquid style): `{{ value | filter: args | ... }}`
- Built-in filters: `date`, `time`, `datetime`, `round`, `number`, `currency`,
  `upcase`, `downcase`, `capitalize`, `trim`, `truncate`, and `default`
- Register custom filters via application config (`config :ootempl, filters: %{...}`)
  or per call with the `:filters` option to `Ootempl.render/4`; both can override built-ins
- New `Ootempl.Filters` module and `Ootempl.DataAccess.get_raw_value/2`
- Default rendering for unfiltered values: `Date`, `Time`, `NaiveDateTime`, and
  `DateTime` now format with ISO-style defaults (and other `String.Chars`
  structs such as `Decimal` are supported) instead of erroring

## [0.2.0] - 2026-04-01

### Added
- Hierarchical table support using block markers (`{{#list}}...{{/list}}`)
- Support for nested parent-child data iteration in tables
- Header/body/footer row sections within block markers
- Data scoping: child rows inherit parent data fields
- Automatic removal of marker-only rows from output
- New `Ootempl.Block` module for block marker detection and expansion

### Fixed
- Non-ASCII characters (Cyrillic, symbols, etc.) in templates causing `{:bad_character, N}` XML parsing errors ([#1](https://github.com/jcowgar/ootempl/issues/1))
- Placeholder errors in repeating table rows now reported correctly instead of being silently ignored

## [0.1.0] - 2025-10-09

### Added
- Initial release of Ootempl
- Template variable replacement with `{{variable}}` syntax
- Conditional content blocks with `{{#if variable}}...{{/if}}`
- Table row iteration with `{{#each variable}}...{{/each}}`
- Image insertion and manipulation
- Template inspection API with `Ootempl.inspect/1`
- Support for Office Open XML documents (Word .docx format)
- Archive handling for OOXML file structure
- XML manipulation and normalization utilities
- Relationship management for document components
- Data validation and type checking

[0.2.0]: https://github.com/jcowgar/ootempl/releases/tag/v0.2.0
[0.1.0]: https://github.com/jcowgar/ootempl/releases/tag/v0.1.0
