# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Placeholder formatting filters (Jinja/Liquid style): `{{ value | filter: args | ... }}`
- Built-in filters: `date`, `time`, `datetime`, `round`, `number`, `currency`,
  `upcase`, `downcase`, `capitalize`, `trim`, `truncate`, and `default`
- Register custom filters via application config (`config :ootempl, filters: %{...}`)
  or per call with the `:filters` option to `Ootempl.render/4`; both can override built-ins
- New `Ootempl.Filters` module and `Ootempl.DataAccess.get_raw_value/2`

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
