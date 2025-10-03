defmodule Ootempl.Archive do
  @moduledoc """
  Provides functions for working with .docx files as ZIP archives.

  .docx files are ZIP archives containing XML documents and media files.
  This module handles extracting .docx archives to access internal content,
  extracting specific files, and re-packaging content into valid .docx archives.
  """

  @type file_entry :: {charlist(), binary()}
  @type file_map :: %{String.t() => binary()}

  @doc """
  Extracts a .docx file to a temporary directory.

  Returns `{:ok, temp_path}` where `temp_path` is the directory containing
  the extracted contents, or `{:error, reason}` if extraction fails.

  The caller is responsible for cleaning up the temporary directory using
  `cleanup/1` when done, even if subsequent operations fail.

  ## Examples

      iex> {:ok, temp_path} = Ootempl.Archive.extract("template.docx")
      iex> File.exists?(Path.join(temp_path, "word/document.xml"))
      true
      iex> Ootempl.Archive.cleanup(temp_path)
      :ok
  """
  @spec extract(Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def extract(docx_path) do
    with {:ok, _} <- validate_file(docx_path),
         {:ok, temp_dir} <- create_temp_dir(),
         {:ok, _files} <- unzip_to_dir(docx_path, temp_dir) do
      {:ok, temp_dir}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extracts a specific file from a .docx archive.

  Returns `{:ok, content}` where `content` is the binary content of the file,
  or `{:error, reason}` if the file cannot be extracted.

  ## Examples

      iex> {:ok, xml} = Ootempl.Archive.extract_file("template.docx", "word/document.xml")
      iex> is_binary(xml)
      true

      iex> Ootempl.Archive.extract_file("template.docx", "nonexistent.xml")
      {:error, :file_not_found}
  """
  @spec extract_file(Path.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def extract_file(docx_path, internal_path) do
    with {:ok, _} <- validate_file(docx_path),
         {:ok, zip_handle} <- open_zip_archive(docx_path) do
      try do
        case :zip.zip_get(to_charlist(internal_path), zip_handle) do
          {:ok, {_name, content}} -> {:ok, content}
          {:error, :file_not_found} -> {:error, :file_not_found}
          {:error, reason} -> {:error, {:extract_file_failed, reason}}
        end
      after
        :zip.zip_close(zip_handle)
      end
    end
  end

  @doc """
  Creates a .docx archive from a map of file paths to content.

  The `file_map` is a map where keys are internal paths (e.g., "word/document.xml")
  and values are binary content.

  Returns `:ok` on success, or `{:error, reason}` if creation fails.

  ## Examples

      iex> file_map = %{
      ...>   "word/document.xml" => "<?xml version=\\"1.0\\"?>...",
      ...>   "[Content_Types].xml" => "<?xml version=\\"1.0\\"?>..."
      ...> }
      iex> Ootempl.Archive.create(file_map, "output.docx")
      :ok
  """
  @spec create(file_map(), Path.t()) :: :ok | {:error, term()}
  def create(file_map, output_path) do
    file_list = Enum.map(file_map, fn {path, content} -> {to_charlist(path), content} end)

    case :zip.create(to_charlist(output_path), file_list) do
      {:ok, _zip_file} -> :ok
      {:error, reason} -> {:error, {:zip_creation_failed, reason}}
    end
  end

  @doc """
  Removes a temporary extraction directory.

  Returns `:ok` on success, or `{:error, reason}` if cleanup fails.

  ## Examples

      iex> {:ok, temp_path} = Ootempl.Archive.extract("template.docx")
      iex> Ootempl.Archive.cleanup(temp_path)
      :ok
      iex> File.exists?(temp_path)
      false
  """
  @spec cleanup(Path.t()) :: :ok | {:error, term()}
  def cleanup(temp_path) do
    case File.rm_rf(temp_path) do
      {:ok, _files} -> :ok
      {:error, reason, path} -> {:error, {:cleanup_failed, reason, path}}
    end
  end

  # Private functions

  @spec validate_file(Path.t()) :: {:ok, :valid} | {:error, term()}
  defp validate_file(docx_path) do
    cond do
      not File.exists?(docx_path) ->
        {:error, :file_not_found}

      not File.regular?(docx_path) ->
        {:error, :not_a_file}

      true ->
        {:ok, :valid}
    end
  end

  @spec open_zip_archive(Path.t()) :: {:ok, term()} | {:error, term()}
  defp open_zip_archive(docx_path) do
    case :zip.zip_open(to_charlist(docx_path), [:memory]) do
      {:ok, zip_handle} -> {:ok, zip_handle}
      {:error, reason} -> {:error, {:invalid_zip_archive, reason}}
    end
  end

  @spec create_temp_dir() :: {:ok, Path.t()} | {:error, term()}
  defp create_temp_dir do
    # Generate a unique temp directory name
    temp_base = System.tmp_dir!()
    temp_name = "ootempl_#{:erlang.unique_integer([:positive])}"
    temp_path = Path.join(temp_base, temp_name)

    case File.mkdir_p(temp_path) do
      :ok -> {:ok, temp_path}
      {:error, reason} -> {:error, {:temp_dir_creation_failed, reason}}
    end
  end

  @spec unzip_to_dir(Path.t(), Path.t()) :: {:ok, [file_entry()]} | {:error, term()}
  defp unzip_to_dir(docx_path, temp_dir) do
    case :zip.unzip(to_charlist(docx_path), cwd: to_charlist(temp_dir)) do
      {:ok, files} -> {:ok, files}
      {:error, reason} -> {:error, {:unzip_failed, reason}}
    end
  end
end
