defmodule Ootempl.Placeholder do
  @moduledoc """
  Detects and parses placeholder variables in text.

  Placeholders follow the format `@variable_name@` and support dot notation
  for nested data access (e.g., `@customer.name@`, `@order.items.0.price@`).

  ## Examples

      iex> Ootempl.Placeholder.detect("Hello @name@!")
      [%{original: "@name@", variable: "name", path: ["name"]}]

      iex> Ootempl.Placeholder.detect("@customer.name@ ordered @product.title@")
      [
        %{original: "@customer.name@", variable: "customer.name", path: ["customer", "name"]},
        %{original: "@product.title@", variable: "product.title", path: ["product", "title"]}
      ]

      iex> Ootempl.Placeholder.detect("No placeholders here")
      []
  """

  @placeholder_regex ~r/@([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_0-9][a-zA-Z0-9_]*)*)@/

  @type placeholder :: %{
          original: String.t(),
          variable: String.t(),
          path: [String.t()]
        }

  @doc """
  Detects all placeholders in the given text.

  Returns a list of placeholder maps containing the original placeholder text,
  the variable name, and the parsed path segments.

  ## Parameters

    - `text` - The text to scan for placeholders

  ## Returns

    - A list of placeholder maps

  ## Examples

      iex> Ootempl.Placeholder.detect("Hello @name@")
      [%{original: "@name@", variable: "name", path: ["name"]}]

      iex> Ootempl.Placeholder.detect("@a.b.c@")
      [%{original: "@a.b.c@", variable: "a.b.c", path: ["a", "b", "c"]}]
  """
  @spec detect(String.t()) :: [placeholder()]
  def detect(text) when is_binary(text) do
    @placeholder_regex
    |> Regex.scan(text, return: :index)
    |> Enum.reduce({[], nil}, fn [{start, length}, {var_start, var_length}], {acc, last_end} ->
      # Check if preceded by @ that's NOT from the previous match's closing @
      preceded_by_invalid_at =
        start > 0 and String.at(text, start - 1) == "@" and last_end != start

      if preceded_by_invalid_at do
        {acc, last_end}
      else
        variable = String.slice(text, var_start, var_length)
        original = @placeholder_regex |> Regex.run(String.slice(text, start..-1//1)) |> hd()

        placeholder = %{
          original: original,
          variable: variable,
          path: parse_path(variable)
        }

        {[placeholder | acc], start + length}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  @doc """
  Parses a variable string into path segments.

  Splits the variable name by dots to support nested data access.

  ## Parameters

    - `variable` - The variable name to parse (without @ symbols)

  ## Returns

    - A list of path segments

  ## Examples

      iex> Ootempl.Placeholder.parse_path("name")
      ["name"]

      iex> Ootempl.Placeholder.parse_path("customer.name")
      ["customer", "name"]

      iex> Ootempl.Placeholder.parse_path("order.items.0.price")
      ["order", "items", "0", "price"]
  """
  @spec parse_path(String.t()) :: [String.t()]
  def parse_path(variable) when is_binary(variable) do
    String.split(variable, ".")
  end

  @doc """
  Checks if the given text is a valid placeholder.

  ## Parameters

    - `text` - The text to validate

  ## Returns

    - `true` if the text is a valid placeholder, `false` otherwise

  ## Examples

      iex> Ootempl.Placeholder.valid?("@name@")
      true

      iex> Ootempl.Placeholder.valid?("@customer.name@")
      true

      iex> Ootempl.Placeholder.valid?("@incomplete")
      false

      iex> Ootempl.Placeholder.valid?("not a placeholder")
      false
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(text) when is_binary(text) do
    Regex.match?(@placeholder_regex, text) and
      String.starts_with?(text, "@") and
      String.ends_with?(text, "@") and
      not String.starts_with?(text, "@@") and
      not String.ends_with?(text, "@@")
  end
end
