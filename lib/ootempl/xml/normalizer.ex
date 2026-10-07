defmodule Ootempl.Xml.Normalizer do
  @moduledoc """
  XML normalization for fragmented placeholders in Word documents.

  Microsoft Word often fragments placeholders across multiple XML runs and text
  elements due to spell-checking, grammar-checking, formatting changes, or editing
  history. This module normalizes the XML so every `{{...}}` token sits inside a
  single `<w:t>` element, without merging runs.

  The whole token is moved into the `<w:t>` where it starts, and the pieces of it
  are removed from the elements that follow. Text outside the token stays in its
  original run, so its formatting, attributes and any non-text run content
  (tabs, breaks, symbols, fields) are untouched. The token takes the formatting
  of the run it starts in, which is how Word itself treats a selection.

  Zero-width markers that Word scatters between runs (proofing errors,
  bookmarks, comment and permission ranges) do not interrupt a token. Runs
  nested in paragraph-level containers such as hyperlinks, tracked insertions,
  smart tags and content controls are normalized within their container.

  ## Example

  Fragmented placeholder:
  ```xml
  <w:r><w:rPr><w:b/></w:rPr><w:t>Hello {{</w:t></w:r>
  <w:proofErr w:type="gramStart"/>
  <w:r><w:t>person.first</w:t></w:r>
  <w:proofErr w:type="gramEnd"/>
  <w:r><w:t>_name}}, how are you?</w:t></w:r>
  ```

  After normalization:
  ```xml
  <w:r><w:rPr><w:b/></w:rPr><w:t>Hello {{person.first_name}}</w:t></w:r>
  <w:proofErr w:type="gramStart"/>
  <w:proofErr w:type="gramEnd"/>
  <w:r><w:t>, how are you?</w:t></w:r>
  ```

  ## Usage

      {:ok, xml_doc} = Ootempl.Xml.parse(xml_string)
      normalized_doc = Ootempl.Xml.Normalizer.normalize(xml_doc)
      {:ok, output} = Ootempl.Xml.serialize(normalized_doc)
  """

  import Ootempl.Xml

  require Record

  # Any `{{...}}` token: placeholders, conditional and block markers, and image
  # markers. Escaped `\{{` is not a token.
  @token_regex ~r/(?<!\\)\{\{[^{}]*\}\}/

  # Elements that occupy no text position, so a token may span across them.
  @zero_width_elements [
    :"w:proofErr",
    :"w:bookmarkStart",
    :"w:bookmarkEnd",
    :"w:commentRangeStart",
    :"w:commentRangeEnd",
    :"w:permStart",
    :"w:permEnd"
  ]

  @doc """
  Normalizes an XML document by moving each fragmented `{{...}}` token into the
  `<w:t>` element where it starts.

  Recursively traverses the XML tree; any element whose children include runs
  is normalized.

  ## Parameters

    - `xml_node` - An xmerl XML element or text node

  ## Returns

    - The normalized XML node
  """
  @spec normalize(Ootempl.Xml.xml_node()) :: Ootempl.Xml.xml_node()
  def normalize(xml_node) do
    if element_node?(xml_node) do
      content =
        xml_node
        |> xmlElement(:content)
        |> normalize_runs()
        |> Enum.map(&normalize/1)

      xmlElement(xml_node, content: content)
    else
      # Text nodes and other node types pass through unchanged
      xml_node
    end
  end

  # Private functions

  # Splits sibling nodes into segments of runs that a token may span, and
  # normalizes each segment.
  @spec normalize_runs([Ootempl.Xml.xml_node()]) :: [Ootempl.Xml.xml_node()]
  defp normalize_runs(nodes) do
    if Enum.any?(nodes, &run_node?/1) do
      nodes
      |> Enum.chunk_by(&segment_node?/1)
      |> Enum.flat_map(&normalize_chunk/1)
    else
      nodes
    end
  end

  @spec normalize_chunk([Ootempl.Xml.xml_node()]) :: [Ootempl.Xml.xml_node()]
  defp normalize_chunk([first | _] = chunk) do
    if segment_node?(first), do: normalize_segment(chunk), else: chunk
  end

  @spec segment_node?(Ootempl.Xml.xml_node()) :: boolean()
  defp segment_node?(node), do: run_node?(node) or transparent?(node)

  # Within a segment, moves every token that crosses a <w:t> boundary into the
  # <w:t> where it starts.
  @spec normalize_segment([Ootempl.Xml.xml_node()]) :: [Ootempl.Xml.xml_node()]
  defp normalize_segment(nodes) do
    texts =
      for node <- nodes, run_node?(node), child <- xmlElement(node, :content), text_element?(child), do: text_of(child)

    full_text = Enum.join(texts)
    boundaries = texts |> Enum.scan(0, &(byte_size(&1) + &2)) |> List.delete_at(-1)
    tokens = Regex.scan(@token_regex, full_text, return: :index)

    new_boundaries = Enum.map(boundaries, &move_out_of_tokens(&1, tokens))

    if new_boundaries == boundaries do
      nodes
    else
      starts = [0 | new_boundaries]
      ends = new_boundaries ++ [byte_size(full_text)]

      new_texts =
        starts
        |> Enum.zip(ends)
        |> Enum.map(fn {from, to} -> binary_part(full_text, from, to - from) end)

      {rewritten, []} = rewrite_texts(nodes, Enum.zip(texts, new_texts))
      rewritten
    end
  end

  # A boundary inside a token moves to the token's end, so the whole token
  # belongs to the <w:t> where it starts.
  @spec move_out_of_tokens(non_neg_integer(), [[{non_neg_integer(), non_neg_integer()}]]) :: non_neg_integer()
  defp move_out_of_tokens(boundary, tokens) do
    Enum.find_value(tokens, boundary, fn [{start, length}] ->
      if start < boundary and boundary < start + length, do: start + length
    end)
  end

  # Writes the new texts back into the segment's <w:t> elements, in order.
  # Emptied <w:t> elements are removed, and so are runs left with nothing but
  # run properties.
  @spec rewrite_texts([Ootempl.Xml.xml_node()], [{String.t(), String.t()}]) ::
          {[Ootempl.Xml.xml_node()], [{String.t(), String.t()}]}
  defp rewrite_texts(nodes, texts) do
    Enum.flat_map_reduce(nodes, texts, fn node, remaining ->
      if run_node?(node), do: rewrite_run(node, remaining), else: {[node], remaining}
    end)
  end

  @spec rewrite_run(Ootempl.Xml.xml_element(), [{String.t(), String.t()}]) ::
          {[Ootempl.Xml.xml_element()], [{String.t(), String.t()}]}
  defp rewrite_run(run, texts) do
    old_content = xmlElement(run, :content)

    {content, remaining} =
      Enum.flat_map_reduce(old_content, texts, fn child, remaining ->
        if text_element?(child), do: rewrite_text_element(child, remaining), else: {[child], remaining}
      end)

    emptied? = content != old_content and Enum.all?(content, &(run_properties?(&1) or whitespace_text?(&1)))

    if emptied?, do: {[], remaining}, else: {[xmlElement(run, content: content)], remaining}
  end

  defp rewrite_text_element(text_element, [{same, same} | remaining]), do: {[text_element], remaining}
  defp rewrite_text_element(_text_element, [{_old, ""} | remaining]), do: {[], remaining}

  defp rewrite_text_element(text_element, [{_old, new} | remaining]) do
    {[put_text(text_element, new)], remaining}
  end

  @spec text_of(Ootempl.Xml.xml_element()) :: String.t()
  defp text_of(text_element) do
    text_element
    |> xmlElement(:content)
    |> Enum.filter(&Record.is_record(&1, :xmlText))
    |> Enum.map_join(&List.to_string(xmlText(&1, :value)))
  end

  @spec element_node?(Ootempl.Xml.xml_node()) :: boolean()
  defp element_node?(node) do
    Record.is_record(node, :xmlElement)
  end

  @spec run_node?(Ootempl.Xml.xml_node()) :: boolean()
  defp run_node?(node) do
    element_node?(node) && xmlElement(node, :name) == :"w:r"
  end

  @spec text_element?(Ootempl.Xml.xml_node()) :: boolean()
  defp text_element?(node) do
    element_node?(node) && xmlElement(node, :name) == :"w:t"
  end

  @spec run_properties?(Ootempl.Xml.xml_node()) :: boolean()
  defp run_properties?(node) do
    element_node?(node) && xmlElement(node, :name) == :"w:rPr"
  end

  # Nodes that sit between runs without occupying a text position: zero-width
  # markers, and whitespace that only appears when the XML is pretty-printed.
  @spec transparent?(Ootempl.Xml.xml_node()) :: boolean()
  defp transparent?(node) do
    (element_node?(node) && xmlElement(node, :name) in @zero_width_elements) or whitespace_text?(node)
  end

  @spec whitespace_text?(Ootempl.Xml.xml_node()) :: boolean()
  defp whitespace_text?(node) do
    Record.is_record(node, :xmlText) && node |> xmlText(:value) |> List.to_string() |> String.trim() == ""
  end
end
