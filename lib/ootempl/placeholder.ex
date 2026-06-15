defmodule Ootempl.Placeholder do
  @moduledoc """
  Detects and parses placeholder variables in text.

  Placeholders follow the format `{{variable_name}}` and support dot notation
  for nested data access (e.g., `{{customer.name}}`, `{{order.items.0.price}}`).

  ## Filters

  A placeholder may declare a chain of formatting filters after the variable,
  separated by `|` (Jinja/Liquid style). Each filter has a name and optional
  comma-separated arguments introduced with `:`:

      {{ invoice.date | date: "%Y-%m-%d" }}
      {{ total | round: 2 | currency: "USD" }}
      {{ name | upcase }}

  Whitespace around the variable, the `|` separators, and arguments is
  insignificant. Arguments may be double- or single-quoted strings, integers,
  or floats; bare words are treated as strings. See `Ootempl.Filters` for the
  built-in filters and how to register your own.

  ## Escaping

  To include literal `{{` or `}}` in your document, use `\\{{` or `\\}}`.

  ## Examples

      iex> Ootempl.Placeholder.detect("Hello {{name}}!")
      [%{original: "{{name}}", variable: "name", path: ["name"], filters: []}]

      iex> Ootempl.Placeholder.detect("{{customer.name}} ordered {{product.title}}")
      [
        %{original: "{{customer.name}}", variable: "customer.name", path: ["customer", "name"], filters: []},
        %{original: "{{product.title}}", variable: "product.title", path: ["product", "title"], filters: []}
      ]

      iex> Ootempl.Placeholder.detect("No placeholders here")
      []
  """

  # Group 1 captures the dotted variable path. Group 2 captures the optional
  # filter section (including its leading `|`). The path stays strict so that
  # block markers (`{{#x}}`, `{{/x}}`), conditionals (`{{if x}}`), and image
  # markers (`{{image:logo}}`) are NOT matched here. `[^{}]` keeps the filter
  # section from crossing into adjacent braces, so quoted arguments may not
  # contain `{` or `}`.
  @placeholder_regex ~r/(?<!\\)\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_0-9][a-zA-Z0-9_]*)*)\s*((?:\|[^{}]*)?)\}\}/

  @type filter :: %{name: String.t(), args: [term()]}

  @type placeholder :: %{
          original: String.t(),
          variable: String.t(),
          path: [String.t()],
          filters: [filter()]
        }

  @doc """
  Detects all placeholders in the given text.

  Returns a list of placeholder maps containing the original placeholder text,
  the variable name, the parsed path segments, and any parsed filters.

  Escaped placeholders (preceded by backslash) are not detected.

  ## Parameters

    - `text` - The text to scan for placeholders

  ## Returns

    - A list of placeholder maps

  ## Examples

      iex> Ootempl.Placeholder.detect("Hello {{name}}")
      [%{original: "{{name}}", variable: "name", path: ["name"], filters: []}]

      iex> Ootempl.Placeholder.detect("{{a.b.c}}")
      [%{original: "{{a.b.c}}", variable: "a.b.c", path: ["a", "b", "c"], filters: []}]

      iex> Ootempl.Placeholder.detect(~S({{date | date: "%Y-%m-%d"}}))
      [%{original: ~S({{date | date: "%Y-%m-%d"}}), variable: "date", path: ["date"], filters: [%{name: "date", args: ["%Y-%m-%d"]}]}]

      iex> Ootempl.Placeholder.detect("Escaped \\{{not_a_placeholder}}")
      []
  """
  @spec detect(String.t()) :: [placeholder()]
  def detect(text) when is_binary(text) do
    @placeholder_regex
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{start, length}, {var_start, var_length} | rest] ->
      # Use :binary.part/3 instead of String.slice/3 because Regex.scan
      # returns byte positions, not grapheme positions. String.slice uses
      # grapheme indices which causes misalignment when multi-byte UTF-8
      # characters (like em-dash, ®, smart quotes) are present in the text.
      variable = :binary.part(text, var_start, var_length)
      original = :binary.part(text, start, length)
      filter_section = extract_filter_section(text, rest)

      %{
        original: original,
        variable: variable,
        path: parse_path(variable),
        filters: parse_filters(filter_section)
      }
    end)
  end

  @spec extract_filter_section(String.t(), [{integer(), non_neg_integer()}]) :: String.t()
  defp extract_filter_section(text, [{f_start, f_length} | _]) when f_start >= 0 and f_length > 0 do
    :binary.part(text, f_start, f_length)
  end

  defp extract_filter_section(_text, _rest), do: ""

  @spec parse_path(String.t()) :: [String.t()]
  defp parse_path(variable) when is_binary(variable) do
    String.split(variable, ".")
  end

  # Parses the raw filter section (e.g. `| date: "%Y-%m-%d" | upcase`) into a
  # list of `%{name:, args:}` maps. Returns `[]` when there are no filters.
  @spec parse_filters(String.t()) :: [filter()]
  defp parse_filters(section) do
    section
    |> String.trim()
    |> String.trim_leading("|")
    |> split_top_level("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_filter/1)
  end

  @spec parse_filter(String.t()) :: filter()
  defp parse_filter(filter_str) do
    case split_top_level(filter_str, ":", 2) do
      [name] ->
        %{name: String.trim(name), args: []}

      [name, args_str] ->
        args =
          args_str
          |> split_top_level(",")
          |> Enum.map(&parse_arg/1)

        %{name: String.trim(name), args: args}
    end
  end

  # Coerces a single argument token into a string, integer, or float. Quoted
  # tokens are always strings (quotes stripped); bare words are strings too.
  @spec parse_arg(String.t()) :: term()
  defp parse_arg(arg) do
    trimmed = String.trim(arg)

    if quoted?(trimmed, "\"") or quoted?(trimmed, "'") do
      String.slice(trimmed, 1, String.length(trimmed) - 2)
    else
      coerce_number(trimmed)
    end
  end

  @spec quoted?(String.t(), String.t()) :: boolean()
  defp quoted?(str, q) do
    String.length(str) >= 2 and String.starts_with?(str, q) and String.ends_with?(str, q)
  end

  @spec coerce_number(String.t()) :: term()
  defp coerce_number(str) do
    case Integer.parse(str) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(str) do
          {float, ""} -> float
          _ -> str
        end
    end
  end

  # Splits `str` on `delimiter` but only at the top level, i.e. ignoring
  # delimiters that appear inside single- or double-quoted spans. `limit`
  # caps the number of returned parts (the final part keeps the remainder).
  @spec split_top_level(String.t(), String.t(), pos_integer() | :infinity) :: [String.t()]
  defp split_top_level(str, delimiter, limit \\ :infinity) do
    do_split(String.graphemes(str), delimiter, limit, nil, "", [])
  end

  defp do_split([], _delim, _limit, _quote, current, acc) do
    Enum.reverse([current | acc])
  end

  # Reached the part limit: everything remaining stays in the current part.
  defp do_split(graphemes, _delim, limit, _quote, current, acc) when is_integer(limit) and length(acc) == limit - 1 do
    Enum.reverse([current <> Enum.join(graphemes) | acc])
  end

  defp do_split([g | rest], delim, limit, quote, current, acc) do
    cond do
      # Inside a quoted span: only the matching quote closes it.
      quote != nil ->
        new_quote = if g == quote, do: nil, else: quote
        do_split(rest, delim, limit, new_quote, current <> g, acc)

      g == "\"" or g == "'" ->
        do_split(rest, delim, limit, g, current <> g, acc)

      g == delim ->
        do_split(rest, delim, limit, nil, "", [current | acc])

      true ->
        do_split(rest, delim, limit, nil, current <> g, acc)
    end
  end
end
