defmodule Ootempl.ConditionalRenderer do
  @moduledoc """
  Applies `{{if}}` / `{{else}}` / `{{endif}}` sections to a parsed document part
  (body, header, footer, notes).

  Two forms are supported:

  - **Inline**: all of a section's markers sit in one paragraph, e.g.
    `Dear {{if formal}}Sir{{else}}friend{{endif}},`. Only the text (and any
    run content such as breaks or images) between the markers is kept or
    removed; the rest of the paragraph is untouched.
  - **Paragraph-level**: each marker sits in a paragraph of its own, and the
    paragraphs between them are kept or removed. The marker paragraphs must be
    siblings (e.g. all in the body, or all in one table cell) and hold nothing
    but markers; otherwise an error is returned rather than deleting content
    that happens to share a paragraph with a marker.

  Sections are processed innermost first. Nodes are addressed by their path in
  the tree, so identical-looking paragraphs elsewhere are never affected.
  """

  import Ootempl.Xml

  alias Ootempl.Conditional

  require Record

  @zero_width_elements [
    :"w:proofErr",
    :"w:bookmarkStart",
    :"w:bookmarkEnd",
    :"w:commentRangeStart",
    :"w:commentRangeEnd",
    :"w:permStart",
    :"w:permEnd"
  ]

  @type section :: %{if: map(), else: map() | nil, endif: map()}

  @doc """
  Processes every conditional section in `root`.

  Returns `{:ok, root}` with sections applied, or `{:error, reason}` where
  reason is one of:

  - `{:conditional_validation_failed, reason}` - markers are unbalanced
  - `{:conditional_evaluation_failed, condition, reason}` - the condition
    could not be evaluated against the data
  - `{:conditional_marker_not_alone, paragraph_text}` - a marker of a
    multi-paragraph section shares its paragraph with other text
  - `{:conditional_section_spans_containers, condition}` - a multi-paragraph
    section's markers are not siblings (e.g. one is inside a table)
  """
  @spec process(Ootempl.Xml.xml_element(), map()) :: {:ok, Ootempl.Xml.xml_element()} | {:error, term()}
  def process(root, data) do
    markers = Enum.flat_map(paragraphs(root), fn {_path, p} -> Conditional.detect_markers(paragraph_text(p)) end)

    cond do
      markers == [] ->
        {:ok, root}

      (validation = Conditional.validate_pairs(markers)) != :ok ->
        {:error, reason} = validation
        {:error, {:conditional_validation_failed, reason}}

      true ->
        with {:ok, root} <- process_inline(root, data) do
          process_sections(root, data)
        end
    end
  end

  # Inline sections: all markers in one paragraph.

  @spec process_inline(Ootempl.Xml.xml_element(), map()) :: {:ok, Ootempl.Xml.xml_element()} | {:error, term()}
  defp process_inline(root, data) do
    found =
      Enum.find_value(paragraphs(root), fn {path, paragraph} ->
        section = paragraph |> paragraph_text() |> Conditional.detect_markers() |> first_section()
        section && {path, section}
      end)

    case found do
      nil ->
        {:ok, root}

      {path, section} ->
        with {:ok, keep?} <- evaluate(section, data) do
          root
          |> update_at(path, &cut(&1, inline_cut_ranges(section, keep?)))
          |> process_inline(data)
        end
    end
  end

  @spec inline_cut_ranges(section(), boolean()) :: [{non_neg_integer(), non_neg_integer()}]
  defp inline_cut_ranges(%{if: if_m, else: nil, endif: endif_m}, true), do: [span(if_m), span(endif_m)]

  defp inline_cut_ranges(%{if: if_m, else: else_m, endif: endif_m}, true),
    do: [span(if_m), {else_m.position, stop(endif_m)}]

  defp inline_cut_ranges(%{if: if_m, else: nil, endif: endif_m}, false), do: [{if_m.position, stop(endif_m)}]

  defp inline_cut_ranges(%{if: if_m, else: else_m, endif: endif_m}, false),
    do: [{if_m.position, stop(else_m)}, span(endif_m)]

  # Paragraph-level sections: markers in sibling paragraphs of their own.

  @spec process_sections(Ootempl.Xml.xml_element(), map()) :: {:ok, Ootempl.Xml.xml_element()} | {:error, term()}
  defp process_sections(root, data) do
    located =
      for {path, paragraph} <- paragraphs(root),
          marker <- Conditional.detect_markers(paragraph_text(paragraph)),
          do: Map.put(marker, :location, path)

    case first_section(located) do
      nil ->
        {:ok, root}

      section ->
        with :ok <- check_markers_alone(root, section),
             :ok <- check_siblings(section),
             {:ok, keep?} <- evaluate(section, data) do
          root |> apply_section(section, keep?) |> process_sections(data)
        end
    end
  end

  @spec check_markers_alone(Ootempl.Xml.xml_element(), section()) :: :ok | {:error, term()}
  defp check_markers_alone(root, section) do
    section
    |> markers()
    |> Enum.map(&(root |> get_at(&1.location) |> paragraph_text()))
    |> Enum.find(fn text -> text |> without_markers() |> String.trim() != "" end)
    |> case do
      nil -> :ok
      text -> {:error, {:conditional_marker_not_alone, String.trim(text)}}
    end
  end

  @spec check_siblings(section()) :: :ok | {:error, term()}
  defp check_siblings(section) do
    parents = section |> markers() |> Enum.map(&parent_path(&1.location)) |> Enum.uniq()

    if length(parents) == 1,
      do: :ok,
      else: {:error, {:conditional_section_spans_containers, section.if.condition}}
  end

  # Removes the sibling nodes of the branch not taken, then cuts the markers
  # from their paragraphs and drops paragraphs left empty.
  @spec apply_section(Ootempl.Xml.xml_element(), section(), boolean()) :: Ootempl.Xml.xml_element()
  defp apply_section(root, section, keep?) do
    index = &List.last(&1.location)
    removed = removed_indexes(section, keep?, index)
    marker_cuts = section |> markers() |> Enum.group_by(index, &span/1)

    update_at(root, parent_path(section.if.location), fn parent ->
      content = xmlElement(parent, :content)

      new_content =
        content
        |> Enum.with_index()
        |> Enum.flat_map(&apply_to_child(&1, removed, marker_cuts))

      xmlElement(parent, content: keep_cell_paragraph(parent, new_content, Enum.at(content, index.(section.if))))
    end)
  end

  defp apply_to_child({child, i}, removed, marker_cuts) do
    cond do
      i in removed -> []
      Map.has_key?(marker_cuts, i) -> child |> cut(marker_cuts[i]) |> drop_if_empty()
      true -> [child]
    end
  end

  @spec removed_indexes(section(), boolean(), (map() -> non_neg_integer())) :: Range.t()
  defp removed_indexes(%{else: nil}, true, _index), do: 0..-1//1
  defp removed_indexes(%{else: else_m, endif: endif_m}, true, index), do: (index.(else_m) + 1)..(index.(endif_m) - 1)//1

  defp removed_indexes(%{if: if_m} = section, false, index) do
    (index.(if_m) + 1)..(index.(section.else || section.endif) - 1)//1
  end

  @spec drop_if_empty(Ootempl.Xml.xml_element()) :: [Ootempl.Xml.xml_element()]
  defp drop_if_empty(paragraph) do
    if paragraph |> xmlElement(:content) |> Enum.all?(&ignorable?/1), do: [], else: [paragraph]
  end

  # A table cell must contain a paragraph; if a section emptied the cell, keep
  # an empty paragraph (with the marker paragraph's properties).
  @spec keep_cell_paragraph(Ootempl.Xml.xml_element(), [Ootempl.Xml.xml_node()], Ootempl.Xml.xml_element()) ::
          [Ootempl.Xml.xml_node()]
  defp keep_cell_paragraph(parent, content, marker_paragraph) do
    if xmlElement(parent, :name) == :"w:tc" and not Enum.any?(content, &paragraph?/1) do
      properties = marker_paragraph |> xmlElement(:content) |> Enum.filter(&properties?/1)
      content ++ [xmlElement(marker_paragraph, content: properties)]
    else
      content
    end
  end

  # Shared helpers

  # The first section to close when reading markers in order, i.e. an
  # innermost one. Markers with no partner in `markers` are skipped.
  @spec first_section([map()]) :: section() | nil
  defp first_section(markers), do: first_section(markers, [])

  defp first_section([], _stack), do: nil
  defp first_section([%{type: :if} = m | rest], stack), do: first_section(rest, [{m, nil} | stack])
  defp first_section([%{type: :else} = m | rest], [{if_m, _} | stack]), do: first_section(rest, [{if_m, m} | stack])
  defp first_section([%{type: :endif} = m | _rest], [{if_m, else_m} | _]), do: %{if: if_m, else: else_m, endif: m}
  defp first_section([_unpaired | rest], []), do: first_section(rest, [])

  @spec evaluate(section(), map()) :: {:ok, boolean()} | {:error, term()}
  defp evaluate(%{if: if_m}, data) do
    case Conditional.evaluate_condition(if_m.path, data) do
      {:ok, keep?} -> {:ok, keep?}
      {:error, reason} -> {:error, {:conditional_evaluation_failed, if_m.condition, reason}}
    end
  end

  defp markers(section), do: Enum.reject([section.if, section.else, section.endif], &is_nil/1)
  defp span(marker), do: {marker.position, stop(marker)}
  defp stop(marker), do: marker.position + marker.length
  defp parent_path(path), do: Enum.drop(path, -1)

  @spec without_markers(String.t()) :: String.t()
  defp without_markers(text) do
    text
    |> Conditional.detect_markers()
    |> Enum.reverse()
    |> Enum.reduce(text, fn m, acc ->
      binary_part(acc, 0, m.position) <> binary_part(acc, stop(m), byte_size(acc) - stop(m))
    end)
  end

  # Removes the byte ranges `ranges` of a paragraph's text. Run content that
  # occupies no text (breaks, tabs, images, ...) is removed when it lies
  # strictly inside a range; runs and other containers emptied by the cut are
  # removed too. Nested paragraphs (text boxes) are left alone.
  @spec cut(Ootempl.Xml.xml_element(), [{non_neg_integer(), non_neg_integer()}]) :: Ootempl.Xml.xml_element()
  defp cut(paragraph, ranges) do
    {content, _offset, _removed?} = cut_children(xmlElement(paragraph, :content), 0, ranges)
    xmlElement(paragraph, content: content)
  end

  defp cut_children(nodes, offset, ranges) do
    {content, {offset, removed?}} =
      Enum.flat_map_reduce(nodes, {offset, false}, fn node, {offset, removed?} ->
        {new_nodes, offset, node_removed?} = cut_node(node, offset, ranges)
        {new_nodes, {offset, removed? or node_removed?}}
      end)

    {content, offset, removed?}
  end

  defp cut_node(node, offset, ranges) do
    cond do
      text_element?(node) -> cut_text_element(node, offset, ranges)
      not element?(node) or properties?(node) or paragraph?(node) -> {[node], offset, false}
      not contains_text_element?(node) -> cut_atomic(node, offset, ranges)
      true -> cut_container(node, offset, ranges)
    end
  end

  defp cut_text_element(node, offset, ranges) do
    text = text_of(node)
    stop = offset + byte_size(text)

    case keep_bytes(text, offset, ranges) do
      ^text -> {[node], stop, false}
      "" -> {[], stop, true}
      kept -> {[put_text(node, kept)], stop, true}
    end
  end

  defp cut_atomic(node, offset, ranges) do
    if Enum.any?(ranges, fn {from, to} -> from < offset and offset < to end),
      do: {[], offset, true},
      else: {[node], offset, false}
  end

  defp cut_container(node, offset, ranges) do
    {content, stop, removed?} = cut_children(xmlElement(node, :content), offset, ranges)

    if removed? and Enum.all?(content, &(properties?(&1) or not element?(&1))),
      do: {[], stop, true},
      else: {[xmlElement(node, content: content)], stop, removed?}
  end

  # The bytes of `text` (which starts at `offset`) outside `ranges`.
  @spec keep_bytes(String.t(), non_neg_integer(), [{non_neg_integer(), non_neg_integer()}]) :: String.t()
  defp keep_bytes(text, offset, ranges) do
    size = byte_size(text)

    {kept, last} =
      ranges
      |> Enum.map(fn {from, to} -> {max(from - offset, 0), min(to - offset, size)} end)
      |> Enum.filter(fn {from, to} -> from < to end)
      |> Enum.sort()
      |> Enum.reduce({[], 0}, fn {from, to}, {acc, pos} -> {[acc, binary_part(text, pos, from - pos)], to} end)

    IO.iodata_to_binary([kept, binary_part(text, last, size - last)])
  end

  # Tree helpers

  # Every paragraph with its path (child indexes from `root`), in document
  # order, including paragraphs nested in text boxes.
  @spec paragraphs(Ootempl.Xml.xml_element(), [non_neg_integer()]) :: [{[non_neg_integer()], Ootempl.Xml.xml_element()}]
  defp paragraphs(node, path \\ []) do
    node
    |> xmlElement(:content)
    |> Enum.with_index()
    |> Enum.flat_map(fn {child, i} ->
      cond do
        paragraph?(child) -> [{path ++ [i], child} | paragraphs(child, path ++ [i])]
        element?(child) -> paragraphs(child, path ++ [i])
        true -> []
      end
    end)
  end

  # Text of a paragraph's <w:t> elements, excluding nested paragraphs.
  @spec paragraph_text(Ootempl.Xml.xml_element()) :: String.t()
  defp paragraph_text(element) do
    element
    |> xmlElement(:content)
    |> Enum.map_join(fn node ->
      cond do
        text_element?(node) -> text_of(node)
        paragraph?(node) or not element?(node) -> ""
        true -> paragraph_text(node)
      end
    end)
  end

  defp contains_text_element?(element) do
    element
    |> xmlElement(:content)
    |> Enum.any?(&(text_element?(&1) or (element?(&1) and not paragraph?(&1) and contains_text_element?(&1))))
  end

  defp get_at(node, []), do: node
  defp get_at(node, [i | rest]), do: node |> xmlElement(:content) |> Enum.at(i) |> get_at(rest)

  defp update_at(node, [], fun), do: fun.(node)

  defp update_at(node, [i | rest], fun) do
    xmlElement(node, content: List.update_at(xmlElement(node, :content), i, &update_at(&1, rest, fun)))
  end

  defp text_of(text_element) do
    text_element
    |> xmlElement(:content)
    |> Enum.filter(&Record.is_record(&1, :xmlText))
    |> Enum.map_join(&List.to_string(xmlText(&1, :value)))
  end

  # Paragraph content that does not show anything: properties, whitespace,
  # zero-width markers and runs holding only properties.
  defp ignorable?(node) do
    not element?(node) or properties?(node) or xmlElement(node, :name) in @zero_width_elements or
      (xmlElement(node, :name) == :"w:r" and node |> xmlElement(:content) |> Enum.all?(&ignorable?/1))
  end

  defp element?(node), do: Record.is_record(node, :xmlElement)
  defp paragraph?(node), do: element?(node) and xmlElement(node, :name) == :"w:p"
  defp text_element?(node), do: element?(node) and xmlElement(node, :name) == :"w:t"

  defp properties?(node) do
    element?(node) and node |> xmlElement(:name) |> Atom.to_string() |> String.ends_with?("Pr")
  end
end
