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
  - Case-insensitive placeholder matching
  - Preserve Word formatting (bold, italic, fonts)
  - Generate valid .docx output files
  - Comprehensive validation and error handling

  ## Basic Usage

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

  ## Architecture

  The library is organized into several modules:

  - `Ootempl.Archive` - ZIP archive operations for .docx files
  - `Ootempl.Xml` - XML parsing and serialization using :xmerl
  - `Ootempl.Xml.Normalizer` - XML normalization for fragmented placeholders
  - `Ootempl.Placeholder` - Placeholder detection and parsing
  - `Ootempl.DataAccess` - Nested data access with case-insensitive matching
  - `Ootempl.Replacement` - Placeholder replacement in XML with formatting preservation
  - `Ootempl.Validator` - Document validation and error handling

  ## Error Handling

  The main `render/3` function returns:
  - `:ok` on success (document generated successfully)
  - `{:error, errors}` when placeholders cannot be resolved
  - `{:error, exception}` on structural failures

  Specific error types:
  - `Ootempl.ValidationError` - File validation failures
  - `Ootempl.InvalidArchiveError` - Invalid ZIP structure
  - `Ootempl.MissingFileError` - Required files missing
  - `Ootempl.MalformedXMLError` - XML parsing failures
  """

  alias Ootempl.Archive
  alias Ootempl.Replacement
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
  - `{:error, errors}` when placeholders cannot be resolved (list of error details)
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
      #=> {:error, [
      #     {:placeholder_not_found, "@name@", {:path_not_found, ["name"]}},
      #     {:placeholder_not_found, "@customer.email@", {:path_not_found, ["customer", "email"]}}
      #   ]}

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
    with {:ok, xml_content} <- load_document_xml(temp_dir),
         {:ok, xml_doc} <- Xml.parse(xml_content),
         normalized_doc <- Normalizer.normalize(xml_doc),
         {:ok, replaced_doc} <- Replacement.replace_in_document(normalized_doc, data),
         {:ok, modified_xml} <- Xml.serialize(replaced_doc),
         :ok <- save_document_xml(temp_dir, modified_xml),
         {:ok, file_map} <- build_file_map(temp_dir) do
      Archive.create(file_map, output_path)
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

  @spec load_document_xml(Path.t()) :: {:ok, binary()} | {:error, term()}
  defp load_document_xml(temp_dir) do
    document_path = Path.join(temp_dir, "word/document.xml")

    case File.read(document_path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, {:read_failed, document_path, reason}}
    end
  end

  @spec save_document_xml(Path.t(), String.t()) :: :ok | {:error, term()}
  defp save_document_xml(temp_dir, xml_content) do
    document_path = Path.join(temp_dir, "word/document.xml")

    case File.write(document_path, xml_content) do
      :ok -> :ok
      {:error, reason} -> {:error, {:write_failed, document_path, reason}}
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
