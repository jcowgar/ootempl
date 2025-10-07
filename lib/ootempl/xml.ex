defmodule Ootempl.Xml do
  @moduledoc """
  XML manipulation utilities for working with Erlang's `:xmerl` library.

  This module provides Elixir-friendly wrappers around `:xmerl` record structures,
  enabling type-safe XML operations for parsing and manipulating Office document XML.

  ## Record Structures

  Defines Elixir records for the following `:xmerl` types:
  - `:xmlElement` - XML element nodes
  - `:xmlAttribute` - XML attribute nodes
  - `:xmlText` - XML text content nodes

  ## Parsing and Serialization

  Parse XML strings into :xmerl record structures:

      {:ok, doc} = Ootempl.Xml.parse("<root><child>text</child></root>")

  Serialize :xmerl records back to XML strings:

      {:ok, xml_string} = Ootempl.Xml.serialize(doc)

  Round-trip parsing and serialization (useful for testing):

      {:ok, xml_string} = Ootempl.Xml.round_trip("<root><child>text</child></root>")

  All parsing and serialization functions handle XML namespaces correctly,
  which is essential for .docx files that use namespaces extensively (w:, r:, etc.).

  ## Usage

  To use the record macros in your code, you need to import them:

      import Ootempl.Xml

      element = xmlElement(name: :div, content: [])
      name = element_name(element)  # Returns "div"

  See the test suite for comprehensive usage examples.
  """

  require Record

  # Extract record definitions from :xmerl
  Record.defrecord(
    :xmlElement,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecord(
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecord(:xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  @type xml_element :: tuple()
  @type xml_attribute :: tuple()
  @type xml_text :: tuple()
  @type xml_node :: xml_element() | xml_text()

  @doc """
  Parses an XML string into :xmerl record structures.

  Uses `:xmerl_scan.string/2` with namespace conformant parsing to correctly
  handle .docx XML which uses namespaces extensively (w:, r:, etc.).

  Returns `{:ok, document}` on success, or `{:error, reason}` if parsing fails.

  ## Examples

      iex> {:ok, _doc} = Ootempl.Xml.parse("<root><child>text</child></root>")

      iex> {:error, _reason} = Ootempl.Xml.parse("<root><unclosed>")
  """
  @spec parse(String.t()) :: {:ok, xml_element()} | {:error, term()}
  def parse(xml_string) when is_binary(xml_string) do
    # :xmerl_scan.string/2 expects a charlist
    # Note: :xmerl has limited UTF-8 support; non-ASCII characters may need
    # the XML declaration with encoding="UTF-8" to parse correctly
    charlist = String.to_charlist(xml_string)
    {doc, _rest} = :xmerl_scan.string(charlist, namespace_conformant: true)
    {:ok, doc}
  rescue
    e -> {:error, e}
  catch
    :exit, reason -> {:error, reason}
  end

  @doc """
  Serializes :xmerl record structures back to an XML string.

  Uses `:xmerl.export_simple/2` to convert the internal representation back
  to XML, preserving namespaces and attributes.

  Returns `{:ok, xml_string}` on success, or `{:error, reason}` if serialization fails.

  ## Examples

      iex> {:ok, doc} = Ootempl.Xml.parse("<root><child>text</child></root>")
      iex> Ootempl.Xml.serialize(doc)
      {:ok, "<?xml version=..."}
  """
  @spec serialize(xml_element()) :: {:ok, String.t()} | {:error, term()}
  def serialize(xml_record) do
    xml_iodata =
      xml_record
      |> List.wrap()
      |> :xmerl.export_simple(:xmerl_xml)

    # Use :unicode.characters_to_binary to handle Unicode codepoints properly
    # :xmerl.export_simple can return iodata with Unicode codepoints > 255
    xml_string = :unicode.characters_to_binary(xml_iodata)

    {:ok, xml_string}
  rescue
    e -> {:error, e}
  catch
    :exit, reason -> {:error, reason}
  end


  @doc """
  Removes a list of nodes from an XML element.

  Traverses the element's content and removes all nodes that match
  any node in the `nodes_to_remove` list. This is useful for removing
  conditional sections when conditions are false.

  ## Parameters

  - `element` - The XML element to process
  - `nodes_to_remove` - List of nodes to remove from the element

  ## Returns

  The modified XML element with the specified nodes removed.

  ## Examples

      iex> {:ok, doc} = Ootempl.Xml.parse("<root><p>keep</p><p>remove</p></root>")
      iex> [_keep, remove] = Ootempl.Xml.find_elements(doc, :p)
      iex> modified = Ootempl.Xml.remove_nodes(doc, [remove])
      iex> Ootempl.Xml.find_elements(modified, :p) |> length()
      1
  """
  @spec remove_nodes(xml_element(), [xml_node()]) :: xml_element()
  def remove_nodes(element, nodes_to_remove) do
    content = xmlElement(element, :content)
    filtered_content = filter_and_recurse(content, nodes_to_remove)
    xmlElement(element, content: filtered_content)
  end

  # Private helpers

  # Filters nodes and recursively processes element children
  @spec filter_and_recurse([xml_node()], [xml_node()]) :: [xml_node()]
  defp filter_and_recurse(nodes, nodes_to_remove) do
    nodes
    |> Enum.reject(fn node -> node in nodes_to_remove end)
    |> Enum.map(fn node ->
      if element_node?(node) do
        remove_nodes(node, nodes_to_remove)
      else
        node
      end
    end)
  end

  @spec element_node?(xml_node()) :: boolean()
  defp element_node?(node) do
    Record.is_record(node, :xmlElement)
  end
end
