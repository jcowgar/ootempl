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
  and `_rels/.rels` to be valid Office Open XML documents.
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

defmodule Ootempl.PlaceholderError do
  @moduledoc """
  Raised when one or more placeholders in a template cannot be resolved.

  This error collects all placeholder resolution failures that occur during
  template rendering, allowing you to see all missing data at once rather
  than failing on the first missing placeholder.

  Each placeholder error contains:
  - `placeholder` - The original placeholder text (e.g., "{{name}}")
  - `reason` - Why it couldn't be resolved (e.g., `{:path_not_found, ["name"]}`)

  ## Common Reasons

  - `{:path_not_found, path}` - Data key doesn't exist in the provided data map
  - `{:ambiguous_key, key, matches}` - Multiple case variants of the key exist
  - `{:invalid_index, index}` - List index is not a valid number
  - `{:index_out_of_bounds, index, size}` - List index exceeds list size
  - `{:not_a_list, value}` - Tried to index into a non-list value
  - `:nil_value` - Data path exists but value is nil
  - `{:unsupported_type, type}` - Value type cannot be converted to string
  """
  defexception [:message, :placeholders]

  @type placeholder_error :: %{
          placeholder: String.t(),
          reason: term()
        }

  @type t :: %__MODULE__{
          message: String.t(),
          placeholders: [placeholder_error()]
        }

  @impl true
  def exception(opts) do
    placeholders = Keyword.fetch!(opts, :placeholders)

    message = build_message(placeholders)

    %__MODULE__{
      message: message,
      placeholders: placeholders
    }
  end

  defp build_message([]) do
    "No placeholders could be resolved"
  end

  defp build_message([%{placeholder: placeholder}]) do
    "Placeholder #{placeholder} could not be resolved"
  end

  defp build_message(placeholders) do
    count = length(placeholders)
    first = List.first(placeholders)
    "#{count} placeholders could not be resolved (first: #{first.placeholder})"
  end
end

defmodule Ootempl.ImageError do
  @moduledoc """
  Raised when an image replacement operation fails.

  This error indicates a problem with image file handling during template rendering.
  The error provides detailed context about which placeholder failed and why.

  ## Common Reasons

  - `:image_not_found_in_data` - Placeholder exists in template but no image path provided in data
  - `:file_not_found` - Image file doesn't exist at the provided path
  - `:file_not_readable` - Image file exists but cannot be read (permission issue)
  - `:unsupported_format` - Image format is not supported (only PNG, JPEG, GIF supported)
  - `:cannot_read_dimensions` - Image file is corrupt or dimensions cannot be extracted

  ## Examples

      # Missing image path in data
      iex> Ootempl.render("template.docx", %{}, "out.docx")
      {:error, %Ootempl.ImageError{
        message: "Image placeholder '{{image:logo}}' has no corresponding data key 'logo'",
        placeholder_name: "logo",
        image_path: nil,
        reason: :image_not_found_in_data
      }}

      # Image file doesn't exist
      iex> Ootempl.render("template.docx", %{"logo" => "/missing/logo.png"}, "out.docx")
      {:error, %Ootempl.ImageError{
        message: "Image file not found for placeholder 'logo': /missing/logo.png",
        placeholder_name: "logo",
        image_path: "/missing/logo.png",
        reason: :file_not_found
      }}

      # Unsupported format
      iex> Ootempl.render("template.docx", %{"logo" => "logo.bmp"}, "out.docx")
      {:error, %Ootempl.ImageError{
        message: "Unsupported image format for placeholder 'logo': logo.bmp (only PNG, JPEG, GIF supported)",
        placeholder_name: "logo",
        image_path: "logo.bmp",
        reason: :unsupported_format
      }}
  """
  defexception [:message, :placeholder_name, :image_path, :reason]

  @type t :: %__MODULE__{
          message: String.t(),
          placeholder_name: String.t() | nil,
          image_path: String.t() | nil,
          reason: atom()
        }

  @impl true
  def exception(opts) do
    placeholder_name = Keyword.get(opts, :placeholder_name)
    image_path = Keyword.get(opts, :image_path)
    reason = Keyword.fetch!(opts, :reason)

    message = build_message(placeholder_name, image_path, reason)

    %__MODULE__{
      message: message,
      placeholder_name: placeholder_name,
      image_path: image_path,
      reason: reason
    }
  end

  defp build_message(placeholder_name, nil, :image_not_found_in_data) do
    "Image placeholder '{{image:#{placeholder_name}}}' has no corresponding data key '#{placeholder_name}'"
  end

  defp build_message(placeholder_name, image_path, :file_not_found) do
    "Image file not found for placeholder '#{placeholder_name}': #{image_path}"
  end

  defp build_message(placeholder_name, image_path, :file_not_readable) do
    "Image file cannot be read for placeholder '#{placeholder_name}': #{image_path} (check file permissions)"
  end

  defp build_message(placeholder_name, image_path, :unsupported_format) do
    extension = Path.extname(image_path)

    "Unsupported image format for placeholder '#{placeholder_name}': #{image_path} (format: #{extension}, only PNG, JPEG, GIF supported)"
  end

  defp build_message(placeholder_name, image_path, :cannot_read_dimensions) do
    "Cannot read image dimensions for placeholder '#{placeholder_name}': #{image_path} (file may be corrupt)"
  end

  defp build_message(placeholder_name, image_path, reason) do
    "Image processing failed for placeholder '#{placeholder_name}' at #{image_path}: #{inspect(reason)}"
  end
end
