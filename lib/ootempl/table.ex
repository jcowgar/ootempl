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

  import Ootempl.Xml

  alias Ootempl.Placeholder

  require Record

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
      |> Enum.map(fn placeholder -> hd(placeholder.path) end)
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

  @doc """
  Duplicates template rows for each item in a list with proper data scoping.

  This is the core transformation for dynamic table generation. It takes a set of
  template rows (which may be a single row or multiple consecutive rows referencing
  the same list), clones them for each item in the list data, and creates scoped
  data contexts for each duplicated row group.

  ## Parameters

    - `template_rows` - List of row XML elements that form the template (1+ consecutive rows)
    - `list_key` - The key in the data structure that references the list
    - `data` - The full data structure containing both the list and parent context

  ## Returns

    - A list of tuples `{row_element, scoped_data}` where each row is paired with
      its corresponding data context for placeholder replacement

  ## Examples

      # Single template row
      template_rows = [row_with_placeholder]
      list_key = "claims"
      data = %{"first_name" => "John", "claims" => [%{"id" => 1}, %{"id" => 2}]}

      duplicate_rows(template_rows, list_key, data)
      # => [
      #   {cloned_row1, %{"first_name" => "John", "id" => 1}},
      #   {cloned_row2, %{"first_name" => "John", "id" => 2}}
      # ]

      # Multi-row template
      template_rows = [header_row, detail_row]
      list_key = "orders"
      data = %{"company" => "Acme", "orders" => [%{"id" => 100}, %{"id" => 200}]}

      duplicate_rows(template_rows, list_key, data)
      # => [
      #   {cloned_header1, %{"company" => "Acme", "id" => 100}},
      #   {cloned_detail1, %{"company" => "Acme", "id" => 100}},
      #   {cloned_header2, %{"company" => "Acme", "id" => 200}},
      #   {cloned_detail2, %{"company" => "Acme", "id" => 200}}
      # ]

      # Empty list
      duplicate_rows(template_rows, "claims", %{"claims" => []})
      # => []
  """
  @spec duplicate_rows([Ootempl.Xml.xml_element()], String.t(), map()) ::
          [{Ootempl.Xml.xml_element(), map()}]
  def duplicate_rows(template_rows, list_key, data)
      when is_list(template_rows) and is_binary(list_key) and is_map(data) do
    # Get the list data
    list_data = Map.get(data, list_key, [])

    # Create parent data (everything except the list)
    parent_data = Map.delete(data, list_key)

    # For each list item, clone all template rows and scope data
    Enum.flat_map(list_data, fn list_item ->
      # Create scoped data with list item nested under list key
      scoped_data = Map.put(parent_data, list_key, list_item)

      # Clone each template row and pair with scoped data
      Enum.map(template_rows, fn row ->
        {clone_row(row), scoped_data}
      end)
    end)
  end

  @spec clone_row(Ootempl.Xml.xml_element()) :: Ootempl.Xml.xml_element()
  defp clone_row(row_element) do
    clone_element(row_element)
  end


  @doc """
  Inserts duplicated rows into a table at the specified position.

  Replaces the template rows in the table with the duplicated rows. The position
  should be the index of the first template row in the table's row list.

  ## Parameters

    - `table_element` - The table XML element
    - `duplicated_rows` - List of row XML elements to insert
    - `position` - Zero-based index where template rows start

  ## Returns

    - Updated table XML element with duplicated rows inserted

  ## Examples

      table = find_tables(doc) |> hd()
      duplicated = duplicate_rows(template_rows, "claims", data)
      rows_only = Enum.map(duplicated, fn {row, _data} -> row end)

      updated_table = insert_rows(table, rows_only, 1)
  """
  @spec insert_rows(Ootempl.Xml.xml_element(), [Ootempl.Xml.xml_element()], non_neg_integer()) ::
          Ootempl.Xml.xml_element()
  def insert_rows(table_element, duplicated_rows, position)
      when is_list(duplicated_rows) and is_integer(position) and position >= 0 do
    content = xmlElement(table_element, :content)

    # Find all row indices in the table's content
    row_positions = find_row_positions(content)

    if position >= length(row_positions) do
      # Position out of bounds, return table unchanged
      table_element
    else
      # Get the actual content index for this row position
      content_index = Enum.at(row_positions, position)

      # Split content at insertion point
      {before, after_with_template} = Enum.split(content, content_index)

      # Combine: before + duplicated rows + after (without template row)
      new_content = before ++ duplicated_rows ++ after_with_template

      xmlElement(table_element, content: new_content)
    end
  end

  @doc """
  Removes template rows from a table.

  Deletes the specified template rows from the table's content. This is typically
  called after duplicated rows have been inserted to clean up the original template.

  ## Parameters

    - `table_element` - The table XML element
    - `template_rows` - List of template row XML elements to remove

  ## Returns

    - Updated table XML element with template rows removed

  ## Examples

      table = find_tables(doc) |> hd()
      template_rows = [row1, row2]

      updated_table = remove_template_rows(table, template_rows)
  """
  @spec remove_template_rows(Ootempl.Xml.xml_element(), [Ootempl.Xml.xml_element()]) ::
          Ootempl.Xml.xml_element()
  def remove_template_rows(table_element, template_rows) when is_list(template_rows) do
    content = xmlElement(table_element, :content)

    # Remove template rows from content by filtering them out
    # We compare by object identity (reference equality)
    new_content = Enum.reject(content, fn node -> node in template_rows end)

    xmlElement(table_element, content: new_content)
  end

  # Private functions

  @spec find_tables_recursive(Ootempl.Xml.xml_element(), [Ootempl.Xml.xml_element()]) ::
          [Ootempl.Xml.xml_element()]
  defp find_tables_recursive(element, acc) do
    # Check if this element is a table
    acc =
      if xmlElement(element, :name) |> Atom.to_string() == "w:tbl" do
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
    element
    |> find_elements_recursive_impl(target_name, [])
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

  @spec clone_element(Ootempl.Xml.xml_element() | Ootempl.Xml.xml_text()) ::
          Ootempl.Xml.xml_element() | Ootempl.Xml.xml_text()
  defp clone_element(element) do
    cond do
      Record.is_record(element, :xmlElement) ->
        # Clone all content recursively
        content = xmlElement(element, :content)
        cloned_content = Enum.map(content, &clone_element/1)

        # Clone attributes
        attributes = xmlElement(element, :attributes)
        cloned_attributes = Enum.map(attributes, &clone_attribute/1)

        # Create new element with cloned content and attributes
        xmlElement(element,
          content: cloned_content,
          attributes: cloned_attributes
        )

      Record.is_record(element, :xmlText) ->
        # Text nodes can be copied directly (their value is immutable)
        element

      true ->
        # Other node types (comments, etc.) - return as-is
        element
    end
  end

  @spec clone_attribute(Ootempl.Xml.xml_attribute()) :: Ootempl.Xml.xml_attribute()
  defp clone_attribute(attribute) do
    # Attributes are small records, we can just return them
    # (their values are immutable charlists/atoms)
    attribute
  end

  @spec find_row_positions([Ootempl.Xml.xml_node()]) :: [non_neg_integer()]
  defp find_row_positions(content) do
    content
    |> Enum.with_index()
    |> Enum.filter(fn {node, _index} ->
      Record.is_record(node, :xmlElement) && xmlElement(node, :name) == :"w:tr"
    end)
    |> Enum.map(fn {_node, index} -> index end)
  end
end
