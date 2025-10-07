defmodule Ootempl.Conditional do
  @moduledoc """
  Detects and parses conditional markers in text for conditional section processing.

  Conditional markers allow showing or hiding document sections based on data conditions.
  Markers follow the syntax:
  - `@if:variable@` - Start of conditional section
  - `@endif@` - End of conditional section

  Markers are case-insensitive and support nested data paths using dot notation.

  ## Examples

      iex> Ootempl.Conditional.detect_conditionals("Hello @if:name@ world @endif@")
      [
        %{type: :if, condition: "name", path: ["name"], position: 6},
        %{type: :endif, condition: nil, path: nil, position: 22}
      ]

      iex> Ootempl.Conditional.detect_conditionals("@if:customer.active@ content @endif@")
      [
        %{type: :if, condition: "customer.active", path: ["customer", "active"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 29}
      ]
  """

  require Record

  @type conditional :: %{
          type: :if | :endif,
          condition: String.t() | nil,
          path: [String.t()] | nil,
          position: integer()
        }

  @if_pattern ~r/@if:([a-zA-Z_][a-zA-Z0-9_.]*)@/i
  @endif_pattern ~r/@endif@/i

  @doc """
  Detects all conditional markers in the given text.

  Returns a list of conditional markers in order of appearance with their positions.

  ## Parameters

  - `text` - The text to scan for conditional markers

  ## Returns

  A list of conditional maps, each containing:
  - `:type` - Either `:if` or `:endif`
  - `:condition` - The condition variable (only for `:if` markers)
  - `:path` - Parsed path segments (only for `:if` markers)
  - `:position` - Character position in the text

  ## Examples

      iex> Ootempl.Conditional.detect_conditionals("@if:active@content@endif@")
      [
        %{type: :if, condition: "active", path: ["active"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 18}
      ]

      iex> Ootempl.Conditional.detect_conditionals("no markers here")
      []
  """
  @spec detect_conditionals(String.t()) :: [conditional()]
  def detect_conditionals(text) when is_binary(text) do
    if_markers = find_if_markers(text)
    endif_markers = find_endif_markers(text)

    Enum.sort_by(if_markers ++ endif_markers, & &1.position)
  end

  @doc """
  Parses a condition string to extract the variable path.

  Supports dot notation for nested data paths.

  ## Parameters

  - `condition` - The condition variable string (e.g., "customer.active")

  ## Returns

  A list of path segments.

  ## Examples

      iex> Ootempl.Conditional.parse_condition("active")
      ["active"]

      iex> Ootempl.Conditional.parse_condition("customer.active")
      ["customer", "active"]

      iex> Ootempl.Conditional.parse_condition("user.profile.name")
      ["user", "profile", "name"]
  """
  @spec parse_condition(String.t()) :: [String.t()]
  def parse_condition(condition) when is_binary(condition) do
    String.split(condition, ".")
  end

  @doc """
  Validates that all conditional markers are properly paired.

  Ensures each `@if@` has a corresponding `@endif@` and detects orphaned markers.

  ## Parameters

  - `conditionals` - List of conditional markers from `detect_conditionals/1`

  ## Returns

  - `:ok` if all markers are properly paired
  - `{:error, reason}` if validation fails

  ## Examples

      iex> Ootempl.Conditional.validate_pairs([
      ...>   %{type: :if, condition: "name", path: ["name"], position: 0},
      ...>   %{type: :endif, condition: nil, path: nil, position: 10}
      ...> ])
      :ok

      iex> Ootempl.Conditional.validate_pairs([
      ...>   %{type: :if, condition: "name", path: ["name"], position: 0}
      ...> ])
      {:error, "Unmatched @if:name@ at position 0"}

      iex> Ootempl.Conditional.validate_pairs([
      ...>   %{type: :endif, condition: nil, path: nil, position: 0}
      ...> ])
      {:error, "Orphan @endif@ at position 0 (no matching @if@)"}
  """
  @spec validate_pairs([conditional()]) :: :ok | {:error, String.t()}
  def validate_pairs(conditionals) when is_list(conditionals) do
    validate_pairs_recursive(conditionals, [])
  end

  @doc """
  Evaluates whether a value is truthy according to conditional logic rules.

  Values considered falsy:
  - `nil`
  - `false`
  - Empty string `""`
  - Integer `0`
  - Float `0.0`

  All other values are considered truthy.

  ## Parameters

  - `value` - The value to evaluate

  ## Returns

  Boolean indicating if the value is truthy.

  ## Examples

      iex> Ootempl.Conditional.truthy?(true)
      true

      iex> Ootempl.Conditional.truthy?(false)
      false

      iex> Ootempl.Conditional.truthy?(nil)
      false

      iex> Ootempl.Conditional.truthy?("")
      false

      iex> Ootempl.Conditional.truthy?(0)
      false

      iex> Ootempl.Conditional.truthy?(0.0)
      false

      iex> Ootempl.Conditional.truthy?("hello")
      true

      iex> Ootempl.Conditional.truthy?(1)
      true

      iex> Ootempl.Conditional.truthy?([])
      true
  """
  @spec truthy?(term()) :: boolean()
  def truthy?(nil), do: false
  def truthy?(false), do: false
  def truthy?(""), do: false
  def truthy?(0), do: false
  def truthy?(value) when is_float(value) and value == 0.0, do: false
  def truthy?(_), do: true

  @doc """
  Evaluates a conditional expression by checking if the data path resolves to a truthy value.

  Uses `Ootempl.DataAccess.get_value/2` for case-insensitive nested data access,
  then evaluates the result using truthiness rules.

  ## Parameters

  - `path` - List of path segments to navigate (e.g., `["customer", "active"]`)
  - `data` - The data map to evaluate against

  ## Returns

  - `{:ok, true}` if the condition evaluates to truthy
  - `{:ok, false}` if the condition evaluates to falsy
  - `{:error, reason}` if the path cannot be resolved

  ## Examples

      iex> Ootempl.Conditional.evaluate_condition(["active"], %{"active" => true})
      {:ok, true}

      iex> Ootempl.Conditional.evaluate_condition(["active"], %{"active" => false})
      {:ok, false}

      iex> Ootempl.Conditional.evaluate_condition(["count"], %{"count" => 0})
      {:ok, false}

      iex> Ootempl.Conditional.evaluate_condition(["count"], %{"count" => 5})
      {:ok, true}

      iex> Ootempl.Conditional.evaluate_condition(["name"], %{"name" => ""})
      {:ok, false}

      iex> Ootempl.Conditional.evaluate_condition(["name"], %{"name" => "John"})
      {:ok, true}

      iex> Ootempl.Conditional.evaluate_condition(["customer", "active"], %{"customer" => %{"active" => true}})
      {:ok, true}

      iex> Ootempl.Conditional.evaluate_condition(["missing"], %{"name" => "John"})
      {:error, {:path_not_found, ["missing"]}}
  """
  @spec evaluate_condition([String.t()], map()) :: {:ok, boolean()} | {:error, term()}
  def evaluate_condition(path, data) when is_list(path) and is_map(data) do
    case Ootempl.DataAccess.get_value(data, path) do
      {:ok, string_value} ->
        # Convert string value back to original type for truthiness evaluation
        result = evaluate_string_value(string_value)
        {:ok, result}

      {:error, :nil_value} ->
        {:ok, false}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Finds section boundaries in an XML document for a conditional section.

  Locates the paragraph containing the `@if@` marker (start boundary) and the
  paragraph containing the `@endif@` marker (end boundary).

  ## Parameters

  - `xml_element` - The XML element to search within
  - `if_marker` - The full if marker text to find (e.g., "@if:active@")
  - `endif_marker` - The endif marker text to find (e.g., "@endif@")

  ## Returns

  - `{:ok, {start_paragraph, end_paragraph}}` if both boundaries found
  - `{:error, :if_marker_not_found}` if the if marker is not found
  - `{:error, :endif_marker_not_found}` if the endif marker is not found

  ## Examples

      # See integration tests for XML examples
  """
  @spec find_section_boundaries(Ootempl.Xml.xml_element(), String.t(), String.t()) ::
          {:ok, {Ootempl.Xml.xml_element(), Ootempl.Xml.xml_element()}}
          | {:error, :if_marker_not_found | :endif_marker_not_found}
  def find_section_boundaries(xml_element, if_marker, endif_marker) do
    case {find_paragraph_with_text(xml_element, if_marker), find_paragraph_with_text(xml_element, endif_marker)} do
      {{:ok, start_para}, {:ok, end_para}} ->
        {:ok, {start_para, end_para}}

      {{:error, :not_found}, _} ->
        {:error, :if_marker_not_found}

      {_, {:error, :not_found}} ->
        {:error, :endif_marker_not_found}
    end
  end

  @doc """
  Collects all XML nodes between two boundary nodes, inclusive.

  Returns all nodes from the start node to the end node, including both boundaries.
  Handles sections spanning single or multiple paragraphs.

  ## Parameters

  - `xml_element` - The XML element containing the section
  - `start_node` - The starting boundary node
  - `end_node` - The ending boundary node

  ## Returns

  - `{:ok, nodes}` - List of all nodes in the section (inclusive of boundaries)
  - `{:error, :boundaries_not_found}` - If start or end nodes are not found in the element

  ## Examples

      # See integration tests for XML examples
  """
  @spec collect_section_nodes(
          Ootempl.Xml.xml_element(),
          Ootempl.Xml.xml_element(),
          Ootempl.Xml.xml_element()
        ) ::
          {:ok, [Ootempl.Xml.xml_node()]} | {:error, :boundaries_not_found}
  def collect_section_nodes(xml_element, start_node, end_node) do
    import Ootempl.Xml

    children = xmlElement(xml_element, :content)

    case find_node_range(children, start_node, end_node) do
      {:ok, range} -> {:ok, range}
      :error -> {:error, :boundaries_not_found}
    end
  end

  # Private helper functions

  @spec find_if_markers(String.t()) :: [conditional()]
  defp find_if_markers(text) do
    @if_pattern
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{position, _length}, {cond_start, cond_length}] ->
      condition = String.slice(text, cond_start, cond_length)
      path = parse_condition(condition)

      %{
        type: :if,
        condition: condition,
        path: path,
        position: position
      }
    end)
  end

  @spec find_endif_markers(String.t()) :: [conditional()]
  defp find_endif_markers(text) do
    @endif_pattern
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{position, _length}] ->
      %{
        type: :endif,
        condition: nil,
        path: nil,
        position: position
      }
    end)
  end

  @spec validate_pairs_recursive([conditional()], [conditional()]) ::
          :ok | {:error, String.t()}
  defp validate_pairs_recursive([], []), do: :ok

  defp validate_pairs_recursive([], [unclosed | _]) do
    {:error, "Unmatched @if:#{unclosed.condition}@ at position #{unclosed.position}"}
  end

  defp validate_pairs_recursive([%{type: :if} = marker | rest], stack) do
    validate_pairs_recursive(rest, [marker | stack])
  end

  defp validate_pairs_recursive([%{type: :endif} = marker | _rest], []) do
    {:error, "Orphan @endif@ at position #{marker.position} (no matching @if@)"}
  end

  defp validate_pairs_recursive([%{type: :endif} | rest], [_if_marker | stack]) do
    validate_pairs_recursive(rest, stack)
  end

  # Helper to evaluate string values from DataAccess
  @spec evaluate_string_value(String.t()) :: boolean()
  defp evaluate_string_value("true"), do: true
  defp evaluate_string_value("false"), do: false
  defp evaluate_string_value("0"), do: false
  defp evaluate_string_value("0.0"), do: false
  defp evaluate_string_value(""), do: false
  defp evaluate_string_value(_), do: true

  # Helper to find a paragraph containing specific text
  @spec find_paragraph_with_text(Ootempl.Xml.xml_element(), String.t()) ::
          {:ok, Ootempl.Xml.xml_element()} | {:error, :not_found}
  defp find_paragraph_with_text(xml_element, text) do
    import Ootempl.Xml

    xml_element
    |> find_all_paragraphs()
    |> Enum.find(fn para -> paragraph_contains_text?(para, text) end)
    |> case do
      nil -> {:error, :not_found}
      para -> {:ok, para}
    end
  end

  # Helper to find all paragraph elements recursively
  @spec find_all_paragraphs(Ootempl.Xml.xml_element()) :: [Ootempl.Xml.xml_element()]
  defp find_all_paragraphs(xml_element) do
    import Ootempl.Xml

    children = xmlElement(xml_element, :content)

    Enum.flat_map(children, &extract_paragraphs_from_node/1)
  end

  # Helper to extract paragraphs from a single node
  @spec extract_paragraphs_from_node(Ootempl.Xml.xml_node()) :: [Ootempl.Xml.xml_element()]
  defp extract_paragraphs_from_node(node) do
    import Ootempl.Xml

    if Record.is_record(node, :xmlElement) do
      name = xmlElement(node, :name)

      # Found a paragraph
      if name == :"w:p" do
        [node]
      else
        # Recurse into other elements
        find_all_paragraphs(node)
      end
    else
      []
    end
  end

  # Helper to check if a paragraph contains specific text
  @spec paragraph_contains_text?(Ootempl.Xml.xml_element(), String.t()) :: boolean()
  defp paragraph_contains_text?(paragraph, text) do
    import Ootempl.Xml

    paragraph
    |> extract_all_text()
    |> String.contains?(text)
  end

  # Helper to extract all text from an element recursively
  @spec extract_all_text(Ootempl.Xml.xml_element()) :: String.t()
  defp extract_all_text(element) do
    import Ootempl.Xml

    children = xmlElement(element, :content)

    Enum.map_join(children, fn node ->
      cond do
        Record.is_record(node, :xmlText) ->
          node |> xmlText(:value) |> List.to_string()

        Record.is_record(node, :xmlElement) ->
          extract_all_text(node)

        true ->
          ""
      end
    end)
  end

  # Helper to find nodes between start and end boundaries
  @spec find_node_range(
          [Ootempl.Xml.xml_node()],
          Ootempl.Xml.xml_element(),
          Ootempl.Xml.xml_element()
        ) ::
          {:ok, [Ootempl.Xml.xml_node()]} | :error
  defp find_node_range(nodes, start_node, end_node) do
    start_index = Enum.find_index(nodes, &(&1 == start_node))
    end_index = Enum.find_index(nodes, &(&1 == end_node))

    case {start_index, end_index} do
      {nil, _} -> :error
      {_, nil} -> :error
      {start_idx, end_idx} when start_idx <= end_idx -> {:ok, Enum.slice(nodes, start_idx..end_idx)}
      _ -> :error
    end
  end
end
