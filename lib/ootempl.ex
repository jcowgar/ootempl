defmodule Ootempl do
  @moduledoc """
  Office document templating library for Elixir.

  Ootempl enables programmatic manipulation of Microsoft Word documents (.docx)
  by replacing placeholders with dynamic content to generate customized documents
  from templates.

  ## Features

  - Load and parse .docx templates
  - Replace `@variable@` placeholders with dynamic content
  - Support nested data access with dot notation (`@customer.name@`)
  - Dynamic table row generation from list data
  - Multi-row table templates for complex layouts
  - Case-insensitive placeholder matching
  - Process headers, footers, footnotes, and endnotes
  - Replace placeholders in document properties (title, author, company)
  - Preserve Word formatting (bold, italic, fonts, table borders, shading)
  - Generate valid .docx output files
  - Comprehensive validation and error handling

  ## Basic Usage

  ### Simple Variable Replacement

  ```elixir
  # Render a template with placeholder replacement
  data = %{
    "name" => "John Doe",
    "customer" => %{"email" => "john@example.com"},
    "total" => 99.99
  }
  Ootempl.render("template.docx", data, "output.docx")
  #=> :ok
  ```

  ### Table Templates

  Table templates automatically duplicate rows based on list data. Template rows are
  identified by placeholders that reference list items.

  ```elixir
  # Simple table template
  data = %{
    "title" => "Claims Report",
    "claims" => [
      %{"id" => 5565, "amount" => 100.50},
      %{"id" => 5566, "amount" => 250.00}
    ],
    "total" => 350.50
  }
  Ootempl.render("invoice_template.docx", data, "invoice.docx")
  #=> :ok
  ```

  Template structure in Word document:
  ```
  | Claim ID       | Amount           |  ← Header (no list placeholders)
  | @claims.id@    | @claims.amount@  |  ← Template row (references "claims" list)
  | Total          | @total@          |  ← Footer (single value)
  ```

  Generated output:
  ```
  | Claim ID  | Amount  |
  | 5565      | 100.50  |
  | 5566      | 250.00  |
  | Total     | 350.50  |
  ```

  Multi-row templates are supported for complex table layouts:
  ```elixir
  data = %{
    "orders" => [
      %{"id" => 100, "product" => "Widget", "qty" => 5, "price" => 10.00},
      %{"id" => 101, "product" => "Gadget", "qty" => 3, "price" => 25.00}
    ]
  }
  ```

  Template with two rows per order:
  ```
  | Order @orders.id@              |  ← Row 1 of template
  | @orders.qty@x @orders.product@ @ $@orders.price@ each |  ← Row 2 of template
  ```

  Generated output duplicates both rows for each order:
  ```
  | Order 100           |
  | 5x Widget @ $10.00 each |
  | Order 101           |
  | 3x Gadget @ $25.00 each |
  ```

  ### Document Properties

  Placeholders in document metadata (title, author, company) are automatically replaced.
  Use this feature to populate document properties from your data.

  ```elixir
  # Template has placeholders in File > Properties:
  # - Title: @document_title@
  # - Author: @author@
  # - Company: @company_name@

  data = %{
    "document_title" => "Q4 Financial Report",
    "author" => "Jane Smith",
    "company_name" => "Acme Corporation"
  }
  Ootempl.render("report_template.docx", data, "Q4_report.docx")
  #=> :ok
  # Generated document has Title, Author, and Company fields populated
  ```

  Supported property fields:
  - **Core properties**: `dc:title`, `dc:subject`, `dc:description`, `dc:creator`
  - **App properties**: `Company`, `Manager`

  ### Headers, Footers, Footnotes, and Endnotes

  Placeholders in headers, footers, footnotes, and endnotes are processed just like
  the main document body:

  ```elixir
  # Template has:
  # - Header with: @company_name@ - @document_title@
  # - Footer with: Page @page@ of @total_pages@
  # - Footnote with: @footnote_citation@

  data = %{
    "company_name" => "Acme Corp",
    "document_title" => "Annual Report",
    "footnote_citation" => "Source: Annual Review 2025"
  }
  Ootempl.render("template.docx", data, "output.docx")
  ```

  ## Architecture

  The library is organized into several modules:

  - `Ootempl.Archive` - ZIP archive operations for .docx files
  - `Ootempl.Xml` - XML parsing and serialization using :xmerl
  - `Ootempl.Xml.Normalizer` - XML normalization for fragmented placeholders
  - `Ootempl.Placeholder` - Placeholder detection and parsing
  - `Ootempl.DataAccess` - Nested data access with case-insensitive matching
  - `Ootempl.Replacement` - Placeholder replacement in XML with formatting preservation
  - `Ootempl.Table` - Table structure detection, template row identification, and duplication
  - `Ootempl.Validator` - Document validation and error handling

  ## Error Handling

  The main `render/3` function returns:
  - `:ok` on success (document generated successfully)
  - `{:error, %PlaceholderError{}}` when placeholders cannot be resolved
  - `{:error, exception}` on structural failures

  Specific error types:
  - `Ootempl.PlaceholderError` - One or more placeholders cannot be resolved
  - `Ootempl.ValidationError` - File validation failures
  - `Ootempl.InvalidArchiveError` - Invalid ZIP structure
  - `Ootempl.MissingFileError` - Required files missing
  - `Ootempl.MalformedXMLError` - XML parsing failures
  """

  alias Ootempl.Archive
  alias Ootempl.Replacement
  alias Ootempl.Table
  alias Ootempl.Validator
  alias Ootempl.Xml
  alias Ootempl.Xml.Normalizer

  @doc """
  Renders a .docx template with data to generate an output document.

  This is the primary public API for the Ootempl library. It orchestrates
  template loading, placeholder replacement, and saving with comprehensive validation.

  Replaces `@variable@` placeholders in the template with values from the data map,
  supporting nested data access with dot notation (e.g., `@customer.name@`).
  Case-insensitive matching ensures `@Name@`, `@name@`, and `@NAME@` all match
  the same data key.

  ## Parameters

  - `template_path` - Path to the .docx template file
  - `data` - Map of data for placeholder replacement (string keys)
  - `output_path` - Path where the generated .docx file should be saved

  ## Returns

  - `:ok` on success
  - `{:error, %PlaceholderError{}}` when placeholders cannot be resolved
  - `{:error, exception}` on structural failures (invalid file, corrupt ZIP, etc.)

  ## Examples

      # Successful replacement
      data = %{
        "name" => "John Doe",
        "customer" => %{"email" => "john@example.com"},
        "total" => 99.99
      }
      Ootempl.render("template.docx", data, "output.docx")
      #=> :ok

      # Missing placeholders (collects all errors)
      Ootempl.render("template.docx", %{}, "output.docx")
      #=> {:error, %Ootempl.PlaceholderError{
      #     message: "2 placeholders could not be resolved (first: @name@)",
      #     placeholders: [
      #       %{placeholder: "@name@", reason: {:path_not_found, ["name"]}},
      #       %{placeholder: "@customer.email@", reason: {:path_not_found, ["customer", "email"]}}
      #     ]
      #   }}

      # Structural error cases
      Ootempl.render("missing.docx", %{}, "out.docx")
      #=> {:error, %Ootempl.ValidationError{reason: :file_not_found}}

      Ootempl.render("corrupt.docx", %{}, "out.docx")
      #=> {:error, %Ootempl.InvalidArchiveError{}}

  ## Error Cases

  ### Structural Errors (fail-fast)
  - Template file does not exist
  - Template is not a valid .docx file
  - Template and output are the same file
  - Output directory does not exist or is not writable
  - Insufficient disk space
  - Template file is locked/in use

  ### Placeholder Errors (collected and returned together)
  - Placeholder not found in data map
  - Invalid nested path
  - Nil values in data
  - Unsupported data types (maps, lists as values)
  """
  @spec render(Path.t(), map(), Path.t()) :: :ok | {:error, term()}
  def render(template_path, data, output_path) do
    with :ok <- validate_paths(template_path, output_path),
         :ok <- Validator.validate_docx(template_path) do
      # Extract template and ensure cleanup happens regardless of success or failure
      case Archive.extract(template_path) do
        {:ok, temp_dir} ->
          # Process template and always cleanup temp directory, even on error
          result = process_template(temp_dir, data, output_path)
          cleanup_result = Archive.cleanup(temp_dir)

          # Return original result or cleanup error
          case {result, cleanup_result} do
            {:ok, :ok} -> :ok
            {:ok, {:error, _} = cleanup_error} -> cleanup_error
            {error, _} -> error
          end

        {:error, _reason} = error ->
          error
      end
    else
      {:error, _reason} = error -> error
    end
  end

  # Private functions

  @spec process_template(Path.t(), map(), Path.t()) :: :ok | {:error, term()}
  defp process_template(temp_dir, data, output_path) do
    with :ok <- process_single_xml_file(temp_dir, "word/document.xml", data),
         :ok <- process_header_footer_files(temp_dir, data),
         :ok <- process_footnote_endnote_files(temp_dir, data),
         :ok <- process_document_properties(temp_dir, data),
         {:ok, file_map} <- build_file_map(temp_dir) do
      Archive.create(file_map, output_path)
    end
  end

  # Processes a single XML file through the full replacement pipeline.
  #
  # Applies the complete processing pipeline to a single XML file:
  # - Load XML content
  # - Parse XML
  # - Normalize (collapse fragmented placeholders)
  # - Process tables (if any)
  # - Replace placeholders
  # - Serialize back to XML
  # - Save to disk
  @spec process_single_xml_file(Path.t(), String.t(), map()) :: :ok | {:error, term()}
  defp process_single_xml_file(temp_dir, relative_path, data) do
    file_path = Path.join(temp_dir, relative_path)

    with {:ok, xml_content} <- File.read(file_path),
         {:ok, xml_doc} <- Xml.parse(xml_content),
         normalized_doc = Normalizer.normalize(xml_doc),
         {:ok, table_processed_doc} <- process_tables(normalized_doc, data),
         {:ok, replaced_doc} <- Replacement.replace_in_document(table_processed_doc, data),
         {:ok, modified_xml} <- Xml.serialize(replaced_doc),
         :ok <- File.write(file_path, modified_xml) do
      :ok
    else
      # PlaceholderError should be returned directly without wrapping
      {:error, %Ootempl.PlaceholderError{} = error} -> {:error, error}
      # Other errors are wrapped with context
      {:error, reason} -> {:error, {:file_processing_failed, relative_path, reason}}
    end
  end

  # Discovers and processes all header and footer XML files in the document.
  #
  # Finds all `word/header*.xml` and `word/footer*.xml` files using Path.wildcard
  # and applies the same processing pipeline used for the main document body.
  #
  # Missing header/footer files are OK (not all documents have them).
  @spec process_header_footer_files(Path.t(), map()) :: :ok | {:error, term()}
  defp process_header_footer_files(temp_dir, data) do
    header_files = Path.wildcard(Path.join(temp_dir, "word/header*.xml"))
    footer_files = Path.wildcard(Path.join(temp_dir, "word/footer*.xml"))

    all_files = header_files ++ footer_files

    # Convert absolute paths to relative paths
    relative_files =
      Enum.map(all_files, fn file_path ->
        Path.relative_to(file_path, temp_dir)
      end)

    # Process each file
    Enum.reduce_while(relative_files, :ok, fn relative_path, _acc ->
      case process_single_xml_file(temp_dir, relative_path, data) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  # Processes footnotes and endnotes XML files if they exist.
  #
  # Finds `word/footnotes.xml` and `word/endnotes.xml` files and applies
  # the same processing pipeline used for the main document body.
  # These files use the same w:p/w:r/w:t XML structure as document.xml.
  #
  # Missing files are OK (not all documents have footnotes or endnotes).
  @spec process_footnote_endnote_files(Path.t(), map()) :: :ok | {:error, term()}
  defp process_footnote_endnote_files(temp_dir, data) do
    ["word/footnotes.xml", "word/endnotes.xml"]
    |> Enum.filter(&File.exists?(Path.join(temp_dir, &1)))
    |> Enum.reduce_while(:ok, fn relative_path, _acc ->
      case process_single_xml_file(temp_dir, relative_path, data) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  # Processes document property files for placeholder replacement.
  #
  # Handles `docProps/core.xml` (title, subject, description, creator) and
  # `docProps/app.xml` (company, manager) files. These files use simpler XML
  # structures with direct text content rather than Word's paragraph/run structure.
  #
  # Missing property files are OK (not all documents have all properties set).
  @spec process_document_properties(Path.t(), map()) :: :ok | {:error, term()}
  defp process_document_properties(temp_dir, data) do
    ["docProps/core.xml", "docProps/app.xml"]
    |> Enum.filter(&File.exists?(Path.join(temp_dir, &1)))
    |> Enum.reduce_while(:ok, fn relative_path, _acc ->
      case process_property_file(temp_dir, relative_path, data) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  # Processes a document property XML file using simple text replacement.
  #
  # Property files have simpler XML structures with direct text content
  # (e.g., `<dc:title>@title@</dc:title>`) rather than the complex
  # w:p/w:r/w:t structure used in the main document. This function uses
  # the full XML processing pipeline to ensure proper handling.
  @spec process_property_file(Path.t(), String.t(), map()) :: :ok | {:error, term()}
  defp process_property_file(temp_dir, relative_path, data) do
    file_path = Path.join(temp_dir, relative_path)

    with {:ok, xml_content} <- File.read(file_path),
         {:ok, xml_doc} <- Xml.parse(xml_content),
         normalized_doc = Normalizer.normalize(xml_doc),
         {:ok, replaced_doc} <- Replacement.replace_in_document(normalized_doc, data),
         {:ok, modified_xml} <- Xml.serialize(replaced_doc),
         :ok <- File.write(file_path, modified_xml) do
      :ok
    else
      {:error, %Ootempl.PlaceholderError{} = error} -> {:error, error}
      {:error, reason} -> {:error, {:property_file_processing_failed, relative_path, reason}}
    end
  end

  @spec process_tables(Xml.xml_element(), map()) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp process_tables(xml_doc, data) do
    # Find all tables in document
    tables = Table.find_tables(xml_doc)

    # Process each table and collect results
    case process_all_tables(tables, data, xml_doc) do
      {:ok, modified_doc} -> {:ok, modified_doc}
      {:error, _reason} = error -> error
    end
  end

  @spec process_all_tables([Xml.xml_element()], map(), Xml.xml_element()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_all_tables([], _data, xml_doc), do: {:ok, xml_doc}

  defp process_all_tables([table | rest_tables], data, xml_doc) do
    case process_single_table(table, data, xml_doc) do
      {:ok, modified_doc} -> process_all_tables(rest_tables, data, modified_doc)
      {:error, _reason} = error -> error
    end
  end

  @spec process_single_table(Xml.xml_element(), map(), Xml.xml_element()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_single_table(table, data, xml_doc) do
    rows = Table.extract_rows(table)

    # Group template rows
    case Table.group_template_rows(rows, data) do
      {:ok, row_analyses} ->
        # Find template row groups and duplicate
        process_row_groups(table, row_analyses, data, xml_doc)

      {:error, {:multiple_lists, _row}} = error ->
        error
    end
  end

  @spec process_row_groups(Xml.xml_element(), [Table.row_analysis()], map(), Xml.xml_element()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_row_groups(table, row_analyses, data, xml_doc) do
    # Identify template row groups (consecutive template rows with same list_key)
    template_groups = identify_template_groups(row_analyses)

    # Process template groups in reverse order to maintain positions
    modified_table =
      template_groups
      |> Enum.reverse()
      |> Enum.reduce(table, fn group, acc_table ->
        duplicate_and_replace_group(group, data, acc_table)
      end)

    # Replace the old table with modified table in the document
    replace_table_in_doc(xml_doc, table, modified_table)
  end

  @spec identify_template_groups([Table.row_analysis()]) ::
          [%{rows: [Xml.xml_element()], list_key: String.t(), position: non_neg_integer()}]
  defp identify_template_groups(row_analyses) do
    row_analyses
    |> Enum.with_index()
    |> Enum.reduce([], &add_template_row_to_groups/2)
    |> Enum.reverse()
  end

  @spec add_template_row_to_groups({Table.row_analysis(), non_neg_integer()}, [map()]) :: [map()]
  defp add_template_row_to_groups({analysis, index}, acc) do
    if analysis.template? do
      handle_template_row(analysis, index, acc)
    else
      acc
    end
  end

  @spec handle_template_row(Table.row_analysis(), non_neg_integer(), [map()]) :: [map()]
  defp handle_template_row(analysis, index, []),
    do: [%{rows: [analysis.row], list_key: analysis.list_key, position: index}]

  defp handle_template_row(analysis, _index, [current | rest]) when current.list_key == analysis.list_key do
    updated_current = %{current | rows: current.rows ++ [analysis.row]}
    [updated_current | rest]
  end

  defp handle_template_row(analysis, index, groups) do
    [%{rows: [analysis.row], list_key: analysis.list_key, position: index} | groups]
  end

  @spec duplicate_and_replace_group(
          %{rows: [Xml.xml_element()], list_key: String.t(), position: non_neg_integer()},
          map(),
          Xml.xml_element()
        ) :: Xml.xml_element()
  defp duplicate_and_replace_group(group, data, table) do
    # Duplicate rows with scoped data
    duplicated_with_data = Table.duplicate_rows(group.rows, group.list_key, data)

    # Replace placeholders in each duplicated row
    duplicated_rows =
      Enum.map(duplicated_with_data, fn {row, scoped_data} ->
        # Apply replacement to this row with scoped data
        case Replacement.replace_in_document(row, scoped_data) do
          {:ok, replaced_row} -> replaced_row
          {:error, _} -> row
        end
      end)

    # Insert duplicated rows first, then remove template rows
    table
    |> Table.insert_rows(duplicated_rows, group.position)
    |> Table.remove_template_rows(group.rows)
  end

  @spec replace_table_in_doc(Xml.xml_element(), Xml.xml_element(), Xml.xml_element()) ::
          {:ok, Xml.xml_element()}
  defp replace_table_in_doc(xml_doc, old_table, new_table) do
    # Traverse document and replace old table with new table
    modified_doc = replace_element_in_tree(xml_doc, old_table, new_table)
    {:ok, modified_doc}
  end

  @spec replace_element_in_tree(Xml.xml_element(), Xml.xml_element(), Xml.xml_element()) ::
          Xml.xml_element()
  defp replace_element_in_tree(element, old_element, new_element) do
    import Xml

    # If this is the element to replace, return the new one
    if element == old_element do
      new_element
    else
      # Otherwise, recursively process children
      content = xmlElement(element, :content)
      modified_content = Enum.map(content, &replace_node_in_tree(&1, old_element, new_element))
      xmlElement(element, content: modified_content)
    end
  end

  @spec replace_node_in_tree(Xml.xml_node(), Xml.xml_element(), Xml.xml_element()) ::
          Xml.xml_node()
  defp replace_node_in_tree(node, old_element, new_element) do
    require Record

    if Record.is_record(node, :xmlElement) do
      replace_element_in_tree(node, old_element, new_element)
    else
      node
    end
  end

  @spec validate_paths(Path.t(), Path.t()) :: :ok | {:error, term()}
  defp validate_paths(template_path, output_path) do
    cond do
      Path.expand(template_path) == Path.expand(output_path) ->
        {:error, {:same_file, "Template and output paths must be different"}}

      not File.dir?(Path.dirname(output_path)) ->
        {:error, {:invalid_output_path, "Output directory does not exist: #{Path.dirname(output_path)}"}}

      true ->
        :ok
    end
  end

  @spec build_file_map(Path.t()) :: {:ok, Archive.file_map()} | {:error, term()}
  defp build_file_map(temp_dir) do
    # Recursively find all files in temp directory
    case gather_files(temp_dir, temp_dir) do
      {:ok, file_map} -> {:ok, file_map}
      {:error, reason} -> {:error, {:build_file_map_failed, reason}}
    end
  end

  @spec gather_files(Path.t(), Path.t()) :: {:ok, Archive.file_map()} | {:error, term()}
  defp gather_files(base_dir, current_dir) do
    case File.ls(current_dir) do
      {:ok, entries} ->
        file_map =
          Enum.reduce(entries, %{}, fn entry, acc ->
            process_entry(base_dir, current_dir, entry, acc)
          end)

        {:ok, file_map}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec process_entry(Path.t(), Path.t(), String.t(), Archive.file_map()) :: Archive.file_map()
  defp process_entry(base_dir, current_dir, entry, acc) do
    full_path = Path.join(current_dir, entry)
    relative_path = Path.relative_to(full_path, base_dir)

    cond do
      File.regular?(full_path) ->
        add_file_to_map(relative_path, full_path, acc)

      File.dir?(full_path) ->
        merge_directory_contents(base_dir, full_path, acc)

      true ->
        acc
    end
  end

  @spec add_file_to_map(String.t(), Path.t(), Archive.file_map()) :: Archive.file_map()
  defp add_file_to_map(relative_path, full_path, acc) do
    case File.read(full_path) do
      {:ok, content} -> Map.put(acc, relative_path, content)
      {:error, _} -> acc
    end
  end

  @spec merge_directory_contents(Path.t(), Path.t(), Archive.file_map()) :: Archive.file_map()
  defp merge_directory_contents(base_dir, full_path, acc) do
    case gather_files(base_dir, full_path) do
      {:ok, nested_map} -> Map.merge(acc, nested_map)
      {:error, _} -> acc
    end
  end
end
