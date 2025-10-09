# Ootempl

Office Open XML document templating library for Elixir. Generate customized Word documents by replacing placeholders in templates with dynamic data.

## Features

- **Simple Placeholder Replacement** - Use `{{variable}}` syntax in Word templates
- **Nested Data Access** - Access nested data with `{{customer.name}}` notation
- **Conditional Sections** - Show/hide content with `{{if condition}}...{{endif}}`
- **Dynamic Tables** - Auto-generate table rows from list data
- **Image Replacement** - Replace placeholder images with dynamic content
- **Case-Insensitive Matching** - `{{Name}}`, `{{name}}`, and `{{NAME}}` all match the same data key
- **Formatting Preservation** - Maintains Word formatting (bold, italic, fonts, colors, table borders)
- **Document Properties** - Replace placeholders in title, author, company metadata
- **Headers & Footers** - Process placeholders in headers, footers, footnotes, and endnotes
- **Comprehensive Validation** - Reports all missing placeholders and errors for easy debugging

## Quick Start

Create a Word template with placeholders:

```
Dear {{customer.name}},

Your order total is {{total}}.
```

Generate a document in Elixir:

```elixir
data = %{
  "customer" => %{"name" => "John Doe"},
  "total" => "$99.99"
}

Ootempl.render("template.docx", data, "output.docx")
#=> :ok
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ootempl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ootempl, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ootempl>.

