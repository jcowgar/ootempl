# Ootempl

## Project Overview

Ootempl is an Elixir library for working with Office Open XML document templates. The primary goal is to enable programmatic manipulation of Word documents (and eventually Excel spreadsheets) by replacing placeholders with dynamic content to generate customized documents from templates.

## Current Status

**Early Development** - The project is currently a bootstrapped Mix project with no implementation yet. The core architecture and dependencies are still being planned.

## Use Cases

- Generating personalized contracts or agreements
- Creating bulk correspondence (letters, certificates, etc.)
- Automating report generation
- Mail merge functionality
- Dynamic form filling

## Technology Stack

- **Language**: Elixir ~> 1.18
- **Dependencies**: TBD (likely XML parsing libraries, ZIP handling)

## Project Structure

```
lib/
  ootempl.ex          # Main module
test/
  ootempl_test.exs    # Test suite
```

## Development Commands

Common Mix commands used during development:

- `mix compile` - Compile the project
- `mix test` - Run the test suite
- `mix test --cover` - Run tests with coverage report
- `mix format` - Format code according to .formatter.exs
- `mix format --check-formatted` - Check if code is properly formatted
- `mix deps.get` - Fetch project dependencies
- `mix deps.update --all` - Update all dependencies
- `mix clean` - Clean build artifacts
- `mix docs` - Generate documentation (if ex_doc is added)
- `mix dialyzer` - Run static analysis (if dialyxir is added)
