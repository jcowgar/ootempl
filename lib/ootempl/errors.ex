defmodule Ootempl.InvalidArchiveError do
  @moduledoc """
  Raised when a .docx file is not a valid ZIP archive.

  This error indicates that the file could not be opened as a ZIP archive,
  which is required for .docx files. Common causes include:
  - File is corrupt or incomplete
  - File is not actually a .docx file (despite the extension)
  - File permissions prevent reading
  """
  defexception [:message, :path, :reason]

  @type t :: %__MODULE__{
          message: String.t(),
          path: Path.t(),
          reason: term()
        }

  @impl true
  def exception(opts) do
    path = Keyword.fetch!(opts, :path)
    reason = Keyword.get(opts, :reason, :unknown)

    message = "Invalid ZIP archive: #{path} (reason: #{inspect(reason)})"

    %__MODULE__{
      message: message,
      path: path,
      reason: reason
    }
  end
end

defmodule Ootempl.MissingFileError do
  @moduledoc """
  Raised when a required file is missing from a .docx archive.

  This error indicates that the .docx file structure is incomplete. All .docx
  files must contain certain files like `word/document.xml`, `[Content_Types].xml`,
  and `_rels/.rels` to be valid Office documents.
  """
  defexception [:message, :path, :missing_file]

  @type t :: %__MODULE__{
          message: String.t(),
          path: Path.t(),
          missing_file: String.t()
        }

  @impl true
  def exception(opts) do
    path = Keyword.fetch!(opts, :path)
    missing_file = Keyword.fetch!(opts, :missing_file)

    message = "Required file missing from #{path}: #{missing_file}"

    %__MODULE__{
      message: message,
      path: path,
      missing_file: missing_file
    }
  end
end

defmodule Ootempl.MalformedXMLError do
  @moduledoc """
  Raised when XML content in a .docx file is not well-formed.

  This error indicates that an XML file within the .docx archive could not be
  parsed. The XML may have syntax errors, unclosed tags, or other structural
  problems that prevent parsing.
  """
  defexception [:message, :path, :xml_file, :reason]

  @type t :: %__MODULE__{
          message: String.t(),
          path: Path.t(),
          xml_file: String.t(),
          reason: term()
        }

  @impl true
  def exception(opts) do
    path = Keyword.fetch!(opts, :path)
    xml_file = Keyword.fetch!(opts, :xml_file)
    reason = Keyword.get(opts, :reason, :unknown)

    message = "Malformed XML in #{path} at #{xml_file}: #{format_parse_error(reason)}"

    %__MODULE__{
      message: message,
      path: path,
      xml_file: xml_file,
      reason: reason
    }
  end

  defp format_parse_error({:fatal, error}) when is_tuple(error) do
    # :xmerl_scan errors are typically {:fatal, {...}}
    "#{inspect(error)}"
  end

  defp format_parse_error(reason) do
    inspect(reason)
  end
end

defmodule Ootempl.ValidationError do
  @moduledoc """
  Raised when a .docx file fails general validation checks.

  This is a catch-all error for validation failures that don't fit into
  the more specific error types. It provides a descriptive message about
  what validation check failed.
  """
  defexception [:message, :path, :reason]

  @type t :: %__MODULE__{
          message: String.t(),
          path: Path.t(),
          reason: term()
        }

  @impl true
  def exception(opts) do
    path = Keyword.fetch!(opts, :path)
    reason = Keyword.fetch!(opts, :reason)

    message = build_message(path, reason)

    %__MODULE__{
      message: message,
      path: path,
      reason: reason
    }
  end

  defp build_message(path, :not_a_file) do
    "Not a regular file: #{path}"
  end

  defp build_message(path, :file_not_found) do
    "File not found: #{path}"
  end

  defp build_message(path, reason) do
    "Validation failed for #{path}: #{inspect(reason)}"
  end
end
