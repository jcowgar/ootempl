defmodule Ootempl.Validator do
  @moduledoc """
  Provides validation functions for .docx files.

  This module validates .docx file structure, ensuring files are valid ZIP
  archives, contain required files, and have well-formed XML content.

  ## Required .docx Files

  All valid .docx files must contain:
  - `word/document.xml` - Primary document content
  - `[Content_Types].xml` - MIME type definitions
  - `_rels/.rels` - Package-level relationships

  ## Validation Workflow

  Use `validate_docx/1` to run all validation checks:

      case Ootempl.Validator.validate_docx("template.docx") do
        :ok -> # File is valid
        {:error, exception} -> # File is invalid, exception has details
      end

  Or use individual validation functions for specific checks:
  - `validate_archive/1` - Check if file is a valid ZIP
  - `validate_structure/1` - Verify required files exist
  - `validate_xml/1` - Check if XML string is well-formed
  """

  alias Ootempl.InvalidArchiveError
  alias Ootempl.MalformedXMLError
  alias Ootempl.MissingFileError
  alias Ootempl.ValidationError

  @required_files [
    "word/document.xml",
    "[Content_Types].xml",
    "_rels/.rels"
  ]

  @doc """
  Validates that a file is a valid ZIP archive.

  Attempts to open the file as a ZIP archive using Erlang's `:zip` module.
  Returns `:ok` if successful, or `{:error, exception}` if the file cannot
  be opened as a ZIP archive.

  ## Examples

      iex> Ootempl.Validator.validate_archive("template.docx")
      :ok

      iex> Ootempl.Validator.validate_archive("not_a_zip.txt")
      {:error, %Ootempl.InvalidArchiveError{}}
  """
  @spec validate_archive(Path.t()) :: :ok | {:error, InvalidArchiveError.t()}
  def validate_archive(path) do
    case :zip.zip_open(to_charlist(path), [:memory]) do
      {:ok, zip_handle} ->
        :zip.zip_close(zip_handle)
        :ok

      {:error, reason} ->
        {:error, InvalidArchiveError.exception(path: path, reason: reason)}
    end
  end

  @doc """
  Validates that a .docx archive contains all required files.

  Checks for the presence of:
  - `word/document.xml` (primary content)
  - `[Content_Types].xml` (MIME types)
  - `_rels/.rels` (package relationships)

  Returns `:ok` if all required files exist, or `{:error, exception}` if
  any required file is missing.

  ## Examples

      iex> Ootempl.Validator.validate_structure("template.docx")
      :ok

      iex> Ootempl.Validator.validate_structure("incomplete.docx")
      {:error, %Ootempl.MissingFileError{missing_file: "word/document.xml"}}
  """
  @spec validate_structure(Path.t()) :: :ok | {:error, MissingFileError.t()}
  def validate_structure(path) do
    case open_zip(path) do
      {:ok, zip_handle} ->
        try do
          case find_missing_files(zip_handle) do
            [] ->
              :ok

            [missing_file | _] ->
              {:error, MissingFileError.exception(path: path, missing_file: missing_file)}
          end
        after
          :zip.zip_close(zip_handle)
        end

      {:error, _exception} = error ->
        error
    end
  end

  @doc """
  Validates that an XML string is well-formed.

  Attempts to parse the XML using `:xmerl_scan`. Returns `:ok` if the XML
  parses successfully, or `{:error, reason}` if parsing fails.

  This function only checks if the XML is well-formed (valid syntax), not if
  it conforms to any particular schema.

  ## Examples

      iex> Ootempl.Validator.validate_xml("<root><child>text</child></root>")
      :ok

      iex> Ootempl.Validator.validate_xml("<root><unclosed>")
      {:error, {:fatal, ...}}
  """
  @spec validate_xml(String.t()) :: :ok | {:error, term()}
  def validate_xml(xml_string) when is_binary(xml_string) do
    charlist = String.to_charlist(xml_string)

    try do
      :xmerl_scan.string(charlist, namespace_conformant: true)
      :ok
    rescue
      e -> {:error, e}
    catch
      :exit, reason -> {:error, reason}
    end
  end

  @doc """
  Runs all validation checks on a .docx file.

  Performs the following validations in order:
  1. File exists and is a regular file
  2. File is a valid ZIP archive
  3. All required files are present
  4. The main document XML is well-formed

  Returns `:ok` if all checks pass, or `{:error, exception}` with a specific
  error type indicating the first validation failure.

  ## Examples

      iex> Ootempl.Validator.validate_docx("template.docx")
      :ok

      iex> Ootempl.Validator.validate_docx("nonexistent.docx")
      {:error, %Ootempl.ValidationError{reason: :file_not_found}}

      iex> Ootempl.Validator.validate_docx("corrupt.docx")
      {:error, %Ootempl.InvalidArchiveError{}}
  """
  @spec validate_docx(Path.t()) ::
          :ok
          | {:error, ValidationError.t() | InvalidArchiveError.t() | MissingFileError.t() | MalformedXMLError.t()}
  def validate_docx(path) do
    with :ok <- validate_file_exists(path),
         :ok <- validate_archive(path),
         :ok <- validate_structure(path) do
      validate_document_xml(path)
    end
  end

  # Private functions

  @spec validate_file_exists(Path.t()) :: :ok | {:error, ValidationError.t()}
  defp validate_file_exists(path) do
    cond do
      not File.exists?(path) ->
        {:error, ValidationError.exception(path: path, reason: :file_not_found)}

      not File.regular?(path) ->
        {:error, ValidationError.exception(path: path, reason: :not_a_file)}

      true ->
        :ok
    end
  end

  @spec open_zip(Path.t()) :: {:ok, term()} | {:error, InvalidArchiveError.t()}
  defp open_zip(path) do
    case :zip.zip_open(to_charlist(path), [:memory]) do
      {:ok, zip_handle} ->
        {:ok, zip_handle}

      {:error, reason} ->
        {:error, InvalidArchiveError.exception(path: path, reason: reason)}
    end
  end

  @spec find_missing_files(term()) :: [String.t()]
  defp find_missing_files(zip_handle) do
    Enum.reject(@required_files, fn file ->
      file_exists_in_zip?(zip_handle, file)
    end)
  end

  @spec file_exists_in_zip?(term(), String.t()) :: boolean()
  defp file_exists_in_zip?(zip_handle, internal_path) do
    case :zip.zip_get(to_charlist(internal_path), zip_handle) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @spec validate_document_xml(Path.t()) :: :ok | {:error, MalformedXMLError.t()}
  defp validate_document_xml(path) do
    xml_file = "word/document.xml"

    case open_zip(path) do
      {:ok, zip_handle} ->
        try do
          case :zip.zip_get(to_charlist(xml_file), zip_handle) do
            {:ok, {_name, content}} ->
              case validate_xml(content) do
                :ok ->
                  :ok

                {:error, reason} ->
                  {:error, MalformedXMLError.exception(path: path, xml_file: xml_file, reason: reason)}
              end

            {:error, _reason} ->
              # This should have been caught by validate_structure,
              # but handle it just in case
              {:error, MissingFileError.exception(path: path, missing_file: xml_file)}
          end
        after
          :zip.zip_close(zip_handle)
        end

      {:error, _exception} = error ->
        error
    end
  end
end
