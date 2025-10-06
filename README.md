# Ootempl

Office document templating library for Elixir. Generate customized Word documents by replacing placeholders in templates with dynamic data.

## Features

- **Simple Placeholder Replacement** - Use `@variable@` syntax in Word templates
- **Nested Data Access** - Access nested data with `@customer.name@` notation
- **Case-Insensitive Matching** - `@Name@`, `@name@`, and `@NAME@` all match the same data key
- **Formatting Preservation** - Maintains Word formatting (bold, italic, fonts, colors)
- **Error Collection** - Reports all missing placeholders together for easy debugging
- **XML Escaping** - Automatically escapes special characters to prevent document corruption

## Quick Start

Create a Word template with placeholders:

```
Dear @customer.name@,

Your order total is @total@.
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

