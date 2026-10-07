defmodule Ootempl.Replacement do
  @moduledoc """
  Replaces placeholders in Word XML text nodes while preserving formatting.

  This module handles the core XML manipulation logic for replacing `{{variable}}`
  placeholders with values from data maps. It handles the complexities of Word's
  XML structure, including:

  - Preserving Word formatting (bold, italic, font, size, color)
  - Storing replacement values as raw text (xmerl escapes them on serialization)
  - Marking `<w:t>` elements `xml:space="preserve"` when substituted text has
    leading or trailing whitespace
  - Turning line breaks and tabs in values into `<w:br/>` and `<w:tab/>`
  - Unescaping literal `\{{` and `\}}` sequences to `{{` and `}}`
  - Collecting all errors for batch reporting

  ## Word XML Structure

  Word stores text in `<w:t>` elements within `<w:r>` (run) elements that carry
  formatting:

      <w:p>  <!-- paragraph -->
        <w:r>  <!-- run with formatting -->
          <w:rPr>...</w:rPr>  <!-- run properties (formatting) -->
          <w:t>Hello {{name}}</w:t>  <!-- text -->
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
          {:ok, doc} = Ootempl.Xml.parse("<w:p><w:r><w:t>Hello {{name}}</w:t></w:r></w:p>")
          {:ok, result} = Ootempl.Replacement.replace_in_document(doc, data)
          # result now contains "Hello World"
  """

  import Ootempl.Xml

  alias Ootempl.DataAccess
  alias Ootempl.Filters
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
          {:ok, doc} = Ootempl.Xml.parse("<w:p><w:r><w:t>{{name}}</w:t></w:r></w:p>")
          Ootempl.Replacement.replace_in_document(doc, %{"name" => "John"})
          # => {:ok, modified_xml}

      Missing placeholder:

          {:ok, doc} = Ootempl.Xml.parse("<w:p><w:r><w:t>{{missing}}</w:t></w:r></w:p>")
          Ootempl.Replacement.replace_in_document(doc, %{})
          # => {:error, %Ootempl.PlaceholderError{
          #      message: "Placeholder {{missing}} could not be resolved",
          #      placeholders: [%{placeholder: "{{missing}}", reason: {:path_not_found, ["missing"]}}]
          #    }}
  """
  @spec replace_in_document(xml_element(), map(), Filters.registry()) ::
          {:ok, xml_element()} | {:error, PlaceholderError.t()}
  def replace_in_document(xml_element, data, filters \\ Filters.active_registry()) when is_map(data) do
    case traverse_and_replace(xml_element, data, filters) do
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

  @spec replace_in_text_node(xml_text(), map(), Filters.registry()) ::
          {:ok, xml_text(), [{String.t(), DataAccess.error_reason()}]}
  defp replace_in_text_node(text_node, data, filters) do
    text = text_node |> xmlText(:value) |> List.to_string()

    case replace_text(text, data, filters) do
      {:ok, ^text} -> {:ok, text_node, []}
      {:ok, new_text} -> {:ok, xmlText(text_node, value: String.to_charlist(new_text)), []}
      {:error, errors} -> {:ok, text_node, errors}
    end
  end

  # Replaces placeholders in a <w:t> element. Line breaks and tabs in the
  # result become <w:br/> and <w:tab/> siblings (Word shows a raw newline or tab
  # in <w:t> as a space), so one <w:t> may become several nodes in its run.
  @spec replace_in_text_element(xml_element(), map(), Filters.registry()) ::
          {:ok, [xml_node()], [{String.t(), DataAccess.error_reason()}]}
  defp replace_in_text_element(text_element, data, filters) do
    text =
      text_element
      |> xmlElement(:content)
      |> Enum.map_join(&List.to_string(xmlText(&1, :value)))

    case replace_text(text, data, filters) do
      {:ok, ^text} -> {:ok, [text_element], []}
      {:ok, new_text} -> {:ok, split_text_element(text_element, new_text), []}
      {:error, errors} -> {:ok, [text_element], errors}
    end
  end

  @spec split_text_element(xml_element(), String.t()) :: [xml_element()]
  defp split_text_element(text_element, text) do
    nodes =
      ~r/\r\n|\r|\n|\t/
      |> Regex.split(text, include_captures: true, trim: true)
      |> Enum.map(fn
        "\t" -> sibling_element(text_element, :"w:tab", ~c"tab")
        "\r\n" -> sibling_element(text_element, :"w:br", ~c"br")
        "\r" -> sibling_element(text_element, :"w:br", ~c"br")
        "\n" -> sibling_element(text_element, :"w:br", ~c"br")
        piece -> put_text(text_element, piece)
      end)

    if nodes == [], do: [put_text(text_element, "")], else: nodes
  end

  # An empty element in the same namespace as `element`, e.g. <w:br/>.
  @spec sibling_element(xml_element(), atom(), charlist()) :: xml_element()
  defp sibling_element(element, name, local_name) do
    {prefix, _local} = xmlElement(element, :nsinfo)
    xmlElement(element, name: name, expanded_name: name, nsinfo: {prefix, local_name}, attributes: [], content: [])
  end

  # Replaces every placeholder in `text`, then unescapes literal {{ and }}.
  # Returns all resolution errors if any placeholder cannot be resolved.
  @spec replace_text(String.t(), map(), Filters.registry()) ::
          {:ok, String.t()} | {:error, [{String.t(), DataAccess.error_reason()}]}
  defp replace_text(text, data, filters) do
    {new_text, errors} =
      text
      |> Placeholder.detect()
      |> Enum.reduce({text, []}, fn placeholder, {current_text, acc_errors} ->
        case resolve_value(data, placeholder, filters) do
          {:ok, value} ->
            # The value is stored as raw text; xmerl escapes it on export
            {String.replace(current_text, placeholder.original, value), acc_errors}

          {:error, reason} ->
            {current_text, [{placeholder.original, reason} | acc_errors]}
        end
      end)

    if errors == [] do
      {:ok, unescape_braces(new_text)}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  # Resolves a placeholder to its final string value: fetch the raw value,
  # run it through the filter chain, then convert the result to a string.
  @spec resolve_value(map(), Placeholder.placeholder(), Filters.registry()) ::
          {:ok, String.t()} | {:error, term()}
  defp resolve_value(data, placeholder, filters) do
    with {:ok, raw} <- DataAccess.get_raw_value(data, placeholder.path),
         {:ok, filtered} <- Filters.apply_chain(raw, placeholder.filters, filters) do
      DataAccess.to_string_value(filtered)
    end
  end

  @spec unescape_braces(String.t()) :: String.t()
  defp unescape_braces(text) when is_binary(text) do
    text
    |> String.replace("\\{{", "{{")
    |> String.replace("\\}}", "}}")
  end

  # Private functions

  @spec traverse_and_replace(xml_element(), map(), Filters.registry()) ::
          {:ok, xml_element(), [{String.t(), DataAccess.error_reason()}]}
  defp traverse_and_replace(element, data, filters) do
    content = xmlElement(element, :content)

    # Process all child nodes and collect errors
    {modified_content, all_errors} =
      Enum.reduce(content, {[], []}, fn node, {acc_content, acc_errors} ->
        {:ok, modified_nodes, node_errors} = process_node(node, data, filters)
        {Enum.reverse(List.wrap(modified_nodes), acc_content), acc_errors ++ node_errors}
      end)

    # Reverse to maintain original order
    modified_content = Enum.reverse(modified_content)
    modified_element = xmlElement(element, content: modified_content)

    {:ok, modified_element, all_errors}
  end

  @spec process_node(xml_node(), map(), Filters.registry()) ::
          {:ok, xml_node() | [xml_node()], [{String.t(), DataAccess.error_reason()}]}
  defp process_node(node, data, filters) do
    cond do
      Record.is_record(node, :xmlText) ->
        replace_in_text_node(node, data, filters)

      text_element?(node) ->
        replace_in_text_element(node, data, filters)

      paragraph?(node) ->
        {:ok, modified, errors} = traverse_and_replace(node, data, filters)
        {:ok, modified, split_placeholder_errors(node) ++ errors}

      Record.is_record(node, :xmlElement) ->
        traverse_and_replace(node, data, filters)

      true ->
        # Other node types (comments, etc.) pass through unchanged
        {:ok, node, []}
    end
  end

  # Placeholders visible in a paragraph's text but not contained in any single
  # <w:t>. The normalizer joins fragments within a run sequence, so these cross
  # a boundary it cannot (e.g. into a hyperlink) and would otherwise be left in
  # the output unreplaced.
  @spec split_placeholder_errors(xml_element()) :: [{String.t(), :split_placeholder}]
  defp split_placeholder_errors(paragraph) do
    texts = paragraph_texts(paragraph)
    whole = texts |> Enum.join() |> Placeholder.detect() |> Enum.map(& &1.original)
    contained = Enum.flat_map(texts, fn text -> text |> Placeholder.detect() |> Enum.map(& &1.original) end)

    Enum.map(whole -- contained, &{&1, :split_placeholder})
  end

  # Texts of the paragraph's <w:t> elements, excluding nested paragraphs
  # (e.g. inside text boxes), which are checked on their own.
  @spec paragraph_texts(xml_element()) :: [String.t()]
  defp paragraph_texts(element) do
    element
    |> xmlElement(:content)
    |> Enum.flat_map(fn node ->
      cond do
        text_element?(node) -> [node |> xmlElement(:content) |> Enum.map_join(&List.to_string(xmlText(&1, :value)))]
        paragraph?(node) -> []
        Record.is_record(node, :xmlElement) -> paragraph_texts(node)
        true -> []
      end
    end)
  end

  @spec paragraph?(xml_node()) :: boolean()
  defp paragraph?(node) do
    Record.is_record(node, :xmlElement) and xmlElement(node, :name) == :"w:p"
  end

  # A <w:t> element holding only text (the normal case)
  @spec text_element?(xml_node()) :: boolean()
  defp text_element?(node) do
    Record.is_record(node, :xmlElement) and xmlElement(node, :name) == :"w:t" and
      Enum.all?(xmlElement(node, :content), &Record.is_record(&1, :xmlText))
  end
end
