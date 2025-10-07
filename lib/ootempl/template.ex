defmodule Ootempl.Template do
  @moduledoc """
  Represents a pre-loaded and parsed .docx template optimized for batch rendering.

  This module provides a performance optimization for scenarios where the same
  template is used to generate multiple documents with different data. Instead of
  re-reading and re-parsing the template file for each render operation, you can
  load the template once and reuse it multiple times.

  ## Performance Benefits

  Loading a template extracts, parses, and normalizes all XML files from the .docx
  archive. This eliminates approximately 40% of the rendering time for batch operations:

  - File I/O: ~20% of render time
  - XML parsing: ~18% of render time
  - Normalization: ~0.2% of render time

  ## Usage

  ### Batch Processing (Optimized)

      # Load template once
      {:ok, template} = Ootempl.load("invoice_template.docx")

      # Render multiple documents (fast - no I/O or parsing)
      Enum.each(customers, fn customer ->
        data = %{"name" => customer.name, "total" => customer.balance}
        Ootempl.render(template, data, "invoice_\#{customer.id}.docx")
      end)

  ### Single Document (Convenience)

      # One-shot rendering (does everything in one call)
      Ootempl.render("template.docx", data, "output.docx")

  ## Structure

  The Template struct contains all parsed and normalized XML structures from the
  .docx template, ready to be cloned and processed for each render operation.
  """

  alias Ootempl.Xml

  @enforce_keys [:document, :static_files]
  defstruct [
    :document,
    :headers,
    :footers,
    :footnotes,
    :endnotes,
    :core_properties,
    :app_properties,
    :static_files,
    :source_path
  ]

  @type t :: %__MODULE__{
          document: Xml.xml_element(),
          headers: %{String.t() => Xml.xml_element()},
          footers: %{String.t() => Xml.xml_element()},
          footnotes: Xml.xml_element() | nil,
          endnotes: Xml.xml_element() | nil,
          core_properties: Xml.xml_element() | nil,
          app_properties: Xml.xml_element() | nil,
          static_files: %{String.t() => binary()},
          source_path: String.t() | nil
        }

  @doc """
  Creates a new Template struct.

  This is typically called by `Ootempl.load/1` rather than directly.
  """
  @spec new(keyword()) :: t()
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Deep clones an XML element structure.

  Required because XML elements are modified during rendering, so each
  render operation needs its own copy of the template's XML structure.
  """
  @spec clone_xml(Xml.xml_element()) :: Xml.xml_element()
  def clone_xml(element) do
    import Xml

    require Record

    case element do
      xmlElement(
        name: name,
        attributes: attrs,
        content: content,
        expanded_name: expanded,
        namespace: ns,
        parents: parents,
        pos: pos,
        language: lang
      ) ->
        cloned_content = Enum.map(content, &clone_xml_node/1)

        xmlElement(
          name: name,
          attributes: attrs,
          content: cloned_content,
          expanded_name: expanded,
          namespace: ns,
          parents: parents,
          pos: pos,
          language: lang
        )

      other ->
        other
    end
  end

  @spec clone_xml_node(Xml.xml_node()) :: Xml.xml_node()
  defp clone_xml_node(node) do
    import Xml

    require Record

    cond do
      Record.is_record(node, :xmlElement) ->
        clone_xml(node)

      Record.is_record(node, :xmlText) ->
        xmlText(
          value: xmlText(node, :value),
          parents: xmlText(node, :parents),
          pos: xmlText(node, :pos),
          language: xmlText(node, :language),
          type: xmlText(node, :type)
        )

      true ->
        node
    end
  end

  @doc """
  Clones a map of XML elements (for headers/footers).
  """
  @spec clone_xml_map(%{String.t() => Xml.xml_element()}) :: %{String.t() => Xml.xml_element()}
  def clone_xml_map(xml_map) do
    Map.new(xml_map, fn {key, xml} -> {key, clone_xml(xml)} end)
  end
end
