defmodule Ootempl.Block do
  @moduledoc """
  Detects and parses block markers for hierarchical list iteration in tables.

  Block markers allow creating nested table structures where rows are repeated
  for each item in a list, with support for header/body/footer sections.

  Markers follow the syntax:
  - `{{#list_key}}` - Start iteration over a list
  - `{{/list_key}}` - End iteration block

  ## Table Structure Example

  Block markers are placed in dedicated rows that will be removed from output:

      | {{#revcode_data}} |             |             |  <- Marker row (removed)
      | {{revcode}}       | {{desc}}    | {{amount}}  |  <- Header row
      | {{#children}}     |             |             |  <- Marker row (removed)
      |                   | {{desc}}    | {{cost}}    |  <- Body row (repeated)
      | {{/children}}     |             |             |  <- Marker row (removed)
      |                   | Subtotal:   | {{subtotal}}|  <- Footer row
      | {{/revcode_data}} |             |             |  <- Marker row (removed)

  ## Data Scoping

  - Header/footer rows access parent item fields directly
  - Body rows access both parent and child fields
  - Child fields take precedence on name conflicts

  ## Examples

      iex> Ootempl.Block.detect_markers("{{#items}} content {{/items}}")
      [
        %{type: :open, list_key: "items", position: 0},
        %{type: :close, list_key: "items", position: 19}
      ]

      iex> Ootempl.Block.contains_markers?("{{#items}}")
      true

      iex> Ootempl.Block.contains_markers?("{{name}}")
      false
  """

  import Ootempl.Xml

  alias Ootempl.Placeholder

  require Record

  @type block_marker :: %{
          type: :open | :close,
          list_key: String.t(),
          position: integer()
        }

  @type block_structure :: %{
          list_key: String.t(),
          open_row_index: non_neg_integer(),
          close_row_index: non_neg_integer(),
          header_rows: [non_neg_integer()],
          body_block: block_structure() | nil,
          footer_rows: [non_neg_integer()]
        }

  @open_pattern ~r/(?<!\\)\{\{#([a-zA-Z_][a-zA-Z0-9_]*)\}\}/
  @close_pattern ~r/(?<!\\)\{\{\/([a-zA-Z_][a-zA-Z0-9_]*)\}\}/
  @any_marker_pattern ~r/(?<!\\)\{\{[#\/]([a-zA-Z_][a-zA-Z0-9_]*)\}\}/

  @doc """
  Detects all block markers in the given text.

  Returns a list of block markers in order of appearance with their positions.

  ## Parameters

  - `text` - The text to scan for block markers

  ## Returns

  A list of marker maps, each containing:
  - `:type` - Either `:open` or `:close`
  - `:list_key` - The list variable name
  - `:position` - Character position in the text

  ## Examples

      iex> Ootempl.Block.detect_markers("{{#items}}content{{/items}}")
      [
        %{type: :open, list_key: "items", position: 0},
        %{type: :close, list_key: "items", position: 17}
      ]

      iex> Ootempl.Block.detect_markers("no markers here")
      []
  """
  @spec detect_markers(String.t()) :: [block_marker()]
  def detect_markers(text) when is_binary(text) do
    open_markers = find_open_markers(text)
    close_markers = find_close_markers(text)

    Enum.sort_by(open_markers ++ close_markers, & &1.position)
  end

  @doc """
  Checks if the given text contains any block markers.

  This is a quick check to determine if block processing is needed.

  ## Parameters

  - `text` - The text to check

  ## Returns

  `true` if the text contains `{{#...}}` or `{{/...}}` markers, `false` otherwise.

  ## Examples

      iex> Ootempl.Block.contains_markers?("{{#items}}")
      true

      iex> Ootempl.Block.contains_markers?("{{name}}")
      false

      iex> Ootempl.Block.contains_markers?("plain text")
      false
  """
  @spec contains_markers?(String.t()) :: boolean()
  def contains_markers?(text) when is_binary(text) do
    Regex.match?(@any_marker_pattern, text)
  end

  @doc """
  Validates that all block markers are properly paired.

  Uses stack-based validation to ensure each `{{#key}}` has a corresponding
  `{{/key}}` and detects orphaned or mismatched markers.

  ## Parameters

  - `markers` - List of block markers from `detect_markers/1`

  ## Returns

  - `:ok` if all markers are properly paired
  - `{:error, reason}` if validation fails

  ## Examples

      iex> Ootempl.Block.validate_pairs([
      ...>   %{type: :open, list_key: "items", position: 0},
      ...>   %{type: :close, list_key: "items", position: 10}
      ...> ])
      :ok

      iex> Ootempl.Block.validate_pairs([
      ...>   %{type: :open, list_key: "items", position: 0}
      ...> ])
      {:error, "Unmatched {{#items}} at position 0"}

      iex> Ootempl.Block.validate_pairs([
      ...>   %{type: :close, list_key: "items", position: 0}
      ...> ])
      {:error, "Orphan {{/items}} at position 0 (no matching {{#items}})"}

      iex> Ootempl.Block.validate_pairs([
      ...>   %{type: :open, list_key: "items", position: 0},
      ...>   %{type: :close, list_key: "other", position: 10}
      ...> ])
      {:error, "Mismatched block: found {{/other}} at position 10, expected {{/items}}"}
  """
  @spec validate_pairs([block_marker()]) :: :ok | {:error, String.t()}
  def validate_pairs(markers) when is_list(markers) do
    validate_pairs_recursive(markers, [])
  end

  @doc """
  Parses the table structure to identify block boundaries and row categories.

  Analyzes table rows to build a block structure that identifies:
  - Which rows are marker-only rows (to be removed)
  - Which rows are header rows (before nested block)
  - Which rows form the body block (nested iteration)
  - Which rows are footer rows (after nested block)

  ## Parameters

  - `rows` - List of table row XML elements
  - `data` - The data map to validate list keys against

  ## Returns

  - `{:ok, block_structure}` with the parsed structure
  - `{:error, reason}` if parsing fails

  ## Examples

      # Single-level block
      {:ok, structure} = Block.parse_table_structure(rows, data)
      # => %{
      #   list_key: "items",
      #   open_row_index: 0,
      #   close_row_index: 2,
      #   header_rows: [1],
      #   body_block: nil,
      #   footer_rows: []
      # }
  """
  @spec parse_table_structure([Ootempl.Xml.xml_element()], map()) ::
          {:ok, block_structure()} | {:error, term()}
  def parse_table_structure(rows, data) when is_list(rows) and is_map(data) do
    # Extract text from each row and detect markers
    row_info =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {row, index} ->
        text = extract_row_text(row)
        markers = detect_markers(text)
        placeholders = Placeholder.detect(text)
        is_marker_only = is_marker_only_row?(markers, placeholders, text)

        %{
          index: index,
          row: row,
          text: text,
          markers: markers,
          placeholders: placeholders,
          marker_only: is_marker_only
        }
      end)

    # Find all markers with their row indices
    all_markers =
      row_info
      |> Enum.flat_map(fn info ->
        Enum.map(info.markers, fn marker ->
          Map.put(marker, :row_index, info.index)
        end)
      end)

    # Validate marker pairs
    case validate_pairs(all_markers) do
      :ok ->
        parse_block_structure(row_info, all_markers, data)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Expands a block structure with the provided data.

  For each item in the list:
  1. Clone header rows with parent item data
  2. If there's a nested body_block, recursively expand it
  3. Clone footer rows with parent item data

  Marker-only rows are excluded from the output.

  ## Parameters

  - `structure` - The block structure from `parse_table_structure/2`
  - `rows` - The original table rows
  - `data` - The data map containing the list to iterate

  ## Returns

  A list of `{row_element, scoped_data}` tuples ready for placeholder replacement.
  """
  @spec expand_block(block_structure(), [Ootempl.Xml.xml_element()], map()) ::
          [{Ootempl.Xml.xml_element(), map()}]
  def expand_block(structure, rows, data) when is_map(structure) and is_list(rows) and is_map(data) do
    list_key = structure.list_key
    list_data = get_list_data(data, list_key)

    # Create parent data (everything except the list)
    parent_data = Map.delete(data, list_key)

    # For each item in the list
    Enum.flat_map(list_data, fn item ->
      # Scope data: parent fields + current item fields
      scoped_data = merge_scoped_data(parent_data, item)

      # Expand header rows
      header_rows =
        structure.header_rows
        |> Enum.map(fn idx -> {clone_row(Enum.at(rows, idx)), scoped_data} end)

      # Expand body block (if any)
      body_rows =
        if structure.body_block do
          # For nested blocks, the list is within the current item
          nested_data = Map.put(scoped_data, structure.body_block.list_key, Map.get(item, structure.body_block.list_key, []))
          expand_nested_block(structure.body_block, rows, nested_data, scoped_data)
        else
          []
        end

      # Expand footer rows
      footer_rows =
        structure.footer_rows
        |> Enum.map(fn idx -> {clone_row(Enum.at(rows, idx)), scoped_data} end)

      header_rows ++ body_rows ++ footer_rows
    end)
  end

  @doc """
  Returns all row indices that should be removed from the original table.

  These are the marker-only rows that contain block markers but no data placeholders.
  """
  @spec marker_row_indices(block_structure()) :: [non_neg_integer()]
  def marker_row_indices(structure) do
    indices = [structure.open_row_index, structure.close_row_index]

    nested_indices =
      if structure.body_block do
        marker_row_indices(structure.body_block)
      else
        []
      end

    (indices ++ nested_indices) |> Enum.sort()
  end

  # Private functions

  @spec find_open_markers(String.t()) :: [block_marker()]
  defp find_open_markers(text) do
    @open_pattern
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{position, _length}, {key_start, key_length}] ->
      list_key = String.slice(text, key_start, key_length)

      %{
        type: :open,
        list_key: list_key,
        position: position
      }
    end)
  end

  @spec find_close_markers(String.t()) :: [block_marker()]
  defp find_close_markers(text) do
    @close_pattern
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{position, _length}, {key_start, key_length}] ->
      list_key = String.slice(text, key_start, key_length)

      %{
        type: :close,
        list_key: list_key,
        position: position
      }
    end)
  end

  @spec validate_pairs_recursive([block_marker()], [block_marker()]) ::
          :ok | {:error, String.t()}
  defp validate_pairs_recursive([], []), do: :ok

  defp validate_pairs_recursive([], [marker | _]) do
    {:error, "Unmatched {{##{marker.list_key}}} at position #{marker.position}"}
  end

  defp validate_pairs_recursive([%{type: :open} = marker | rest], stack) do
    validate_pairs_recursive(rest, [marker | stack])
  end

  defp validate_pairs_recursive([%{type: :close} = marker | _rest], []) do
    {:error, "Orphan {{/#{marker.list_key}}} at position #{marker.position} (no matching {{##{marker.list_key}}})"}
  end

  defp validate_pairs_recursive([%{type: :close} = close | rest], [open | stack_rest]) do
    if close.list_key == open.list_key do
      validate_pairs_recursive(rest, stack_rest)
    else
      {:error, "Mismatched block: found {{/#{close.list_key}}} at position #{close.position}, expected {{/#{open.list_key}}}"}
    end
  end

  @spec is_marker_only_row?([block_marker()], [Placeholder.placeholder()], String.t()) :: boolean()
  defp is_marker_only_row?(markers, placeholders, text) do
    # A row is marker-only if:
    # 1. It contains at least one block marker
    # 2. It has no data placeholders
    # 3. Any non-marker text is whitespace only
    has_markers = length(markers) > 0
    has_no_placeholders = Enum.empty?(placeholders)

    if has_markers and has_no_placeholders do
      # Remove all markers from text and check if only whitespace remains
      stripped =
        text
        |> String.replace(@open_pattern, "")
        |> String.replace(@close_pattern, "")
        |> String.trim()

      stripped == ""
    else
      false
    end
  end

  @spec parse_block_structure(
          [map()],
          [map()],
          map()
        ) :: {:ok, block_structure()} | {:error, term()}
  defp parse_block_structure(row_info, all_markers, data) do
    case all_markers do
      [] ->
        {:error, :no_block_markers}

      markers ->
        # Find the outermost block
        case find_outermost_block(markers) do
          {:ok, open_marker, close_marker} ->
            build_block_structure(row_info, markers, open_marker, close_marker, data)

          {:error, _} = error ->
            error
        end
    end
  end

  @spec find_outermost_block([map()]) :: {:ok, map(), map()} | {:error, term()}
  defp find_outermost_block(markers) do
    # The first open marker and its matching close marker form the outermost block
    case markers do
      [%{type: :open} = open | rest] ->
        case find_matching_close(rest, open.list_key, 1) do
          {:ok, close} -> {:ok, open, close}
          :error -> {:error, "No matching close marker for {{##{open.list_key}}}"}
        end

      _ ->
        {:error, "Block must start with an open marker"}
    end
  end

  @spec find_matching_close([map()], String.t(), non_neg_integer()) ::
          {:ok, map()} | :error
  defp find_matching_close([], _list_key, _depth), do: :error

  defp find_matching_close([%{type: :open, list_key: key} | rest], list_key, depth) when key == list_key do
    find_matching_close(rest, list_key, depth + 1)
  end

  defp find_matching_close([%{type: :close, list_key: key} = marker | _rest], list_key, 1) when key == list_key do
    {:ok, marker}
  end

  defp find_matching_close([%{type: :close, list_key: key} | rest], list_key, depth) when key == list_key do
    find_matching_close(rest, list_key, depth - 1)
  end

  defp find_matching_close([_ | rest], list_key, depth) do
    find_matching_close(rest, list_key, depth)
  end

  @spec build_block_structure(
          [map()],
          [map()],
          map(),
          map(),
          map()
        ) :: {:ok, block_structure()} | {:error, term()}
  defp build_block_structure(row_info, all_markers, open_marker, close_marker, data) do
    open_row_idx = open_marker.row_index
    close_row_idx = close_marker.row_index

    # Find rows between open and close markers (exclusive of marker rows)
    content_rows =
      row_info
      |> Enum.filter(fn info ->
        info.index > open_row_idx and info.index < close_row_idx
      end)

    # Check for nested block markers
    nested_markers =
      all_markers
      |> Enum.filter(fn m ->
        m.row_index > open_row_idx and m.row_index < close_row_idx
      end)

    case find_nested_block(nested_markers) do
      {:ok, nested_open, nested_close} ->
        # We have a nested block - split rows into header/body/footer
        header_indices =
          content_rows
          |> Enum.filter(fn info ->
            info.index > open_row_idx and info.index < nested_open.row_index and not info.marker_only
          end)
          |> Enum.map(& &1.index)

        footer_indices =
          content_rows
          |> Enum.filter(fn info ->
            info.index > nested_close.row_index and info.index < close_row_idx and not info.marker_only
          end)
          |> Enum.map(& &1.index)

        # Build nested block structure
        nested_result = build_block_structure(
          row_info,
          nested_markers,
          nested_open,
          nested_close,
          data
        )

        case nested_result do
          {:ok, nested_structure} ->
            {:ok,
             %{
               list_key: open_marker.list_key,
               open_row_index: open_row_idx,
               close_row_index: close_row_idx,
               header_rows: header_indices,
               body_block: nested_structure,
               footer_rows: footer_indices
             }}

          {:error, _} = error ->
            error
        end

      :none ->
        # No nested block - all content rows are "header" rows
        content_indices =
          content_rows
          |> Enum.filter(fn info -> not info.marker_only end)
          |> Enum.map(& &1.index)

        {:ok,
         %{
           list_key: open_marker.list_key,
           open_row_index: open_row_idx,
           close_row_index: close_row_idx,
           header_rows: content_indices,
           body_block: nil,
           footer_rows: []
         }}
    end
  end

  @spec find_nested_block([map()]) :: {:ok, map(), map()} | :none
  defp find_nested_block([]), do: :none

  defp find_nested_block(markers) do
    case markers do
      [%{type: :open} = open | rest] ->
        case find_matching_close(rest, open.list_key, 1) do
          {:ok, close} -> {:ok, open, close}
          :error -> :none
        end

      _ ->
        :none
    end
  end

  @spec expand_nested_block(block_structure(), [Ootempl.Xml.xml_element()], map(), map()) ::
          [{Ootempl.Xml.xml_element(), map()}]
  defp expand_nested_block(structure, rows, nested_data, parent_scope) do
    list_key = structure.list_key
    list_data = get_list_data(nested_data, list_key)

    # For each child item
    Enum.flat_map(list_data, fn child_item ->
      # Scope: parent fields + child fields (child overrides parent on conflict)
      scoped_data = merge_scoped_data(parent_scope, child_item)

      # Expand body rows (header_rows in nested context, since there's no further nesting)
      body_rows =
        structure.header_rows
        |> Enum.map(fn idx -> {clone_row(Enum.at(rows, idx)), scoped_data} end)

      # If there's deeper nesting, recurse
      deeper_rows =
        if structure.body_block do
          deeper_data = Map.put(scoped_data, structure.body_block.list_key, Map.get(child_item, structure.body_block.list_key, []))
          expand_nested_block(structure.body_block, rows, deeper_data, scoped_data)
        else
          []
        end

      footer_rows =
        structure.footer_rows
        |> Enum.map(fn idx -> {clone_row(Enum.at(rows, idx)), scoped_data} end)

      body_rows ++ deeper_rows ++ footer_rows
    end)
  end

  @spec get_list_data(map(), String.t()) :: [map()]
  defp get_list_data(data, list_key) do
    case Map.get(data, list_key) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  @spec merge_scoped_data(map(), map()) :: map()
  defp merge_scoped_data(parent, child) when is_map(parent) and is_map(child) do
    Map.merge(parent, child)
  end

  defp merge_scoped_data(parent, _child), do: parent

  @spec extract_row_text(Ootempl.Xml.xml_element()) :: String.t()
  defp extract_row_text(row_element) do
    extract_text_recursive(row_element)
  end

  @spec extract_text_recursive(Ootempl.Xml.xml_element() | Ootempl.Xml.xml_text()) :: String.t()
  defp extract_text_recursive(element) do
    cond do
      Record.is_record(element, :xmlElement) ->
        children = xmlElement(element, :content)
        Enum.map_join(children, &extract_text_recursive/1)

      Record.is_record(element, :xmlText) ->
        element
        |> xmlText(:value)
        |> List.to_string()

      true ->
        ""
    end
  end

  @spec clone_row(Ootempl.Xml.xml_element()) :: Ootempl.Xml.xml_element()
  defp clone_row(row_element) do
    clone_element(row_element)
  end

  @spec clone_element(Ootempl.Xml.xml_element() | Ootempl.Xml.xml_text()) ::
          Ootempl.Xml.xml_element() | Ootempl.Xml.xml_text()
  defp clone_element(element) do
    cond do
      Record.is_record(element, :xmlElement) ->
        content = xmlElement(element, :content)
        cloned_content = Enum.map(content, &clone_element/1)
        attributes = xmlElement(element, :attributes)
        cloned_attributes = Enum.map(attributes, &clone_attribute/1)

        xmlElement(element,
          content: cloned_content,
          attributes: cloned_attributes
        )

      Record.is_record(element, :xmlText) ->
        element

      true ->
        element
    end
  end

  @spec clone_attribute(Ootempl.Xml.xml_attribute()) :: Ootempl.Xml.xml_attribute()
  defp clone_attribute(attribute), do: attribute
end
