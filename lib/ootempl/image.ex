defmodule Ootempl.Image do
  @moduledoc """
  Functions for detecting and validating placeholder images in Word documents.

  This module provides functionality to:
  - Find images with placeholder markers in Word XML
  - Parse placeholder names from alt text markers
  - Validate image files (existence, readability, format)
  - Read image dimensions for aspect ratio calculations
  """

  import Record, only: [defrecord: 2, extract: 2]

  # Extract XML element records from xmerl
  defrecord :xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlAttribute, extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")

  @image_marker_regex ~r/^@image:([a-zA-Z0-9_-]+)@$/

  @doc """
  Finds all placeholder images in the given XML element.

  Searches for `w:drawing` elements that contain alt text matching the pattern `@image:name@`.

  ## Parameters

    - `xml_element` - The XML element to search (typically a document root or paragraph)

  ## Returns

  A list of maps containing information about each placeholder image:

      %{
        placeholder_name: "logo",
        alt_text: "@image:logo@",
        xml_element: xml_drawing,
        relationship_id: "rId5",
        template_dimensions: {width, height}
      }

  ## Examples

      iex> Ootempl.Image.find_placeholder_images(document_xml)
      [
        %{
          placeholder_name: "logo",
          alt_text: "@image:logo@",
          xml_element: {...},
          relationship_id: "rId5",
          template_dimensions: {100, 100}
        }
      ]
  """
  @spec find_placeholder_images(tuple()) :: [map()]
  def find_placeholder_images(xml_element) do
    # Find all w:drawing elements
    drawings = find_elements_by_path(xml_element, ["drawing"])

    # Extract placeholder info from each drawing
    drawings
    |> Enum.map(&extract_placeholder_info/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Parses an image marker from alt text.

  Extracts the placeholder name from alt text in the format `@image:name@`.

  ## Parameters

    - `alt_text` - The alt text string to parse

  ## Returns

  - `{:ok, name}` if the alt text matches the image marker pattern
  - `:error` if the alt text does not match

  ## Examples

      iex> Ootempl.Image.parse_image_marker("@image:logo@")
      {:ok, "logo"}

      iex> Ootempl.Image.parse_image_marker("Regular alt text")
      :error
  """
  @spec parse_image_marker(String.t()) :: {:ok, String.t()} | :error
  def parse_image_marker(alt_text) when is_binary(alt_text) do
    case Regex.run(@image_marker_regex, alt_text) do
      [_, name] -> {:ok, name}
      _ -> :error
    end
  end

  @doc """
  Validates an image file at the given path.

  Checks that:
  - The file exists
  - The file is readable
  - The file format is supported (PNG, JPEG, GIF)

  ## Parameters

    - `path` - The file path to validate

  ## Returns

  - `:ok` if the file is valid
  - `{:error, reason}` if validation fails

  ## Examples

      iex> Ootempl.Image.validate_image_file("/path/to/logo.png")
      :ok

      iex> Ootempl.Image.validate_image_file("/path/to/missing.png")
      {:error, :file_not_found}

      iex> Ootempl.Image.validate_image_file("/path/to/file.bmp")
      {:error, :unsupported_format}
  """
  @spec validate_image_file(String.t()) :: :ok | {:error, atom()}
  def validate_image_file(path) when is_binary(path) do
    with :ok <- check_file_exists(path),
         :ok <- check_file_readable(path) do
      check_supported_format(path)
    end
  end

  @doc """
  Reads the dimensions (width and height) of an image file.

  ## Parameters

    - `path` - The file path of the image

  ## Returns

  - `{:ok, {width, height}}` if dimensions can be read
  - `{:error, reason}` if reading fails

  ## Examples

      iex> Ootempl.Image.get_image_dimensions("/path/to/logo.png")
      {:ok, {800, 600}}
  """
  @spec get_image_dimensions(String.t()) :: {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, atom()}
  def get_image_dimensions(path) when is_binary(path) do
    case File.read(path) do
      {:ok, data} -> read_dimensions(path, data)
      {:error, _} -> {:error, :cannot_read_file}
    end
  end

  @doc """
  Checks if an image file format is supported.

  Supported formats: PNG, JPEG, GIF

  ## Parameters

    - `path` - The file path to check

  ## Returns

  `true` if the format is supported, `false` otherwise

  ## Examples

      iex> Ootempl.Image.supported_format?("/path/to/logo.png")
      true

      iex> Ootempl.Image.supported_format?("/path/to/file.bmp")
      false
  """
  @spec supported_format?(String.t()) :: boolean()
  def supported_format?(path) when is_binary(path) do
    ext = path |> Path.extname() |> String.downcase()
    ext in [".png", ".jpg", ".jpeg", ".gif"]
  end

  # Private helper functions

  defp find_elements_by_path(xml_element, path) do
    case xml_element do
      xmlElement(name: name, content: content) ->
        current_name = name |> Atom.to_string() |> String.split(":") |> List.last()

        case path do
          [^current_name | rest] when rest == [] ->
            [xml_element]

          [^current_name | rest] ->
            Enum.flat_map(content, &find_elements_by_path(&1, rest))

          _ ->
            Enum.flat_map(content, &find_elements_by_path(&1, path))
        end

      _ ->
        []
    end
  end

  defp extract_placeholder_info(drawing_element) do
    # Find wp:docPr element with descr attribute
    case find_doc_pr(drawing_element) do
      nil ->
        nil

      doc_pr ->
        alt_text = get_attribute_value(doc_pr, "descr")

        case parse_image_marker(alt_text) do
          {:ok, name} ->
            relationship_id = find_relationship_id(drawing_element)
            dimensions = find_template_dimensions(drawing_element)

            %{
              placeholder_name: name,
              alt_text: alt_text,
              xml_element: drawing_element,
              relationship_id: relationship_id,
              template_dimensions: dimensions
            }

          :error ->
            nil
        end
    end
  end

  defp find_doc_pr(xml_element) do
    case xml_element do
      xmlElement(name: name) = elem ->
        current_name = name |> Atom.to_string() |> String.split(":") |> List.last()

        if current_name == "docPr" do
          elem
        else
          xmlElement(content: content) = elem
          Enum.find_value(content, &find_doc_pr/1)
        end

      _ ->
        nil
    end
  end

  defp get_attribute_value(xml_element, attr_name) do
    xmlElement(attributes: attrs) = xml_element

    attrs
    |> Enum.find(fn
      xmlAttribute(name: name) ->
        Atom.to_string(name) == attr_name

      _ ->
        false
    end)
    |> case do
      nil -> ""
      xmlAttribute(value: value) -> to_string(value)
    end
  end

  defp find_relationship_id(drawing_element) do
    # Find a:blip element with r:embed attribute
    case find_blip(drawing_element) do
      nil -> nil
      blip -> get_attribute_value(blip, "embed")
    end
  end

  defp find_blip(xml_element) do
    case xml_element do
      xmlElement(name: name) = elem ->
        current_name = name |> Atom.to_string() |> String.split(":") |> List.last()

        if current_name == "blip" do
          elem
        else
          xmlElement(content: content) = elem
          Enum.find_value(content, &find_blip/1)
        end

      _ ->
        nil
    end
  end

  defp find_template_dimensions(drawing_element) do
    # Find wp:extent element with cx and cy attributes (EMUs - English Metric Units)
    case find_extent(drawing_element) do
      nil ->
        nil

      extent ->
        cx = get_attribute_value(extent, "cx")
        cy = get_attribute_value(extent, "cy")

        case {Integer.parse(cx), Integer.parse(cy)} do
          {{cx_int, _}, {cy_int, _}} -> {cx_int, cy_int}
          _ -> nil
        end
    end
  end

  defp find_extent(xml_element) do
    case xml_element do
      xmlElement(name: name) = elem ->
        current_name = name |> Atom.to_string() |> String.split(":") |> List.last()

        if current_name == "extent" do
          elem
        else
          xmlElement(content: content) = elem
          Enum.find_value(content, &find_extent/1)
        end

      _ ->
        nil
    end
  end

  defp check_file_exists(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, :file_not_found}
    end
  end

  defp check_file_readable(path) do
    case File.stat(path) do
      {:ok, %File.Stat{access: access}} when access in [:read, :read_write] ->
        :ok

      {:ok, _} ->
        {:error, :file_not_readable}

      {:error, _} ->
        {:error, :file_not_readable}
    end
  end

  defp check_supported_format(path) do
    if supported_format?(path) do
      :ok
    else
      {:error, :unsupported_format}
    end
  end

  # Image dimension reading functions

  defp read_dimensions(path, data) do
    ext = path |> Path.extname() |> String.downcase()

    case ext do
      ".png" -> read_png_dimensions(data)
      ext when ext in [".jpg", ".jpeg"] -> read_jpeg_dimensions(data)
      ".gif" -> read_gif_dimensions(data)
      _ -> {:error, :unsupported_format}
    end
  end

  defp read_png_dimensions(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>> = data) do
    # PNG signature verified, find IHDR chunk
    <<_signature::binary-size(8), _chunk_length::32, "IHDR", width::32, height::32, _rest::binary>> =
      data

    {:ok, {width, height}}
  end

  defp read_png_dimensions(_), do: {:error, :invalid_image_format}

  defp read_jpeg_dimensions(<<0xFF, 0xD8, _::binary>> = data) do
    # JPEG signature verified
    case find_jpeg_sof(data, 2) do
      {:ok, {height, width}} -> {:ok, {width, height}}
      error -> error
    end
  end

  defp read_jpeg_dimensions(_), do: {:error, :invalid_image_format}

  defp read_gif_dimensions(<<"GIF87a", width::little-16, height::little-16, _::binary>>) do
    {:ok, {width, height}}
  end

  defp read_gif_dimensions(<<"GIF89a", width::little-16, height::little-16, _::binary>>) do
    {:ok, {width, height}}
  end

  defp read_gif_dimensions(_), do: {:error, :invalid_image_format}

  # JPEG SOF (Start of Frame) marker scanning
  defp find_jpeg_sof(data, offset) when byte_size(data) > offset + 1 do
    case data do
      <<_::binary-size(offset), marker::16, rest::binary>> ->
        process_jpeg_marker(data, marker, rest, offset)

      _ ->
        {:error, :invalid_image_format}
    end
  end

  defp find_jpeg_sof(_, _), do: {:error, :invalid_image_format}

  defp process_jpeg_marker(data, marker, rest, offset) do
    cond do
      sof_marker?(marker) -> extract_sof_dimensions(rest)
      marker == 0xFF00 -> find_jpeg_sof(data, offset + 2)
      marker >= 0xFF00 and marker <= 0xFFFF -> skip_jpeg_segment(data, rest, offset)
      true -> find_jpeg_sof(data, offset + 1)
    end
  end

  defp sof_marker?(marker) do
    marker in [0xFFC0, 0xFFC1, 0xFFC2, 0xFFC3, 0xFFC5, 0xFFC6, 0xFFC7, 0xFFC9, 0xFFCA, 0xFFCB, 0xFFCD, 0xFFCE, 0xFFCF]
  end

  defp extract_sof_dimensions(rest) when byte_size(rest) >= 9 do
    <<_length::16, _precision::8, height::16, width::16, _::binary>> = rest
    {:ok, {height, width}}
  end

  defp extract_sof_dimensions(_), do: {:error, :invalid_image_format}

  defp skip_jpeg_segment(data, rest, offset) when byte_size(rest) >= 2 do
    <<length::16, _::binary>> = rest
    find_jpeg_sof(data, offset + 2 + length)
  end

  defp skip_jpeg_segment(_, _, _), do: {:error, :invalid_image_format}
end
