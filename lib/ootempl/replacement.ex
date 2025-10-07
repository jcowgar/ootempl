defmodule Ootempl.Replacement do
  @moduledoc """
  Replaces placeholders in Word XML text nodes while preserving formatting.

  This module handles the core XML manipulation logic for replacing `@variable@`
  placeholders with values from data maps. It handles the complexities of Word's
  XML structure, including:

  - Preserving Word formatting (bold, italic, font, size, color)
  - XML-escaping replacement values to prevent corruption
  - Collecting all errors for batch reporting

  ## Word XML Structure

  Word stores text in `<w:t>` elements within `<w:r>` (run) elements that carry
  formatting:

      <w:p>  <!-- paragraph -->
        <w:r>  <!-- run with formatting -->
          <w:rPr>...</w:rPr>  <!-- run properties (formatting) -->
          <w:t>Hello @name@</w:t>  <!-- text -->
        </w:r>
      </w:p>

  ## Split Placeholders

  Word often splits placeholders across multiple `<w:t>` elements. Documents must be
  normalized using `Ootempl.Xml.Normalizer` before calling this module to ensure
  placeholders are consolidated. The main `Ootempl.render/3` API handles this
  automatically.

  ## Examples

      Replacing placeholders in a Word document:

          data = %{"name" => "World"}
          {:ok, doc} = Ootempl.Xml.parse("<w:p><w:r><w:t>Hello @name@</w:t></w:r></w:p>")
          {:ok, result} = Ootempl.Replacement.replace_in_document(doc, data)
          # result now contains "Hello World"
  """

  import Ootempl.Xml

  alias Ootempl.DataAccess
  alias Ootempl.Placeholder
  alias Ootempl.PlaceholderError

  require Record

  @type xml_element :: Ootempl.Xml.xml_element()
  @type xml_text :: Ootempl.Xml.xml_text()
  @type xml_node :: Ootempl.Xml.xml_node()

  @type placeholder_error_detail :: %{
          placeholder: String.t(),
          reason: DataAccess.error_reason()
        }

  @doc """
  Replaces all placeholders in the document XML with values from the data map.

  Processes the entire document tree, replacing placeholders while preserving all
  formatting. Collects all errors and returns them together for batch reporting.

  Note: This function expects the document to already be normalized (split placeholders
  merged). Use `Ootempl.Xml.Normalizer.normalize/1` first if needed, or use the
  high-level `Ootempl.render/3` API which handles normalization automatically.

  ## Parameters

    - `xml_element` - The root XML element (typically the document root)
    - `data` - Map containing replacement values (string keys)

  ## Returns

    - `{:ok, modified_xml}` - Modified XML with all replacements applied
    - `{:error, %PlaceholderError{}}` - Struct containing all placeholder resolution errors

  ## Examples

      Successful replacement:

          import Ootempl.Xml
          {:ok, doc} = Ootempl.Xml.parse("<w:p><w:r><w:t>@name@</w:t></w:r></w:p>")
          Ootempl.Replacement.replace_in_document(doc, %{"name" => "John"})
          # => {:ok, modified_xml}

      Missing placeholder:

          {:ok, doc} = Ootempl.Xml.parse("<w:p><w:r><w:t>@missing@</w:t></w:r></w:p>")
          Ootempl.Replacement.replace_in_document(doc, %{})
          # => {:error, %Ootempl.PlaceholderError{
          #      message: "Placeholder @missing@ could not be resolved",
          #      placeholders: [%{placeholder: "@missing@", reason: {:path_not_found, ["missing"]}}]
          #    }}
  """
  @spec replace_in_document(xml_element(), map()) ::
          {:ok, xml_element()} | {:error, PlaceholderError.t()}
  def replace_in_document(xml_element, data) when is_map(data) do
    case traverse_and_replace(xml_element, data) do
      {:ok, modified, []} ->
        {:ok, modified}

      {:ok, _modified, errors} ->
        # Convert error tuples to maps
        placeholder_errors =
          Enum.map(errors, fn {placeholder, reason} ->
            %{placeholder: placeholder, reason: reason}
          end)

        error = PlaceholderError.exception(placeholders: placeholder_errors)
        {:error, error}
    end
  end

  @spec replace_in_text_node(xml_text(), map()) ::
          {:ok, xml_text(), [{String.t(), DataAccess.error_reason()}]}
  defp replace_in_text_node(text_node, data) do
    text = text_node |> xmlText(:value) |> List.to_string()
    placeholders = Placeholder.detect(text)

    # Collect all replacement results
    {modified_text, errors} =
      Enum.reduce(placeholders, {text, []}, fn placeholder, {current_text, acc_errors} ->
        case DataAccess.get_value(data, placeholder.path) do
          {:ok, value} ->
            escaped_value = xml_escape(value)
            new_text = String.replace(current_text, placeholder.original, escaped_value)
            {new_text, acc_errors}

          {:error, reason} ->
            # Store as {placeholder, reason} tuple
            error = {placeholder.original, reason}
            {current_text, [error | acc_errors]}
        end
      end)

    # Reverse errors to maintain order
    errors = Enum.reverse(errors)

    # Only modify the text node if there were no errors
    if errors == [] do
      modified_node = xmlText(text_node, value: String.to_charlist(modified_text))
      {:ok, modified_node, []}
    else
      {:ok, text_node, errors}
    end
  end

  @spec xml_escape(String.t()) :: String.t()
  defp xml_escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  # Private functions

  @spec traverse_and_replace(xml_element(), map()) ::
          {:ok, xml_element(), [{String.t(), DataAccess.error_reason()}]}
  defp traverse_and_replace(element, data) do
    content = xmlElement(element, :content)

    # Process all child nodes and collect errors
    {modified_content, all_errors} =
      Enum.reduce(content, {[], []}, fn node, {acc_content, acc_errors} ->
        {:ok, modified_node, node_errors} = process_node(node, data)
        {[modified_node | acc_content], acc_errors ++ node_errors}
      end)

    # Reverse to maintain original order
    modified_content = Enum.reverse(modified_content)
    modified_element = xmlElement(element, content: modified_content)

    {:ok, modified_element, all_errors}
  end

  @spec process_node(xml_node(), map()) ::
          {:ok, xml_node(), [{String.t(), DataAccess.error_reason()}]}
  defp process_node(node, data) do
    cond do
      Record.is_record(node, :xmlText) ->
        replace_in_text_node(node, data)

      Record.is_record(node, :xmlElement) ->
        traverse_and_replace(node, data)

      true ->
        # Other node types (comments, etc.) pass through unchanged
        {:ok, node, []}
    end
  end
end
