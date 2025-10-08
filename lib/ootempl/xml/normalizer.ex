defmodule Ootempl.Xml.Normalizer do
  @moduledoc """
  XML normalization for fragmented placeholders in Word documents.

  Microsoft Word often fragments placeholders across multiple XML runs and text
  elements due to spell-checking, grammar-checking, formatting changes, or editing
  history. This module normalizes the XML by collapsing fragmented placeholders
  into single text runs while preserving intentional formatting.

  ## Example

  Fragmented placeholder:
  ```xml
  <w:r><w:t>Hello {{</w:t></w:r>
  <w:proofErr w:type="gramStart"/>
  <w:r><w:t>person.first</w:t></w:r>
  <w:proofErr w:type="gramEnd"/>
  <w:r><w:t>_name}}, how are you?</w:t></w:r>
  ```

  After normalization:
  ```xml
  <w:r><w:t>Hello {{person.first_name}}, how are you?</w:t></w:r>
  ```

  ## Usage

      {:ok, xml_doc} = Ootempl.Xml.parse(xml_string)
      normalized_doc = Ootempl.Xml.Normalizer.normalize(xml_doc)
      {:ok, output} = Ootempl.Xml.serialize(normalized_doc)
  """

  import Ootempl.Xml

  alias Ootempl.Placeholder

  require Record

  # Add xmlNamespace record definition
  Record.defrecord(
    :xmlNamespace,
    Record.extract(:xmlNamespace, from_lib: "xmerl/include/xmerl.hrl")
  )

  @doc """
  Normalizes an XML document by collapsing fragmented placeholders.

  Recursively traverses the XML tree and normalizes all paragraphs that
  contain fragmented placeholders.

  ## Parameters

    - `xml_node` - An xmerl XML element or text node

  ## Returns

    - The normalized XML node
  """
  @spec normalize(Ootempl.Xml.xml_node()) :: Ootempl.Xml.xml_node()
  def normalize(xml_node) do
    if element_node?(xml_node) do
      normalize_element(xml_node)
    else
      # Text nodes and other node types pass through unchanged
      xml_node
    end
  end

  # Private functions

  @spec normalize_element(Ootempl.Xml.xml_element()) :: Ootempl.Xml.xml_element()
  defp normalize_element(element) do
    element_name = xmlElement(element, :name)

    if element_name == :"w:p" do
      normalize_paragraph(element)
    else
      # For non-paragraph elements, recursively normalize children
      content = xmlElement(element, :content)
      normalized_content = Enum.map(content, &normalize/1)
      xmlElement(element, content: normalized_content)
    end
  end

  @spec normalize_paragraph(Ootempl.Xml.xml_element()) :: Ootempl.Xml.xml_element()
  defp normalize_paragraph(paragraph) do
    content = xmlElement(paragraph, :content)
    # Filter out proofing errors
    filtered_content = Enum.reject(content, &proofing_error?/1)
    # Process content to find and collapse placeholders
    normalized_content = process_runs_for_placeholders(filtered_content, [])
    xmlElement(paragraph, content: normalized_content)
  end

  # Scan runs to find placeholder spans and collapse them
  @spec process_runs_for_placeholders([Ootempl.Xml.xml_node()], [Ootempl.Xml.xml_node()]) ::
          [Ootempl.Xml.xml_node()]
  defp process_runs_for_placeholders([], acc), do: Enum.reverse(acc)

  defp process_runs_for_placeholders(nodes, acc) do
    case find_placeholder_span(nodes) do
      {:found, placeholder_text, _span_runs, remaining_nodes, consistent_props} ->
        # Create collapsed run with appropriate formatting
        collapsed_run = create_collapsed_run(placeholder_text, consistent_props)
        process_runs_for_placeholders(remaining_nodes, [collapsed_run | acc])

      {:no_placeholder, first_node, rest} ->
        # No placeholder found, keep first node and continue
        normalized_first = normalize(first_node)
        process_runs_for_placeholders(rest, [normalized_first | acc])
    end
  end

  # Find a span of runs that contains a complete placeholder
  @spec find_placeholder_span([Ootempl.Xml.xml_node()]) ::
          {:found, String.t(), [Ootempl.Xml.xml_element()], [Ootempl.Xml.xml_node()], Ootempl.Xml.xml_element() | nil}
          | {:no_placeholder, Ootempl.Xml.xml_node(), [Ootempl.Xml.xml_node()]}
  defp find_placeholder_span(nodes), do: scan_for_placeholder(nodes, "", [], [])

  @spec scan_for_placeholder(
          [Ootempl.Xml.xml_node()],
          String.t(),
          [Ootempl.Xml.xml_element()],
          [Ootempl.Xml.xml_element() | nil]
        ) ::
          {:found, String.t(), [Ootempl.Xml.xml_element()], [Ootempl.Xml.xml_node()], Ootempl.Xml.xml_element() | nil}
          | {:no_placeholder, Ootempl.Xml.xml_node(), [Ootempl.Xml.xml_node()]}
  defp scan_for_placeholder([], _accumulated_text, span_runs, _properties) do
    # Reached end without finding complete placeholder
    # Return first run from span if we accumulated any
    if length(span_runs) > 0 do
      [first | _] = span_runs
      {:no_placeholder, first, []}
    else
      {:no_placeholder, nil, []}
    end
  end

  defp scan_for_placeholder([current | rest] = nodes, accumulated_text, span_runs, all_properties) do
    if run_node?(current) do
      run_text = extract_run_text(current)
      run_props = extract_run_properties(current)
      new_text = accumulated_text <> run_text
      new_span = span_runs ++ [current]
      new_props = all_properties ++ [run_props]

      # Check if we have a complete placeholder
      placeholders = Placeholder.detect(new_text)

      cond do
        length(placeholders) > 0 ->
          # Found complete placeholder - check formatting consistency
          consistent_props = check_formatting_consistency(new_props)
          {:found, new_text, new_span, rest, consistent_props}

        potentially_building_placeholder?(new_text) && length(rest) > 0 ->
          # Keep scanning if there are more nodes
          scan_for_placeholder(rest, new_text, new_span, new_props)

        true ->
          # Not building a placeholder
          handle_no_placeholder(span_runs, current, rest)
      end
    else
      # Non-run node - can't be part of placeholder
      if length(span_runs) > 0 do
        # We accumulated some runs but hit a non-run node
        # Return first accumulated run and put everything else back
        [first_span | remaining_spans] = span_runs
        remaining_nodes = remaining_spans ++ nodes
        {:no_placeholder, first_span, remaining_nodes}
      else
        # First node is non-run, just return it
        {:no_placeholder, current, rest}
      end
    end
  end

  # Handle case where we didn't find a placeholder
  @spec handle_no_placeholder([Ootempl.Xml.xml_element()], Ootempl.Xml.xml_node(), [Ootempl.Xml.xml_node()]) ::
          {:no_placeholder, Ootempl.Xml.xml_node(), [Ootempl.Xml.xml_node()]}
  defp handle_no_placeholder(span_runs, current, rest) do
    if Enum.empty?(span_runs) do
      # First iteration, return current node
      {:no_placeholder, current, rest}
    else
      # We accumulated some text but no placeholder found
      # Return the first node we accumulated and put rest back
      [first_span | remaining_spans] = span_runs
      remaining_nodes = remaining_spans ++ [current | rest]
      {:no_placeholder, first_span, remaining_nodes}
    end
  end

  # Check formatting consistency and return the most common formatting (majority rule)
  @spec check_formatting_consistency([Ootempl.Xml.xml_element() | nil]) ::
          Ootempl.Xml.xml_element() | nil
  defp check_formatting_consistency(properties) do
    # Count occurrences of each unique formatting
    frequency_map =
      Enum.reduce(properties, %{}, fn props, acc ->
        key = serialize_props(props)

        Map.update(acc, key, {props, 1}, fn {existing_props, count} ->
          {existing_props, count + 1}
        end)
      end)

    # Find the formatting with the highest count
    case Enum.max_by(frequency_map, fn {_key, {_props, count}} -> count end, fn -> nil end) do
      {_key, {props, max_count}} ->
        # Check if there's a tie - if multiple formattings have the same max count, strip all
        tie_exists =
          frequency_map
          |> Enum.filter(fn {_key, {_props, count}} -> count == max_count end)
          |> length() > 1

        if tie_exists do
          nil
        else
          props
        end

      nil ->
        nil
    end
  end

  @spec serialize_props(Ootempl.Xml.xml_element() | nil) :: String.t()
  defp serialize_props(nil), do: "nil"

  defp serialize_props(props) do
    # Serialize properties for comparison
    props
    |> xmlElement(:content)
    |> Enum.map(fn elem -> xmlElement(elem, :name) end)
    |> Enum.sort()
    |> inspect()
  end

  # Check if text might be building toward a placeholder
  @spec potentially_building_placeholder?(String.t()) :: boolean()
  defp potentially_building_placeholder?(text) do
    # If text contains {{ and we haven't found a complete placeholder yet, keep scanning
    # Look for {{ that might be the start of a placeholder
    String.contains?(text, "{{") or String.contains?(text, "{")
  end

  @spec element_node?(Ootempl.Xml.xml_node()) :: boolean()
  defp element_node?(node) do
    Record.is_record(node, :xmlElement)
  end

  @spec proofing_error?(Ootempl.Xml.xml_node()) :: boolean()
  defp proofing_error?(node) do
    element_node?(node) && xmlElement(node, :name) == :"w:proofErr"
  end

  @spec run_node?(Ootempl.Xml.xml_node()) :: boolean()
  defp run_node?(node) do
    element_node?(node) && xmlElement(node, :name) == :"w:r"
  end

  @spec extract_run_text(Ootempl.Xml.xml_element()) :: String.t()
  defp extract_run_text(run) do
    run
    |> xmlElement(:content)
    |> Enum.filter(fn node ->
      element_node?(node) && xmlElement(node, :name) == :"w:t"
    end)
    |> Enum.map_join(fn text_elem ->
      text_elem
      |> xmlElement(:content)
      |> Enum.filter(&Record.is_record(&1, :xmlText))
      |> Enum.map(&xmlText(&1, :value))
      |> Enum.map_join(&List.to_string/1)
    end)
  end

  @spec extract_run_properties(Ootempl.Xml.xml_element()) :: Ootempl.Xml.xml_element() | nil
  defp extract_run_properties(run) do
    run
    |> xmlElement(:content)
    |> Enum.find(fn node ->
      element_node?(node) && xmlElement(node, :name) == :"w:rPr"
    end)
  end

  @spec create_collapsed_run(String.t(), Ootempl.Xml.xml_element() | nil) ::
          Ootempl.Xml.xml_element()
  defp create_collapsed_run(text, run_props) do
    # Create text node
    text_node = xmlText(value: String.to_charlist(text))

    # Create w:t element containing the text
    text_element =
      xmlElement(
        name: :"w:t",
        content: [text_node],
        attributes: [],
        expanded_name: :"w:t",
        nsinfo: {~c"w", ~c"t"},
        namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
      )

    # Build run content: [rPr (optional), w:t]
    run_content =
      if run_props do
        [run_props, text_element]
      else
        [text_element]
      end

    # Create w:r element
    xmlElement(
      name: :"w:r",
      content: run_content,
      attributes: [],
      expanded_name: :"w:r",
      nsinfo: {~c"w", ~c"r"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end
end
