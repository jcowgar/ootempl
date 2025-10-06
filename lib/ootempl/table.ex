defmodule Ootempl.Table do
  @moduledoc """
  Table structure detection and analysis for Word documents.

  This module provides functionality to detect Word tables in XML, extract rows,
  analyze placeholders within table cells, and identify template rows based on
  whether they reference list data.

  ## Template Row Detection

  Template rows are identified by analyzing placeholders in each row:
  - If a placeholder references a list in the data structure (e.g., `@claims.id@`
    where `claims` is a list), the row is considered a template row
  - Multiple consecutive rows referencing the same list are grouped as multi-row templates
  - If a row references multiple different lists, an error is returned

  ## Word XML Structure

  Tables in Word XML follow this structure:

      <w:tbl>
        <w:tr>  <!-- table row -->
          <w:tc>  <!-- table cell -->
            <w:p>  <!-- paragraph -->
              <w:r><w:t>@claims.id@</w:t></w:r>
            </w:p>
          </w:tc>
        </w:tr>
      </w:tbl>

  ## Examples

      # Find all tables in document
      tables = Ootempl.Table.find_tables(xml_doc)

      # Extract rows from a table
      rows = Ootempl.Table.extract_rows(table)

      # Analyze a row to determine if it's a template
      data = %{"claims" => [%{"id" => 1}, %{"id" => 2}]}
      result = Ootempl.Table.analyze_row(row, data)
      # => {:ok, %{row: row, template?: true, list_key: "claims", placeholders: [...]}}

      # Group consecutive template rows
      grouped = Ootempl.Table.group_template_rows(rows, data)
  """

  require Record
  import Ootempl.Xml
  alias Ootempl.Placeholder

  @type row_analysis :: %{
          row: Ootempl.Xml.xml_element(),
          template?: boolean(),
          list_key: String.t() | nil,
          placeholders: [Placeholder.placeholder()]
        }

  @doc """
  Finds all table elements in the given XML document.

  Recursively searches for `<w:tbl>` elements (Word table elements) in the XML tree.

  ## Parameters

    - `xml_element` - The XML element to search (typically the document root)

  ## Returns

    - A list of table XML elements

  ## Examples

      tables = Ootempl.Table.find_tables(doc)
      # => [table1, table2, ...]
  """
  @spec find_tables(Ootempl.Xml.xml_element()) :: [Ootempl.Xml.xml_element()]
  def find_tables(xml_element) do
    find_tables_recursive(xml_element, [])
  end

  @doc """
  Extracts all row elements from a table.

  Finds all `<w:tr>` (Word table row) elements within a table.

  ## Parameters

    - `table_element` - The table XML element

  ## Returns

    - A list of row XML elements

  ## Examples

      rows = Ootempl.Table.extract_rows(table)
      # => [row1, row2, row3, ...]
  """
  @spec extract_rows(Ootempl.Xml.xml_element()) :: [Ootempl.Xml.xml_element()]
  def extract_rows(table_element) do
    find_elements_recursive(table_element, :"w:tr")
  end

  @doc """
  Analyzes a table row to determine if it's a template row.

  Examines all placeholders in the row's cells and checks if any reference list data.
  A row is a template row if it contains placeholders that reference a list in the
  data structure.

  ## Parameters

    - `row_element` - The row XML element to analyze
    - `data` - The data structure to check against

  ## Returns

    - `{:ok, analysis}` - Row analysis with template status and list reference
    - `{:error, :multiple_lists}` - Row references multiple different lists (conflict)

  ## Examples

      # Regular row (no list reference)
      data = %{"name" => "John"}
      Ootempl.Table.analyze_row(row, data)
      # => {:ok, %{row: row, template?: false, list_key: nil, placeholders: [...]}}

      # Template row (references list)
      data = %{"claims" => [%{"id" => 1}]}
      Ootempl.Table.analyze_row(row_with_claims, data)
      # => {:ok, %{row: row, template?: true, list_key: "claims", placeholders: [...]}}

      # Conflict (multiple lists)
      data = %{"claims" => [...], "orders" => [...]}
      Ootempl.Table.analyze_row(row_with_both, data)
      # => {:error, :multiple_lists}
  """
  @spec analyze_row(Ootempl.Xml.xml_element(), map()) ::
          {:ok, row_analysis()} | {:error, :multiple_lists}
  def analyze_row(row_element, data) do
    # Extract all text from row cells
    text = extract_row_text(row_element)

    # Detect all placeholders in the row
    placeholders = Placeholder.detect(text)

    # Find unique list references
    list_keys =
      placeholders
      |> Enum.map(fn placeholder -> placeholder.path |> hd() end)
      |> Enum.filter(fn key -> list_reference?(key, data) end)
      |> Enum.uniq()

    case list_keys do
      [] ->
        # No list references - regular row
        {:ok,
         %{
           row: row_element,
           template?: false,
           list_key: nil,
           placeholders: placeholders
         }}

      [single_list] ->
        # Single list reference - template row
        {:ok,
         %{
           row: row_element,
           template?: true,
           list_key: single_list,
           placeholders: placeholders
         }}

      _multiple ->
        # Multiple different lists - conflict
        {:error, :multiple_lists}
    end
  end

  @doc """
  Groups consecutive template rows that reference the same list.

  Analyzes all rows and groups consecutive template rows that reference the same
  list key together. Non-template rows and template rows referencing different
  lists break the grouping.

  ## Parameters

    - `rows` - List of row XML elements
    - `data` - The data structure to check against

  ## Returns

    - `{:ok, grouped_analyses}` - List of row analyses with grouping information
    - `{:error, {:multiple_lists, row}}` - A row references multiple lists

  ## Examples

      rows = [regular_row, template_row1, template_row2, regular_row2]
      data = %{"claims" => [...]}
      Ootempl.Table.group_template_rows(rows, data)
      # => {:ok, [
      #      %{template?: false, ...},
      #      %{template?: true, list_key: "claims", ...},
      #      %{template?: true, list_key: "claims", ...},
      #      %{template?: false, ...}
      #    ]}
  """
  @spec group_template_rows([Ootempl.Xml.xml_element()], map()) ::
          {:ok, [row_analysis()]} | {:error, {:multiple_lists, Ootempl.Xml.xml_element()}}
  def group_template_rows(rows, data) do
    # Analyze each row
    results =
      Enum.map(rows, fn row ->
        case analyze_row(row, data) do
          {:ok, analysis} -> {:ok, analysis}
          {:error, :multiple_lists} -> {:error, {:multiple_lists, row}}
        end
      end)

    # Check if any errors occurred
    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, Enum.map(results, fn {:ok, analysis} -> analysis end)}
      error -> error
    end
  end

  @doc """
  Checks if a data key references a list.

  Looks up the key in the data structure and determines if the value is a list.

  ## Parameters

    - `key` - The data key to check (first segment of placeholder path)
    - `data` - The data structure to check

  ## Returns

    - `true` if the key exists and its value is a list
    - `false` otherwise

  ## Examples

      data = %{
        "name" => "John",
        "claims" => [%{"id" => 1}, %{"id" => 2}]
      }

      Ootempl.Table.list_reference?("name", data)
      # => false

      Ootempl.Table.list_reference?("claims", data)
      # => true

      Ootempl.Table.list_reference?("unknown", data)
      # => false
  """
  @spec list_reference?(String.t(), map()) :: boolean()
  def list_reference?(key, data) when is_binary(key) and is_map(data) do
    case Map.get(data, key) do
      value when is_list(value) -> true
      _ -> false
    end
  end

  # Private functions

  @spec find_tables_recursive(Ootempl.Xml.xml_element(), [Ootempl.Xml.xml_element()]) ::
          [Ootempl.Xml.xml_element()]
  defp find_tables_recursive(element, acc) do
    # Check if this element is a table
    acc =
      if element_name(element) == "w:tbl" do
        [element | acc]
      else
        acc
      end

    # Recursively search children
    children = xmlElement(element, :content)

    children
    |> Enum.filter(&Record.is_record(&1, :xmlElement))
    |> Enum.reduce(acc, fn child, acc -> find_tables_recursive(child, acc) end)
    |> Enum.reverse()
  end

  @spec find_elements_recursive(Ootempl.Xml.xml_element(), atom()) ::
          [Ootempl.Xml.xml_element()]
  defp find_elements_recursive(element, target_name) do
    find_elements_recursive_impl(element, target_name, [])
    |> Enum.reverse()
  end

  @spec find_elements_recursive_impl(
          Ootempl.Xml.xml_element(),
          atom(),
          [Ootempl.Xml.xml_element()]
        ) :: [Ootempl.Xml.xml_element()]
  defp find_elements_recursive_impl(element, target_name, acc) do
    # Check if this element matches
    acc =
      if xmlElement(element, :name) == target_name do
        [element | acc]
      else
        acc
      end

    # Recursively search children
    children = xmlElement(element, :content)

    children
    |> Enum.filter(&Record.is_record(&1, :xmlElement))
    |> Enum.reduce(acc, fn child, acc ->
      find_elements_recursive_impl(child, target_name, acc)
    end)
  end

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
end
